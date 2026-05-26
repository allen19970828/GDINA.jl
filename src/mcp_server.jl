# ============================================================================
# mcp_server.jl — Model Context Protocol (MCP) Server for GDINA.jl
#
# This script exposes GDINA.jl functionalities as tools over standard JSON-RPC
# to be consumed by LLM agents via the Model Context Protocol.
#
# Usage:
# julia --project=@. src/mcp_server.jl
# ============================================================================

using GDINA
using JSON3
using CSV
using DataFrames

function handle_initialize(req)
    return Dict(
        "protocolVersion" => "2024-11-05",
        "capabilities" => Dict(
            "tools" => Dict()
        ),
        "serverInfo" => Dict(
            "name" => "GDINAServer",
            "version" => "0.1.0"
        )
    )
end

function handle_tools_list(req)
    return Dict(
        "tools" => [
            Dict(
                "name" => "estimate_gdina",
                "description" => "Estimate a Cognitive Diagnosis Model (CDM) using GDINA.jl. Takes paths to CSV files for response data and Q-matrix, and outputs estimation reports.",
                "inputSchema" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "data_path" => Dict("type" => "string", "description" => "Absolute path to the response data CSV file (N examinees x J items)."),
                        "qmatrix_path" => Dict("type" => "string", "description" => "Absolute path to the Q-matrix CSV file (J items x K attributes)."),
                        "model" => Dict("type" => "string", "description" => "Model type: GDINA, DINA, DINO, ACDM, LLM, RRUM. Default is GDINA."),
                        "method" => Dict("type" => "string", "description" => "Estimation method: EM or MCMC. Default is EM."),
                        "has_header" => Dict("type" => "boolean", "description" => "Set to true if CSV files have headers (column names). Default is false."),
                        "compute_se" => Dict("type" => "boolean", "description" => "Compute item parameter standard errors (only applicable for EM). Default is true.")
                    ),
                    "required" => ["data_path", "qmatrix_path"]
                )
            )
        ]
    )
end

function handle_tools_call(req)
    params = get(req, "params", Dict())
    name = get(params, "name", "")
    args = get(params, "arguments", Dict())
    
    if name == "estimate_gdina"
        try
            data_path = args["data_path"]
            q_path = args["qmatrix_path"]
            model_str = get(args, "model", "GDINA")
            model_sym = Symbol(model_str)
            
            method_str = get(args, "method", "EM")
            method_sym = Symbol(method_str)
            
            has_header = get(args, "has_header", false)
            compute_se = get(args, "compute_se", true)
            
            # Read Response Data
            df_data = has_header ? CSV.read(data_path, DataFrame) : CSV.read(data_path, DataFrame, header=false)
            data_mat = Matrix{Float64}(df_data)
            
            # Read Q-matrix
            df_q = has_header ? CSV.read(q_path, DataFrame) : CSV.read(q_path, DataFrame, header=false)
            q_mat = Matrix{Int}(df_q)
            
            if method_sym == :MCMC
                # Dynamically try to load Turing to activate the Package Extension
                try
                    @eval using Turing
                catch e
                    return Dict(
                        "isError" => true,
                        "content" => [
                            Dict(
                                "type" => "text",
                                "text" => "MCMC method requested, but Turing.jl is not available. Please ensure Turing.jl is in your environment dependencies."
                            )
                        ]
                    )
                end
            end
            
            # Run GDINA Estimation
            res = gdina(data_mat, q_mat; model=model_sym, method=method_sym)
            
            # Extract Latent Profiles
            eap = person_eap(res)
            map_prof = person_map(res)
            
            # Build Item Parameters Table
            item_table = "### Item Parameters & Delta Estimates\n\n| Item | Parameter | Estimate (Delta) |"
            if method_sym == :EM && compute_se
                se_delta = standard_error(res, data_mat)
                item_table *= " Standard Error |\n| :--- | :--- | :--- | :--- |\n"
                for j in 1:res.nitems
                    delta_j = res.item_params.delta[j]
                    se_j = se_delta[j]
                    for p in 1:length(delta_j)
                        param_name = p == 1 ? "d0 (Base)" : "d$(p-1)"
                        item_table *= "| Item $j | $param_name | $(round(delta_j[p], digits=4)) | $(round(se_j[p], digits=4)) |\n"
                    end
                end
            else
                item_table *= "\n| :--- | :--- | :--- |\n"
                for j in 1:res.nitems
                    delta_j = res.item_params.delta[j]
                    for p in 1:length(delta_j)
                        param_name = p == 1 ? "d0 (Base)" : "d$(p-1)"
                        item_table *= "| Item $j | $param_name | $(round(delta_j[p], digits=4)) |\n"
                    end
                end
            end
            
            # Create full report in markdown
            summary = """
            ## GDINA.jl Estimation Report
            
            *   **Model Type:** `$model_str`
            *   **Estimation Method:** `$method_str`
            *   **Number of Examinees (N):** $(res.npersons)
            *   **Number of Items (J):** $(res.nitems)
            *   **Number of Latent Attributes (K):** $(res.Q.natt)
            
            ### Fit Statistics (Information Criteria)
            *   **Log-Likelihood:** $(round(res.loglik, digits=4))
            *   **Deviance:** $(round(res.deviance, digits=4))
            *   **AIC:** $(round(res.AIC, digits=4))
            *   **BIC:** $(round(res.BIC, digits=4))
            *   **Free Parameters (df):** $(res.npar)
            *   **Estimation Converged:** $(res.converged ? "Yes" : "No") (in $(res.n_iter) iterations)
            
            $item_table
            
            ### Latent Attribute Profile Classification (MAP)
            *Showing classification for first 5 examinees:*
            """
            
            # Format MAP as markdown table
            map_table = "\n| Examinee | " * join(["Attribute $k" for k in 1:res.Q.natt], " | ") * " |\n"
            map_table *= "| :--- | " * join([":---" for k in 1:res.Q.natt], " | ") * " |\n"
            for i in 1:min(5, res.npersons)
                map_table *= "| Examinee $i | " * join([string(map_prof[i, k]) for k in 1:res.Q.natt], " | ") * " |\n"
            end
            
            summary *= map_table
            
            return Dict(
                "content" => [
                    Dict(
                        "type" => "text",
                        "text" => summary
                    )
                ]
            )
        catch e
            return Dict(
                "isError" => true,
                "content" => [
                    Dict(
                        "type" => "text",
                        "text" => "Error during estimation: $(sprint(showerror, e))"
                    )
                ]
            )
        end
    ) else
        return Dict(
            "isError" => true,
            "content" => [
                Dict("type" => "text", "text" => "Unknown tool: $name")
            ]
        )
    end
end

function main_loop()
    # Log to stderr so stdout is strictly JSON-RPC
    println(stderr, "GDINAServer starting on stdio...")
    
    while !eof(stdin)
        line = readline(stdin)
        isempty(strip(line)) && continue
        
        local req
        try
            req = JSON3.read(line, Dict{String, Any})
        catch
            println(stderr, "Failed to parse JSON: ", line)
            continue
        end
        
        # JSON-RPC Handling
        if haskey(req, "method")
            method = req["method"]
            id = get(req, "id", nothing)
            
            response = Dict{String, Any}("jsonrpc" => "2.0")
            if id !== nothing
                response["id"] = id
            end
            
            try
                if method == "initialize"
                    response["result"] = handle_initialize(req)
                elseif method == "tools/list"
                    response["result"] = handle_tools_list(req)
                elseif method == "tools/call"
                    response["result"] = handle_tools_call(req)
                elseif method == "notifications/initialized" || startswith(method, "\\\$/")
                    # Ignore notifications and cancellation
                    continue
                else
                    # Method not found
                    response["error"] = Dict("code" => -32601, "message" => "Method not found: $method")
                end
            catch e
                response["error"] = Dict("code" => -32000, "message" => "Internal error: $(sprint(showerror, e))")
            end
            
            # Send response if it's a request (has id)
            if id !== nothing
                println(stdout, JSON3.write(response))
                flush(stdout)
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_loop()
end
