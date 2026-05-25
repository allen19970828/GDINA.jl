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
                "description" => "Estimate a Cognitive Diagnosis Model (CDM) using GDINA.jl. Takes paths to CSV files for response data and Q-matrix.",
                "inputSchema" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "data_path" => Dict("type" => "string", "description" => "Absolute path to the response data CSV file (N examines x J items)."),
                        "qmatrix_path" => Dict("type" => "string", "description" => "Absolute path to the Q-matrix CSV file (J items x K attributes)."),
                        "model" => Dict("type" => "string", "description" => "Model type: GDINA, DINA, DINO, ACDM, LLM, RRUM. Default is GDINA.")
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
            
            # Read Data
            df_data = CSV.read(data_path, DataFrame, header=false)
            data_mat = Matrix(df_data)
            
            # Read Q-matrix
            df_q = CSV.read(q_path, DataFrame, header=false)
            q_mat = Matrix(df_q)
            
            # Run GDINA
            res = gdina(data_mat, q_mat, model=model_sym)
            
            # Extract EAP/MAP
            eap = person_eap(res)
            map_prof = person_map(res)
            
            # Create text response
            summary = """
            GDINA Estimation Completed Successfully!
            
            Model: $model_str
            Number of Examinees: $(res.npersons)
            Number of Items: $(res.nitems)
            Number of Attributes: $(res.Q.natt)
            
            Fit Statistics:
            - Log-Likelihood: $(round(res.loglik, digits=4))
            - Deviance: $(round(res.deviance, digits=4))
            - AIC: $(round(res.AIC, digits=4))
            - BIC: $(round(res.BIC, digits=4))
            - Free Parameters: $(res.npar)
            
            Examinees MAP Profiles (First 5):
            $(map_prof[1:min(5, end), :])
            """
            
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
    else
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
