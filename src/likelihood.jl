# ============================================================================
# likelihood.jl — Likelihood and probability computations for GDINA.jl
# ============================================================================

"""
    item_prob(delta::Vector{T}, design_matrix::Matrix{Float64}, link::LinkFunction) -> Vector{T}

Compute the success probability P(X_j = 1 | α_c) for all reduced latent groups
for a single item.

# Arguments
- `delta`: The ANOVA basis parameters (δ).
- `design_matrix`: The M_j design matrix mapping classes to parameters.
- `link`: The link function (e.g., IdentityLink, LogitLink).

# Returns
- A vector of probabilities, one for each reduced latent group.
"""
function item_prob(delta::Vector{T}, design_matrix::Matrix{Float64}, link::LinkFunction) where {T<:Real}
    # η = M_j * δ
    eta = design_matrix * delta
    
    # Apply inverse link function to get probabilities
    prob = similar(eta)
    for i in eachindex(eta)
        prob[i] = apply_inv_link(link, eta[i])
        # Bound probabilities to avoid log(0)
        prob[i] = clamp(prob[i], 1e-10, 1.0 - 1e-10)
    end
    return prob
end

"""
    log_likelihood_matrix(
        data::Matrix{Union{Int8, Missing}},
        catprob::Vector{Vector{T}},
        group_map::Vector{Vector{Int}}
    ) -> Matrix{T}

Compute the N × 2^K conditional log-likelihood matrix log L(X_i | α_c).

# Arguments
- `data`: N × J response matrix
- `catprob`: Vector of length J, containing success probabilities for reduced groups
- `group_map`: Vector of length J, containing mapping from 2^K classes to reduced groups

# Returns
- `logL`: N × 2^K matrix where logL[i, c] = ∑_j log P(X_ij | α_c)
"""
function log_likelihood_matrix(
    data::AbstractMatrix,
    catprob::Vector{Vector{T}},
    group_map::Vector{Vector{Int}}
) where {T<:Real}
    
    N, J = size(data)
    C = length(group_map[1]) # 2^K
    
    logL = zeros(T, N, C)
    
    for j in 1:J
        prob_j = catprob[j]
        map_j = group_map[j]
        
        # Precompute log(P(X_ij = x | α_c)) for this item across all classes
        log_p1 = zeros(T, C)
        log_p0 = zeros(T, C)
        
        for c in 1:C
            g = map_j[c]
            log_p1[c] = log(prob_j[g])
            log_p0[c] = log(1.0 - prob_j[g])
        end
        
        for i in 1:N
            x = data[i, j]
            if !ismissing(x)
                if x == 1
                    for c in 1:C
                        logL[i, c] += log_p1[c]
                    end
                else # x == 0
                    for c in 1:C
                        logL[i, c] += log_p0[c]
                    end
                end
            end
        end
    end
    
    return logL
end
