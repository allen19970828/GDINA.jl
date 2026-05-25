# ============================================================================
# em.jl — Main EM Algorithm Loop and User Entry Point for GDINA.jl
# ============================================================================

"""
    gdina(
        data::Union{AbstractMatrix, ResponseData},
        q_matrix::Union{AbstractMatrix, QMatrix};
        model::Union{Symbol, Vector{Symbol}} = :GDINA,
        method::Symbol = :EM,
        kwargs...
    ) -> GDINAResult

Estimate a Cognitive Diagnosis Model.
"""
function gdina(
    data::Union{AbstractMatrix, ResponseData},
    q_matrix::Union{AbstractMatrix, QMatrix};
    model::Union{Symbol, Vector{Symbol}} = :GDINA,
    method::Symbol = :EM,
    kwargs...
)
    if method == :EM
        return fit_em(data, q_matrix; model=model, kwargs...)
    elseif method == :MCMC
        return fit_mcmc(data, q_matrix; model=model, kwargs...)
    else
        error("Unknown method: \$method")
    end
end

function fit_mcmc(data, q_matrix; kwargs...)
    error("Please run `using Turing` to enable MCMC Bayesian estimation.")
end

function fit_em(
    data::Union{AbstractMatrix, ResponseData},
    q_matrix::Union{AbstractMatrix, QMatrix};
    model::Union{Symbol, Vector{Symbol}} = :GDINA,
    config::EMConfig = EMConfig(),
    att_dist::AttDistribution = IndependentDist()
)
    # 1. Standardize Inputs
    rd = data isa ResponseData ? data : ResponseData(data)
    Q = q_matrix isa QMatrix ? q_matrix : QMatrix(q_matrix)
    
    J = Q.nitems
    K = Q.natt
    
    if rd.nitems != J
        throw(DimensionMismatch("Data has $(rd.nitems) items but Q-matrix has $J"))
    end
    
    # Standardize models and links
    model_symbols = model isa Symbol ? fill(model, J) : model
    length(model_symbols) == J || throw(DimensionMismatch("Length of model vector must be $J"))
    
    models = parse_model.(model_symbols)
    links = default_link.(models)
    
    # 2. Setup Data Structures and Caches
    att_patterns = attributepattern(K)
    C = size(att_patterns, 1)
    
    group_map = latent_group_map(Q, att_patterns)
    design_matrices = [designmatrix(Q.Kj[j], models[j]) for j in 1:J]
    
    # 3. Initialize Parameters
    # Flat prior over latent classes
    att_prior = fill(1.0 / C, C)
    
    # Initialize item parameters (guessing 0.2, slipping 0.2 for simplicity)
    delta_init = Vector{Vector{Float64}}(undef, J)
    catprob_init = Vector{Vector{Float64}}(undef, J)
    
    for j in 1:J
        M = design_matrices[j]
        link = links[j]
        Kj_star = length(unique(group_map[j]))
        
        # Simple initialization: 0.2 for lowest group, 0.8 for highest, linear between
        prob = zeros(Kj_star)
        for g in 1:Kj_star
            prob[g] = 0.2 + (0.6 / max(1, Kj_star - 1)) * (g - 1)
        end
        catprob_init[j] = prob
        
        # Approximate delta
        # Since applying pseudo-inverse might fail if M is not full rank,
        # we fallback to simple least squares
        delta_init[j] = M \ apply_link.(Ref(link), prob)
    end
    
    item_params = ItemParams(catprob_init, delta_init, models, links)
    
    # 4. EM Loop
    loglik_history = Float64[]
    converged = false
    n_iter = 0
    prev_loglik = -Inf
    
    # Allocate posterior to be available outside loop
    local posterior, expected_Nc
    
    for iter in 1:config.max_iter
        n_iter = iter
        
        # --- E-Step ---
        logL = log_likelihood_matrix(rd.data, item_params.catprob, group_map)
        posterior, Rjl, Ijl, expected_Nc, current_loglik = estep(logL, att_prior, rd.data, group_map)
        
        push!(loglik_history, current_loglik)
        
        if config.verbose && (iter == 1 || iter % config.verbose_freq == 0)
            @printf("Iter %4d: Loglik = %12.4f, Change = %10.4e\n", iter, current_loglik, current_loglik - prev_loglik)
        end
        
        # Check convergence
        if iter > 1 && abs(current_loglik - prev_loglik) < config.tol
            converged = true
            break
        end
        prev_loglik = current_loglik
        
        # --- M-Step ---
        mstep!(item_params, att_prior, Rjl, Ijl, expected_Nc, design_matrices, config.mono_constr)
        
    end
    
    if config.verbose
        println("EM completed. Converged: $converged, Iterations: $n_iter")
    end
    
    # 5. Compute Fit Indices
    npar_item = sum(length(d) for d in item_params.delta)
    npar_prior = C - 1
    npar = npar_item + npar_prior
    
    deviance = -2.0 * prev_loglik
    AIC = deviance + 2 * npar
    BIC = deviance + npar * log(rd.npersons)
    
    return GDINAResult(
        Q, model_symbols, IdentityLink(), att_dist,
        item_params, att_prior, posterior, att_patterns,
        prev_loglik, deviance, AIC, BIC, npar, rd.npersons, J,
        converged, n_iter, loglik_history,
        design_matrices, group_map
    )
end
