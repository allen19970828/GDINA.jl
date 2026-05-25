# ============================================================================
# designmatrix.jl — Design matrix generation for GDINA.jl
# ============================================================================

"""
    designmatrix(Kj::Int, model::CDMType) -> Matrix{Float64}

Generate the design matrix M_j for an item with Kj required attributes,
based on the specified cognitive diagnosis model type.
The design matrix maps the ANOVA basis parameters (δ) to the success probabilities
of the 2^Kj reduced latent groups.
"""
function designmatrix(Kj::Int, model::CDMType)
    # If Kj == 0 (no attributes required), there's only one group (intercept)
    if Kj == 0
        return ones(Float64, 1, 1)
    end
    return _build_design_matrix(Kj, model)
end

# Saturated G-DINA: Complete ANOVA expansion
function _build_design_matrix(Kj::Int, ::SaturatedGDINA)
    n_groups = 2^Kj
    M = zeros(Float64, n_groups, n_groups)
    
    # We use the binary counter pattern to represent the groups.
    # A basis function δ_S is active for group g if the attributes of S
    # are a subset of the attributes of g.
    # Since we use binary counter, the bitwise AND of g and S should equal S.
    for g in 1:n_groups
        val_g = g - 1
        for S in 1:n_groups
            val_S = S - 1
            if (val_g & val_S) == val_S
                M[g, S] = 1.0
            end
        end
    end
    return M
end

# DINA: Intercept + highest-order interaction only
function _build_design_matrix(Kj::Int, ::DINA)
    n_groups = 2^Kj
    M = zeros(Float64, n_groups, 2)
    
    for g in 1:n_groups
        val_g = g - 1
        M[g, 1] = 1.0 # Intercept
        # Highest order interaction is only active when ALL attributes are mastered.
        # This corresponds to val_g == 2^Kj - 1
        if val_g == n_groups - 1
            M[g, 2] = 1.0
        end
    end
    return M
end

# DINO: Intercept + compensatory interaction
function _build_design_matrix(Kj::Int, ::DINO)
    n_groups = 2^Kj
    M = zeros(Float64, n_groups, 2)
    
    for g in 1:n_groups
        val_g = g - 1
        M[g, 1] = 1.0 # Intercept
        # Active if AT LEAST ONE attribute is mastered (val_g > 0)
        if val_g > 0
            M[g, 2] = 1.0
        end
    end
    return M
end

# ACDM, LLM, RRUM: Intercept + main effects only
# They all share the same structural design matrix. Differences are handled by link functions.
function _build_main_effects_matrix(Kj::Int)
    n_groups = 2^Kj
    M = zeros(Float64, n_groups, Kj + 1)
    
    for g in 1:n_groups
        val_g = g - 1
        M[g, 1] = 1.0 # Intercept
        # Main effects
        for k in 1:Kj
            if (val_g & (1 << (k - 1))) != 0
                M[g, k + 1] = 1.0
            end
        end
    end
    return M
end

_build_design_matrix(Kj::Int, ::ACDM) = _build_main_effects_matrix(Kj)
_build_design_matrix(Kj::Int, ::LLM)  = _build_main_effects_matrix(Kj)
_build_design_matrix(Kj::Int, ::RRUM) = _build_main_effects_matrix(Kj)
