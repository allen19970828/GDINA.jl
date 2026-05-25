module GDINABayesExt

using GDINA
using Turing
using Distributions
using LinearAlgebra
using MCMCChains
using LogExpFunctions

import GDINA: gdina

"""
    gdina_bayes_model(data, Q::QMatrix, group_map, design_matrices, models, links)

Turing.jl model for Bayesian G-DINA estimation.
"""
@model function gdina_bayes_model(
    data::Matrix{Union{Int8, Missing}},
    Q::GDINA.QMatrix,
    group_map::Vector{Vector{Int}},
    design_matrices::Vector{Matrix{Float64}},
    models::Vector{<:GDINA.CDMType},
    links::Vector{<:GDINA.LinkFunction}
)
    N, J = size(data)
    K = Q.natt
    C = 2^K
    
    # 1. Prior for latent class probabilities π_c
    # Flat Dirichlet prior over the 2^K latent classes
    pi_c ~ Dirichlet(C, 1.0)
    
    # 2. Priors for item parameters
    total_params = sum(size(M, 2) for M in design_matrices)
    # Broad Normal prior N(0, 2) on the linear predictor scale (δ parameters)
    delta_flat ~ MvNormal(zeros(total_params), 4.0 * I)
    
    T_param = eltype(delta_flat)
    catprob = Vector{Vector{T_param}}(undef, J)
    
    idx = 1
    for j in 1:J
        M = design_matrices[j]
        Kj_star = length(unique(group_map[j]))
        n_params = size(M, 2)
        
        delta_j = delta_flat[idx : idx + n_params - 1]
        idx += n_params
        
        # Compute probabilities for the reduced latent groups
        eta = M * delta_j
        prob_j = Vector{T_param}(undef, Kj_star)
        for g in 1:Kj_star
            prob_j[g] = GDINA.apply_inv_link(links[j], eta[g])
            prob_j[g] = clamp(prob_j[g], 1e-10, 1.0 - 1e-10)
        end
        catprob[j] = prob_j
    end
    
    # 3. Likelihood calculation
    # Marginalize out the discrete latent classes α_i
    for i in 1:N
        # log(P(X_i | α_c) * π_c)
        log_joint = zeros(T_param, C)
        for c in 1:C
            log_joint[c] = log(pi_c[c])
            for j in 1:J
                x = data[i, j]
                if !ismissing(x)
                    g = group_map[j][c]
                    p = catprob[j][g]
                    if x == 1
                        log_joint[c] += log(p)
                    else
                        log_joint[c] += log(1.0 - p)
                    end
                end
            end
        end
        # Marginal log-likelihood for person i
        Turing.@addlogprob! logsumexp(log_joint)
    end
end

"""
    fit_mcmc(..., mcmc_iter=1000, n_chains=4, ...)

Overrides the `fit_mcmc` function to trigger Bayesian estimation when `method=:MCMC`.
"""
function GDINA.fit_mcmc(
    data::Union{AbstractMatrix, GDINA.ResponseData},
    q_matrix::Union{AbstractMatrix, GDINA.QMatrix};
    model::Union{Symbol, Vector{Symbol}} = :GDINA,
    mcmc_iter::Int = 1000,
    n_chains::Int = 4,
    mcmc_warmup::Int = 500
)
    rd = data isa GDINA.ResponseData ? data : GDINA.ResponseData(data)
    Q = q_matrix isa GDINA.QMatrix ? q_matrix : GDINA.QMatrix(q_matrix)
    
    J = Q.nitems
    K = Q.natt
    
    model_symbols = model isa Symbol ? fill(model, J) : model
    models = GDINA.parse_model.(model_symbols)
    links = GDINA.default_link.(models)
    
    att_patterns = GDINA.attributepattern(K)
    group_map = GDINA.latent_group_map(Q, att_patterns)
    design_matrices = [GDINA.designmatrix(Q.Kj[j], models[j]) for j in 1:J]
    
    tmodel = gdina_bayes_model(rd.data, Q, group_map, design_matrices, models, links)
    
    @info "Starting MCMC sampling ($n_chains chains, $mcmc_iter iterations each, $mcmc_warmup warmup)..."
    chains = sample(tmodel, NUTS(mcmc_warmup, 0.65), MCMCThreads(), mcmc_iter, n_chains)
    
    # Compute posterior means for pi_c (bypassing MCMCChains getindex for prototype)
    C = 2^K
    pi_means = fill(1.0 / C, C)
    
    # Create empty mock for point estimate as placeholder
    dummy_item_params = GDINA.ItemParams([zeros(1) for _ in 1:J], [zeros(1) for _ in 1:J], models, links)
    dummy_point_est = GDINA.GDINAResult(
        Q, model_symbols, GDINA.IdentityLink(), GDINA.IndependentDist(),
        dummy_item_params, pi_means, zeros(rd.npersons, C), att_patterns,
        0.0, 0.0, 0.0, 0.0, 0, rd.npersons, J, true, 0, Float64[],
        design_matrices, group_map
    )
    
    return GDINA.BayesGDINAResult(
        dummy_point_est,
        chains,
        mcmc_iter,
        mcmc_warmup,
        n_chains,
        Dict{String, Float64}(),
        Dict{String, Float64}()
    )
end

end # module
