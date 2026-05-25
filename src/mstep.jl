# ============================================================================
# mstep.jl — M-step computations for the EM algorithm
# ============================================================================

"""
    mstep!(
        item_params::ItemParams{T},
        att_prior::Vector{T},
        Rjl::Vector{Vector{T}},
        Ijl::Vector{Vector{T}},
        expected_Nc::Vector{T},
        design_matrices::Vector{Matrix{T}},
        mono_constr::Bool
    )

Perform the M-step of the EM algorithm, updating item_params and att_prior in-place.
"""
function mstep!(
    item_params::ItemParams{T},
    att_prior::Vector{T},
    Rjl::Vector{Vector{T}},
    Ijl::Vector{Vector{T}},
    expected_Nc::Vector{T},
    design_matrices::Vector{Matrix{T}},
    mono_constr::Bool
) where {T<:Real}

    J = length(Rjl)
    
    # 1. Update prior mixing proportions π_c
    N = sum(expected_Nc)
    for c in eachindex(att_prior)
        att_prior[c] = expected_Nc[c] / N
    end
    
    # 2. Update item parameters for each item
    for j in 1:J
        R = Rjl[j]
        I_count = Ijl[j]
        M = design_matrices[j]
        model = item_params.models[j]
        link = item_params.links[j]
        
        # Dispatch to the specific parameter estimation method based on the model
        delta_j, prob_j = update_item(model, R, I_count, M, link, mono_constr)
        
        item_params.delta[j] = delta_j
        item_params.catprob[j] = prob_j
    end
    
    return nothing
end

"""
    update_item(::SaturatedGDINA, R, I, M, link, mono_constr)

Closed-form solution for the saturated G-DINA model with Identity link.
"""
function update_item(
    ::SaturatedGDINA,
    R::Vector{T},
    I_count::Vector{T},
    M::Matrix{T},
    link::IdentityLink,
    mono_constr::Bool
) where {T<:Real}
    
    # P_g = R_g / I_g
    prob = similar(R)
    for g in eachindex(R)
        # Avoid division by zero
        denom = max(I_count[g], eps(T))
        p = R[g] / denom
        prob[g] = clamp(p, 1e-4, 1.0 - 1e-4)
    end
    
    # Enforce monotonicity using PAVA-like pooling if requested
    if mono_constr
        prob = enforce_monotonicity_saturated(prob, M)
    end
    
    # δ = M \\ P
    delta = M \ prob
    
    return delta, prob
end

"""
    update_item(model::CDMType, R, I, M, link, mono_constr)

General numerical optimization solution for non-saturated models
(e.g., DINA, DINO, ACDM, LLM, RRUM).
"""
function update_item(
    model::CDMType,
    R::Vector{T},
    I_count::Vector{T},
    M::Matrix{T},
    link::LinkFunction,
    mono_constr::Bool
) where {T<:Real}
    
    Kj_star = length(R)
    n_params = size(M, 2)
    
    # Objective function to MINIMIZE: negative log-likelihood
    function objective(delta)
        eta = M * delta
        val = zero(eltype(delta))
        for g in 1:Kj_star
            p = apply_inv_link(link, eta[g])
            p = clamp(p, 1e-10, 1.0 - 1e-10)
            val -= R[g] * log(p) + (I_count[g] - R[g]) * log(1.0 - p)
        end
        
        # Add penalty for monotonicity violation if required
        if mono_constr && !(model isa DINA) && !(model isa DINO)
            val += monotonicity_penalty(delta, M, link)
        end
        return val
    end
    
    # Initial guess
    delta0 = zeros(T, n_params)
    delta0[1] = apply_link(link, 0.2) # Initial intercept (~guessing)
    if n_params > 1
        delta0[2:end] .= 0.5 # Initial main effects
    end
    
    # Optimize using L-BFGS with ForwardDiff for exact gradients
    res = Optim.optimize(objective, delta0, LBFGS(); autodiff = :forward)
    
    delta = Optim.minimizer(res)
    
    # Recompute probabilities at optimum
    eta = M * delta
    prob = similar(R)
    for g in 1:Kj_star
        prob[g] = clamp(apply_inv_link(link, eta[g]), 1e-10, 1.0 - 1e-10)
    end
    
    return delta, prob
end

"""
    enforce_monotonicity_saturated(prob::Vector{T}, M::Matrix{T}) -> Vector{T}

Enforce monotonicity for the saturated model using iterative pooling.
"""
function enforce_monotonicity_saturated(prob::Vector{T}, M::Matrix{T}) where {T<:Real}
    n_groups = length(prob)
    p_mono = copy(prob)
    
    changed = true
    max_iter = 100
    iter = 0
    while changed && iter < max_iter
        changed = false
        iter += 1
        for g in 1:n_groups
            for S in 1:n_groups
                if M[g, S] == 1.0 && g != S
                    if p_mono[S] > p_mono[g]
                        avg = (p_mono[S] + p_mono[g]) / 2
                        p_mono[S] = avg
                        p_mono[g] = avg
                        changed = true
                    end
                end
            end
        end
    end
    return p_mono
end

"""
    monotonicity_penalty(delta::Vector{T}, M::Matrix{T}, link::LinkFunction)

Compute a penalty if monotonicity constraints are violated for parametric models.
"""
function monotonicity_penalty(delta::AbstractVector{T}, M::Matrix{Float64}, link::LinkFunction) where {T}
    penalty = zero(T)
    # Main effects (k > 1) should be non-negative
    for k in 2:length(delta)
        if delta[k] < 0
            penalty += (delta[k])^2 * 1000.0
        end
    end
    return penalty
end
