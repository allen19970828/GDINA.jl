# ============================================================================
# io.jl — I/O and display methods for GDINA.jl
# ============================================================================

import Base: show

function show(io::IO, q::QMatrix)
    print(io, "QMatrix with $(q.nitems) items and $(q.natt) attributes")
end

function show(io::IO, m::MIME"text/plain", q::QMatrix)
    println(io, "QMatrix with $(q.nitems) items and $(q.natt) attributes:")
    show(io, m, q.mat)
end

function show(io::IO, rd::ResponseData)
    print(io, "ResponseData with $(rd.npersons) examinees and $(rd.nitems) items")
    if rd.nmissing > 0
        print(io, " ($(rd.nmissing) missing responses)")
    end
end

function show(io::IO, res::GDINAResult)
    println(io, "GDINAResult:")
    # Group model names by type for concise printing
    unique_models = unique(res.model_names)
    model_str = length(unique_models) == 1 ? string(unique_models[1]) : "Mixed ($(join(unique_models, ", ")))"
    
    println(io, "  Model: ", model_str)
    println(io, "  Examinees: ", res.npersons)
    println(io, "  Items: ", res.nitems)
    println(io, "  Log-likelihood: ", round(res.loglik, digits=2))
    println(io, "  Deviance: ", round(res.deviance, digits=2))
    println(io, "  AIC: ", round(res.AIC, digits=2))
    println(io, "  BIC: ", round(res.BIC, digits=2))
    println(io, "  Number of parameters: ", res.npar)
    println(io, "  Converged: ", res.converged, " in ", res.n_iter, " iterations")
end

"""
    coef(res::GDINAResult, what::Symbol=:catprob)

Extract item parameters from the GDINA result.
`what` can be `:catprob` (success probabilities), `:delta` (ANOVA parameters), or `:se` (standard errors).
"""
function coef(res::GDINAResult, what::Symbol=:catprob)
    if what == :catprob
        return res.item_params.catprob
    elseif what == :delta
        return res.item_params.delta
    elseif what == :se
        return res.item_params.se
    else
        throw(ArgumentError("what must be :catprob, :delta, or :se"))
    end
end

"""
    extract(res::GDINAResult, what::Symbol)

Extract specific components from the GDINA result.
"""
function extract(res::GDINAResult, what::Symbol)
    if what == :posterior
        return res.posterior
    elseif what == :att_prior
        return res.att_prior
    elseif what == :design_matrices
        return res.design_matrices
    elseif what == :group_map
        return res.group_map
    else
        throw(ArgumentError("Unknown extraction target: $what"))
    end
end
