# ============================================================================
# estep.jl — E-step computations for the EM algorithm
# ============================================================================

"""
    estep(
        logL::Matrix{T},
        att_prior::Vector{T},
        data::Matrix{Union{Int8, Missing}},
        group_map::Vector{Vector{Int}}
    )

Perform the E-step of the EM algorithm.

# Arguments
- `logL`: N × 2^K log-likelihood matrix
- `att_prior`: 2^K vector of mixing proportions (π_c)
- `data`: N × J response matrix
- `group_map`: Mapping from 2^K classes to reduced groups for each item

# Returns
- `posterior`: N × 2^K posterior probability matrix P(α_c | X_i)
- `Rjl`: Vector of length J, containing expected number of correct responses for each reduced group
- `Ijl`: Vector of length J, containing expected number of examinees for each reduced group
- `expected_Nc`: Vector of length 2^K, expected number of examinees in each latent class
- `marginal_loglik`: The sum of log-marginal likelihoods
"""
function estep(
    logL::Matrix{T},
    att_prior::Vector{T},
    data::Matrix{Union{Int8, Missing}},
    group_map::Vector{Vector{Int}}
) where {T<:Real}
    
    N, C = size(logL)
    J = size(data, 2)
    
    posterior = zeros(T, N, C)
    marginal_loglik = zero(T)
    
    # 1. Compute posterior P(α_c | X_i) and marginal likelihood
    log_prior = log.(max.(att_prior, eps(T)))
    
    for i in 1:N
        # log(P(X_i | α_c) * π_c)
        log_joint = zeros(T, C)
        for c in 1:C
            log_joint[c] = logL[i, c] + log_prior[c]
        end
        
        # Marginal log-likelihood for person i: log(∑_c P(X_i, α_c))
        log_marg_i = logsumexp(log_joint)
        marginal_loglik += log_marg_i
        
        # Posterior: P(α_c | X_i) = exp(log_joint - log_marg_i)
        for c in 1:C
            posterior[i, c] = exp(log_joint[c] - log_marg_i)
        end
    end
    
    # 2. Compute expected counts
    expected_Nc = vec(sum(posterior, dims=1))
    
    Rjl = Vector{Vector{T}}(undef, J)
    Ijl = Vector{Vector{T}}(undef, J)
    
    for j in 1:J
        map_j = group_map[j]
        Kj_star = length(unique(map_j))
        
        R = zeros(T, Kj_star)
        I_count = zeros(T, Kj_star)
        
        for c in 1:C
            g = map_j[c]
            
            # Sum over all persons i
            for i in 1:N
                x = data[i, j]
                if !ismissing(x)
                    post_ic = posterior[i, c]
                    I_count[g] += post_ic
                    if x == 1
                        R[g] += post_ic
                    end
                end
            end
        end
        
        Rjl[j] = R
        Ijl[j] = I_count
    end
    
    return posterior, Rjl, Ijl, expected_Nc, marginal_loglik
end
