# ============================================================================
# se.jl — Standard Error Estimation
# ============================================================================

export standard_error

"""
    standard_error(res::GDINAResult, data::AbstractMatrix) -> Vector{Vector{Float64}}

Compute standard errors for item parameters (δ) using the empirical cross-product 
information matrix (Louis, 1982).
Returns a vector of length J, containing the standard errors for the δ parameters of each item.
"""
function standard_error(res::GDINAResult, data::AbstractMatrix)
    rd = data isa GDINA.ResponseData ? data : GDINA.ResponseData(data)
    N, J = size(rd.data)
    
    # Pre-allocate standard errors
    se_delta = Vector{Vector{Float64}}(undef, J)
    C = size(res.att_patterns, 1)
    
    for j in 1:J
        M = res.design_matrices[j]
        n_params = size(M, 2)
        delta_j = res.item_params.delta[j]
        link_j = res.item_params.links[j]
        group_map_j = res.group_map[j]
        
        # Define log-likelihood for person i as a function of delta_j
        function logL_i(delta_vec, i::Int)
            eta = M * delta_vec
            prob_j = [GDINA.apply_inv_link(link_j, e) for e in eta]
            
            sum_prob = zero(eltype(delta_vec))
            
            for c in 1:C
                prior_c = res.att_prior[c]
                p_xc = one(eltype(delta_vec))
                
                for jj in 1:J
                    x = rd.data[i, jj]
                    if !ismissing(x)
                        if jj == j
                            g = group_map_j[c]
                            p = clamp(prob_j[g], 1e-10, 1.0 - 1e-10)
                            p_xc *= (x == 1 ? p : 1.0 - p)
                        else
                            g = res.group_map[jj][c]
                            p = res.item_params.catprob[jj][g]
                            p_xc *= (x == 1 ? p : 1.0 - p)
                        end
                    end
                end
                sum_prob += prior_c * p_xc
            end
            return log(sum_prob + 1e-300)
        end
        
        # Accumulate empirical information matrix
        Info = zeros(Float64, n_params, n_params)
        for i in 1:N
            grad_i = ForwardDiff.gradient(d -> logL_i(d, i), delta_j)
            Info += grad_i * grad_i'
        end
        
        # Invert to get covariance matrix (with small ridge for stability)
        for p in 1:n_params
            Info[p, p] += 1e-6
        end
        
        cov_matrix = inv(Info)
        se_j = sqrt.(max.(diag(cov_matrix), 0.0))
        se_delta[j] = se_j
    end
    
    return se_delta
end
