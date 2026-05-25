# GDINA.jl

**GDINA.jl** is a Julia package for Cognitive Diagnosis Modeling (CDM), providing a fast, extensible, and mathematically rigorous framework. It is heavily inspired by the R `GDINA` package but is built natively in Julia to take advantage of Multiple Dispatch, exact Automatic Differentiation, and state-of-the-art MCMC Bayesian estimation.

## Features

- **EM Estimation**: Ultra-fast Maximum Likelihood via the EM algorithm.
- **Supported Models**: Saturated G-DINA, DINA, DINO, ACDM, LLM, RRUM, Sequential G-DINA, and MC-DINA.
- **Bayesian MCMC**: First-class integration with `Turing.jl` via Package Extensions for rigorous HMC/NUTS Bayesian inference.
- **Inference**: Expected A Posteriori (EAP), Maximum A Posteriori (MAP), Maximum Likelihood Estimation (MLE) for person parameters.
- **Standard Errors**: Exact Empirical Cross-Product Information Matrix standard errors using `ForwardDiff.jl`.

## Quick Start

```julia
using GDINA
using DelimitedFiles

# Load your response data and Q-matrix (e.g., from CSV)
data = readdlm("data.csv", ',', Int)
q_matrix = readdlm("q_matrix.csv", ',', Int)

# Estimate the G-DINA model
res = gdina(data, q_matrix, model=:GDINA)

# Retrieve Person MAP profiles
map_profiles = person_map(res)

# Calculate Standard Errors
se = standard_error(res, data)
```
