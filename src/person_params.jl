# ============================================================================
# person_params.jl — Person Parameter Estimation (EAP, MAP, MLE)
# ============================================================================

export person_eap, person_map, person_mle

"""
    person_eap(res::GDINAResult) -> Matrix{Float64}

Compute the Expected A Posteriori (EAP) estimates of attribute mastery for each examinee.
Returns an N × K matrix containing the probability that person i masters attribute k.
"""
function person_eap(res::GDINAResult)
    N = res.npersons
    K = res.Q.natt
    C = size(res.att_patterns, 1)
    
    eap = zeros(Float64, N, K)
    
    for i in 1:N
        for c in 1:C
            post_ic = res.posterior[i, c]
            for k in 1:K
                if res.att_patterns[c, k] == 1
                    eap[i, k] += post_ic
                end
            end
        end
    end
    return eap
end

"""
    person_map(res::GDINAResult) -> Matrix{Int8}

Compute the Maximum A Posteriori (MAP) estimates of attribute profiles.
Returns an N × K binary matrix representing the estimated attribute profile
with the highest posterior probability for each examinee.
"""
function person_map(res::GDINAResult)
    N = res.npersons
    K = res.Q.natt
    
    map_profiles = zeros(Int8, N, K)
    
    for i in 1:N
        # Find the class c with the maximum posterior probability
        best_c = argmax(view(res.posterior, i, :))
        for k in 1:K
            map_profiles[i, k] = res.att_patterns[best_c, k]
        end
    end
    return map_profiles
end

"""
    person_mle(res::GDINAResult, data::AbstractMatrix) -> Matrix{Int8}

Compute the Maximum Likelihood Estimates (MLE) of attribute profiles.
Returns an N × K binary matrix representing the estimated attribute profile
with the highest likelihood (ignoring the prior).
"""
function person_mle(res::GDINAResult, data::AbstractMatrix)
    rd = data isa GDINA.ResponseData ? data : GDINA.ResponseData(data)
    N, J = size(rd.data)
    K = res.Q.natt
    
    mle_profiles = zeros(Int8, N, K)
    
    # We recompute the log-likelihood matrix since it is not stored in GDINAResult
    logL = log_likelihood_matrix(data, res.item_params.catprob, res.group_map)
    
    for i in 1:N
        best_c = argmax(view(logL, i, :))
        for k in 1:K
            mle_profiles[i, k] = res.att_patterns[best_c, k]
        end
    end
    
    return mle_profiles
end
