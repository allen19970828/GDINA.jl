# ============================================================================
# types.jl — Core type definitions for GDINA.jl
#
# Defines the complete type hierarchy for Cognitive Diagnosis Models,
# leveraging Julia's multiple dispatch to replace R's if-else branching.
# ============================================================================

# ============================================================================
# Link Functions
# ============================================================================

"""
    LinkFunction

Abstract type for link functions used in CDM item response functions.
Concrete subtypes: [`IdentityLink`](@ref), [`LogitLink`](@ref), [`LogLink`](@ref).
"""
abstract type LinkFunction end

"""
    IdentityLink <: LinkFunction

Identity link: g(P) = P. Used by G-DINA, DINA, DINO, A-CDM.
"""
struct IdentityLink <: LinkFunction end

"""
    LogitLink <: LinkFunction

Logit link: g(P) = log(P / (1-P)). Used by LLM (Log-Linear Model).
"""
struct LogitLink <: LinkFunction end

"""
    LogLink <: LinkFunction

Log link: g(P) = log(P). Used by RRUM (Reduced Reparameterized Unified Model).
"""
struct LogLink <: LinkFunction end

# ============================================================================
# CDM Model Types
# ============================================================================

"""
    CDMType

Abstract type for Cognitive Diagnosis Model specifications.
Each concrete subtype determines the design matrix structure and M-step strategy.
"""
abstract type CDMType end

"""
    SaturatedGDINA <: CDMType

Saturated G-DINA model with all main effects and interactions.
Number of parameters per item: 2^{K*_j}.
"""
struct SaturatedGDINA <: CDMType end

"""
    DINA <: CDMType

Deterministic Input, Noisy AND gate model (non-compensatory/conjunctive).
Only intercept and highest-order interaction are non-zero.
Parameters per item: 2 (guessing g, slip s).
"""
struct DINA <: CDMType end

"""
    DINO <: CDMType

Deterministic Input, Noisy OR gate model (compensatory/disjunctive).
Mastery of any single required attribute is sufficient.
Parameters per item: 2 (guessing g, slip s).
"""
struct DINO <: CDMType end

"""
    ACDM <: CDMType

Additive CDM. Main effects only with identity link (no interactions).
Parameters per item: K*_j + 1.
"""
struct ACDM <: CDMType end

"""
    LLM <: CDMType

Log-Linear Model. Main effects only with logit link.
Parameters per item: K*_j + 1.
"""
struct LLM <: CDMType end

"""
    RRUM <: CDMType

Reduced Reparameterized Unified Model. Main effects only with log link.
Parameters per item: K*_j + 1.
"""
struct RRUM <: CDMType end

# --- Advanced model types (Phase 5) ---

"""
    SequentialGDINA <: CDMType

Sequential G-DINA for polytomous/ordinal response data.
"""
struct SequentialGDINA <: CDMType end

"""
    MCModelType <: CDMType

Multiple-Choice DINA model for nominal responses with distractor diagnostics.
"""
struct MCModelType <: CDMType end

# ============================================================================
# Attribute Distribution Models
# ============================================================================

"""
    AttDistribution

Abstract type for the joint attribute distribution model P(α).
"""
abstract type AttDistribution end

"""Saturated (unrestricted) attribute distribution. Parameters: 2^K - 1."""
struct SaturatedDist <: AttDistribution end

"""Independent attributes: P(α) = ∏_k P(α_k). Parameters: K."""
struct IndependentDist <: AttDistribution end

"""Higher-order model: attributes driven by continuous latent trait θ via IRT."""
struct HigherOrderDist <: AttDistribution
    nfactors::Int  # number of higher-order factors (typically 1)
end
HigherOrderDist() = HigherOrderDist(1)

"""Log-linear smoothing of attribute distribution (Xu & von Davier, 2008)."""
struct LogLinearDist <: AttDistribution
    order::Int  # maximum interaction order
end
LogLinearDist() = LogLinearDist(2)

"""Fixed (user-supplied) attribute distribution — not estimated."""
struct FixedDist <: AttDistribution
    prior::Vector{Float64}
end

"""Structured attribute distribution with hierarchy constraints."""
struct StructuredDist <: AttDistribution
    hierarchy::Matrix{Int}  # K × K adjacency matrix
end

# ============================================================================
# Estimation Method
# ============================================================================

"""Abstract type for parameter estimation methods."""
abstract type EstimationMethod end

"""Maximum Likelihood via EM algorithm."""
struct EMMethod <: EstimationMethod end

"""Bayesian estimation via MCMC (requires Turing.jl extension)."""
struct MCMCMethod <: EstimationMethod end

# ============================================================================
# Q-Matrix
# ============================================================================

"""
    QMatrix

Q-matrix specification mapping items to required attributes.

# Fields
- `mat::BitMatrix`: J × K binary matrix where mat[j,k] = 1 if item j requires attribute k
- `nitems::Int`: number of items (J)
- `natt::Int`: number of attributes (K)
- `Kj::Vector{Int}`: number of required attributes per item (K*_j)
- `req_att::Vector{Vector{Int}}`: indices of required attributes per item
"""
struct QMatrix
    mat::BitMatrix
    nitems::Int
    natt::Int
    Kj::Vector{Int}
    req_att::Vector{Vector{Int}}
end

"""
    QMatrix(mat::AbstractMatrix)

Construct a QMatrix from a binary matrix (any numeric type).
Automatically computes item attribute counts and indices.
"""
function QMatrix(mat::AbstractMatrix)
    J, K = size(mat)
    bmat = BitMatrix(mat .> 0)
    Kj = vec(sum(bmat; dims=2))
    req_att = [findall(bmat[j, :]) for j in 1:J]
    return QMatrix(bmat, J, K, Kj, req_att)
end

# ============================================================================
# Response Data
# ============================================================================

"""
    ResponseData

Container for examinee response data.

# Fields
- `data::Matrix{Union{Int8, Missing}}`: N × J response matrix (0/1 or missing)
- `npersons::Int`: number of examinees (N)
- `nitems::Int`: number of items (J)
- `nmissing::Int`: total number of missing responses
"""
struct ResponseData
    data::Matrix{Union{Int8, Missing}}
    npersons::Int
    nitems::Int
    nmissing::Int
end

"""
    ResponseData(data::AbstractMatrix)

Construct ResponseData from a numeric matrix. Values are converted to Int8;
any value < 0 or NaN is treated as missing.
"""
function ResponseData(data::AbstractMatrix)
    N, J = size(data)
    converted = Matrix{Union{Int8, Missing}}(undef, N, J)
    nmiss = 0
    for j in 1:J, i in 1:N
        v = data[i, j]
        if ismissing(v) || (v isa Number && (isnan(v) || v < 0))
            converted[i, j] = missing
            nmiss += 1
        else
            converted[i, j] = Int8(round(Int, v))
        end
    end
    return ResponseData(converted, N, J, nmiss)
end

# ============================================================================
# Item Parameters
# ============================================================================

"""
    ItemParams{T<:Real}

Estimated item parameters for all items.

# Fields
- `catprob::Vector{Vector{T}}`: success probabilities P(X=1|α_g) for each reduced latent group
- `delta::Vector{Vector{T}}`: ANOVA-style basis (design matrix) coefficients δ
- `se::Vector{Vector{T}}`: standard errors of catprob
- `models::Vector{CDMType}`: model type used for each item
- `links::Vector{LinkFunction}`: link function used for each item
"""
struct ItemParams{T<:Real}
    catprob::Vector{Vector{T}}
    delta::Vector{Vector{T}}
    se::Vector{Vector{T}}
    models::Vector{CDMType}
    links::Vector{LinkFunction}
end

"""Construct ItemParams with empty SE vectors."""
function ItemParams(catprob::Vector{Vector{T}}, delta::Vector{Vector{T}},
                    models::Vector{<:CDMType}, links::Vector{<:LinkFunction}) where {T<:Real}
    se = [zeros(T, length(cp)) for cp in catprob]
    return ItemParams{T}(catprob, delta, se, models, links)
end

# ============================================================================
# EM Configuration
# ============================================================================

"""
    EMConfig

Configuration for the EM algorithm.

# Fields
- `max_iter::Int`: maximum number of EM iterations (default: 2000)
- `tol::Float64`: convergence tolerance for log-likelihood change (default: 1e-4)
- `tol_param::Float64`: convergence tolerance for parameter change (default: 1e-4)
- `mono_constr::Bool`: enforce monotonicity constraints (default: false)
- `pem::Bool`: use P-EM acceleration (default: false)
- `verbose::Bool`: print iteration progress (default: true)
- `verbose_freq::Int`: print every N iterations (default: 1)
"""
Base.@kwdef struct EMConfig
    max_iter::Int = 2000
    tol::Float64 = 1e-4
    tol_param::Float64 = 1e-4
    mono_constr::Bool = false
    pem::Bool = false
    verbose::Bool = true
    verbose_freq::Int = 1
end

# ============================================================================
# GDINAResult — Main estimation output
# ============================================================================

"""
    GDINAResult{T<:Real}

Complete output of a G-DINA model estimation.

# Fields
## Model specification
- `Q::QMatrix`: the Q-matrix
- `model_names::Vector{Symbol}`: model names per item (e.g., :GDINA, :DINA)
- `link::LinkFunction`: link function used
- `att_dist::AttDistribution`: attribute distribution model

## Estimated parameters
- `item_params::ItemParams{T}`: item parameter estimates
- `att_prior::Vector{T}`: estimated mixing proportions π_c (2^K vector)

## Posterior and classification
- `posterior::Matrix{T}`: N × 2^K posterior probability matrix P(α_c | Y_i)
- `att_patterns::BitMatrix`: 2^K × K matrix of all attribute patterns

## Fit indices
- `loglik::T`: marginal log-likelihood at convergence
- `deviance::T`: -2 × loglik
- `AIC::T`: -2ℓ + 2p
- `BIC::T`: -2ℓ + p·log(N)
- `npar::Int`: total number of free parameters
- `npersons::Int`: number of examinees
- `nitems::Int`: number of items

## Convergence info
- `converged::Bool`: whether EM converged
- `n_iter::Int`: number of EM iterations run
- `loglik_history::Vector{T}`: log-likelihood at each iteration

## Cached computations
- `design_matrices::Vector{Matrix{T}}`: design matrices M_j for each item
- `group_map::Vector{Vector{Int}}`: mapping from 2^K classes to reduced groups per item
"""
struct GDINAResult{T<:Real}
    # Model specification
    Q::QMatrix
    model_names::Vector{Symbol}
    link::LinkFunction
    att_dist::AttDistribution

    # Estimated parameters
    item_params::ItemParams{T}
    att_prior::Vector{T}

    # Posterior and classification
    posterior::Matrix{T}
    att_patterns::BitMatrix

    # Fit indices
    loglik::T
    deviance::T
    AIC::T
    BIC::T
    npar::Int
    npersons::Int
    nitems::Int

    # Convergence info
    converged::Bool
    n_iter::Int
    loglik_history::Vector{T}

    # Cached
    design_matrices::Vector{Matrix{T}}
    group_map::Vector{Vector{Int}}
end

# ============================================================================
# BayesGDINAResult — Bayesian estimation output (placeholder for Phase 6)
# ============================================================================

"""
    BayesGDINAResult{T<:Real}

Output of Bayesian G-DINA estimation via MCMC.
Wraps an EM-style point estimate (posterior means) plus the full MCMC chains.
"""
struct BayesGDINAResult{T<:Real}
    point_estimate::GDINAResult{T}  # posterior means formatted as GDINAResult
    chains::Any                      # MCMCChains.Chains object
    n_samples::Int
    n_warmup::Int
    n_chains::Int
    r_hat::Dict{String, T}          # convergence diagnostics
    ess::Dict{String, T}            # effective sample sizes
end

# ============================================================================
# Convenience: model/link symbol lookup tables
# ============================================================================

const MODEL_TYPES = Dict{Symbol, CDMType}(
    :GDINA => SaturatedGDINA(),
    :DINA  => DINA(),
    :DINO  => DINO(),
    :ACDM  => ACDM(),
    :LLM   => LLM(),
    :RRUM  => RRUM(),
    :seqGDINA => SequentialGDINA(),
    :MCmodel  => MCModelType(),
)

const LINK_TYPES = Dict{Symbol, LinkFunction}(
    :identity => IdentityLink(),
    :logit    => LogitLink(),
    :log      => LogLink(),
)

"""
    parse_model(model::Symbol) -> CDMType

Convert a model symbol to its CDMType instance.
"""
function parse_model(model::Symbol)
    haskey(MODEL_TYPES, model) || throw(ArgumentError(
        "Unknown model type :$model. Available: $(join(keys(MODEL_TYPES), ", "))"))
    return MODEL_TYPES[model]
end

"""
    parse_link(link::Symbol) -> LinkFunction

Convert a link symbol to its LinkFunction instance.
"""
function parse_link(link::Symbol)
    haskey(LINK_TYPES, link) || throw(ArgumentError(
        "Unknown link function :$link. Available: $(join(keys(LINK_TYPES), ", "))"))
    return LINK_TYPES[link]
end

# Pass-through for already-typed inputs
parse_model(model::CDMType) = model
parse_link(link::LinkFunction) = link

# ============================================================================
# Link function application and inverse
# ============================================================================

"""Apply link function: transform probability to linear predictor."""
apply_link(::IdentityLink, p::Real) = p
apply_link(::LogitLink, p::Real) = log(p / (1 - p))
apply_link(::LogLink, p::Real) = log(p)

"""Apply inverse link function: transform linear predictor to probability."""
apply_inv_link(::IdentityLink, η::Real) = η
apply_inv_link(::LogitLink, η::Real) = one(η) / (one(η) + exp(-η))
apply_inv_link(::LogLink, η::Real) = exp(η)

"""Default link function for each model type."""
default_link(::SaturatedGDINA) = IdentityLink()
default_link(::DINA)           = IdentityLink()
default_link(::DINO)           = IdentityLink()
default_link(::ACDM)           = IdentityLink()
default_link(::LLM)            = LogitLink()
default_link(::RRUM)           = LogLink()
default_link(::SequentialGDINA) = IdentityLink()
default_link(::MCModelType)    = IdentityLink()
