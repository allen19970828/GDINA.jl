# ============================================================================
# utils.jl — Utility functions for GDINA.jl
# ============================================================================

"""
    attributepattern(K::Int) -> BitMatrix

Generate a 2^K × K matrix of all possible binary attribute patterns.
The patterns are ordered using a binary counter (e.g., [0,0], [1,0], [0,1], [1,1]),
which matches the convention used in the original GDINA R package.
"""
function attributepattern(K::Int)
    K < 1 && throw(ArgumentError("K must be >= 1"))
    n_patterns = 2^K
    patterns = BitMatrix(undef, n_patterns, K)
    for i in 1:n_patterns
        val = i - 1
        for k in 1:K
            patterns[i, k] = (val & (1 << (k - 1))) != 0
        end
    end
    return patterns
end

"""
    latent_group_map(Q::QMatrix, att_patterns::BitMatrix) -> Vector{Vector{Int}}

Create a mapping from the 2^K latent classes to the 2^{K*_j} reduced latent groups
for each item j. 
Returns a vector of length J, where each element is a vector of length 2^K containing
the reduced group index (1-based) for each full latent class.
"""
function latent_group_map(Q::QMatrix, att_patterns::BitMatrix)
    J = Q.nitems
    C = size(att_patterns, 1) # 2^K
    
    group_map = Vector{Vector{Int}}(undef, J)
    
    for j in 1:J
        req = Q.req_att[j]
        Kj = Q.Kj[j]
        
        mapping = Vector{Int}(undef, C)
        
        if Kj == 0
            mapping .= 1
        else
            # For each class c, its reduced pattern corresponds to a binary number.
            for c in 1:C
                idx = 1
                for (k, attr_idx) in enumerate(req)
                    if att_patterns[c, attr_idx]
                        idx += (1 << (k - 1))
                    end
                end
                mapping[c] = idx
            end
        end
        group_map[j] = mapping
    end
    
    return group_map
end

"""
    bdiag_matrix(matrices::Vector{<:AbstractMatrix}) -> SparseMatrixCSC

Construct a block diagonal matrix from a list of matrices.
"""
function bdiag_matrix(matrices::Vector{<:AbstractMatrix})
    isempty(matrices) && return spzeros(0, 0)
    
    rows = Int[]
    cols = Int[]
    vals = Float64[]
    
    r_offset = 0
    c_offset = 0
    
    for M in matrices
        r, c = size(M)
        for j in 1:c, i in 1:r
            v = M[i, j]
            if v != 0
                push!(rows, i + r_offset)
                push!(cols, j + c_offset)
                push!(vals, Float64(v))
            end
        end
        r_offset += r
        c_offset += c
    end
    
    return sparse(rows, cols, vals, r_offset, c_offset)
end

"""
    att_structure(K::Int, hierarchy::Matrix{Int}) -> BitMatrix

Filter attribute patterns based on a hierarchy adjacency matrix.
If hierarchy[i, j] == 1, then mastery of attribute j requires mastery of attribute i.
"""
function att_structure(K::Int, hierarchy::Matrix{Int})
    patterns = attributepattern(K)
    C = size(patterns, 1)
    valid_idx = Int[]
    
    for c in 1:C
        is_valid = true
        for j in 1:K, i in 1:K
            if hierarchy[i, j] == 1
                # If j is mastered (1), i must also be mastered (1)
                if patterns[c, j] && !patterns[c, i]
                    is_valid = false
                    break
                end
            end
        end
        if is_valid
            push!(valid_idx, c)
        end
    end
    return patterns[valid_idx, :]
end
