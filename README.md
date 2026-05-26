# GDINA.jl

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Julia Version](https://img.shields.io/badge/julia-v1.10%2B-blue.svg)](https://julialang.org)
[![Registry](https://img.shields.io/badge/registry-General-orange.svg)](https://github.com/JuliaRegistries/General)

`GDINA.jl` is a high-performance, native Julia package for **Cognitive Diagnosis Modeling (CDMs)**. It is heavily inspired by and extends the classic R `GDINA` package, leveraging Julia's **multiple dispatch**, **type safety**, and **computational speed** to process large-scale educational and psychological assessment data efficiently.

Additionally, `GDINA.jl` features a built-in **MCP (Model Context Protocol) server**, enabling seamless integration with Large Language Model (LLM) agents (like Claude, Cursor, and ChatGPT) to automate data estimation and analytical reporting.

🌐 **[繁體中文說明文件請見 README_zh.md](README_zh.md)**

---

## ✨ Features

1. **High-Performance EM Engine**:
   - Built on elegant Julia abstract types (`CDMType`, `LinkFunction`) instead of messy conditional branches.
   - Supports key cognitive diagnosis models:
     - **Saturated G-DINA**
     - **DINA** (Deterministic Inputs, Noisy "And" gate)
     - **DINO** (Deterministic Inputs, Noisy "Or" gate)
     - **A-CDM** (Additive CDM) / **LLM** (Linear Logistic Model) / **RRUM** (Reduced RUM)
   - Supports Identity, Logit, and Log link functions.

2. **Seamless Bayesian Extension (MCMC via Turing.jl)**:
   - Uses Julia's advanced **Package Extensions** to keep the core package extremely lightweight and fast-loading.
   - Just load `using Turing` in your session to unlock `fit_mcmc`, enabling advanced NUTS (No-U-Turn Sampler) estimation.

3. **Rigorous Louis (1982) Standard Errors**:
   - Implements Louis's observed information matrix method using **ForwardDiff.jl** automatic differentiation.
   - Provides exact, analytically accurate standard errors for item parameters without manual derivative derivation.

4. **Advanced Model Support**:
   - Includes data expansion utilities like `expand_sequential_data` to support polytomous item analysis (e.g., **Sequential G-DINA**).

5. **AI-Native MCP Server**:
   - Implements a JSON-RPC 2.0 Model Context Protocol server.
   - Allows AI Agents to call your Julia package as a tool to automate analysis of raw CSV student response data.

---

## 🛠️ Installation

You can install `GDINA.jl` via the Julia package manager (once the registration grace period completes):

```julia
using Pkg
Pkg.add("GDINA")
```

For development or local testing, clone the repository and instantiate:

```bash
julia --project=.
# Enter Pkg REPL by pressing ']'
(GDINA) pkg> instantiate
```

---

## 🚀 Quick Start

### 1. Estimate G-DINA Model using EM Algorithm

```julia
using GDINA

# Y: N × J response matrix (0/1)
# Q: J × K Q-matrix (0/1)
Y = [
    1 0 1;
    0 1 1;
    1 1 0;
    1 1 1;
    0 0 1
]

Q = [
    1 0;
    0 1;
    1 1
]

# Fit Saturated G-DINA model (defaults to Identity link)
model_em = fit_em(Y, Q; model=:GDINA, max_iter=200, tol=1e-4)

# Retrieve estimated success probabilities
println("Estimated Item Parameters (P): ", model_em.P)

# Estimate latent attribute profiles using EAP
est_eap = person_eap(model_em)
println("Latent Profiles (EAP): ", est_eap)
```

### 2. Bayesian MCMC Estimation

Loading `Turing` automatically brings the Bayesian extension into scope:

```julia
using GDINA
using Turing # Activates extension

# Estimate DINA model using MCMC
model_mcmc = fit_mcmc(Y, Q; model=:DINA, n_samples=1000, n_adapts=500)

# Retrieve posterior means
println("Posterior Estimates: ", model_mcmc.posterior_means)
```

---

## 🤖 AI Agent Integration: Run the MCP Server

To run the MCP server locally and allow IDEs like Cursor or Claude Desktop to use `GDINA.jl` to analyze files on your behalf:

1. Launch the server script:
   ```bash
   julia --project=@. src/mcp_server.jl
   ```

2. Add the server configuration to your Claude Desktop config file (usually `~/Library/Application Support/Claude/claude_desktop_config.json`):
   ```json
   {
     "mcpServers": {
       "gdina-jl": {
         "command": "julia",
         "args": [
           "--project=/absolute/path/to/GDINA.jl",
           "/absolute/path/to/GDINA.jl/src/mcp_server.jl"
         ]
       }
     }
   }
   ```
Now you can prompt your AI assistant: *"Analyze the student response CSV using the local GDINA server and write a cognitive diagnosis report."*

---

## 📚 Build Documentation Locally

To generate and view the static HTML documentation:

```bash
julia --project=docs docs/make.jl
```
Open `docs/build/index.html` in your browser to read the formatted API reference.

---

## 🧪 Running Tests

Run the test suite to verify code correctness:

```julia
using Pkg
Pkg.test("GDINA")
```

---

## 📂 Project Structure

```text
GDINA.jl/
├── Project.toml              # Package definition & dependencies
├── upstream_version.txt      # Synced R GDINA upstream version tracker
├── src/
│   ├── GDINA.jl              # Main package module
│   ├── types.jl              # Link functions & model types
│   ├── em.jl                 # EM estimation loop
│   ├── likelihood.jl         # Marginal & joint likelihood computations
│   ├── person_params.jl      # Latent attribute estimation (EAP/MAP/MLE)
│   ├── se.jl                 # Louis (1982) SEs using ForwardDiff
│   ├── advanced_models.jl    # Polytomous & Sequential G-DINA data expansion
│   └── mcp_server.jl         # Model Context Protocol server
├── ext/
│   └── GDINABayesExt/        # Turing.jl MCMC Extension
├── test/
│   └── runtests.jl           # Unit tests
└── docs/
    ├── make.jl               # Documenter.jl build script
    └── src/                  # Markdown files for documentation
```

---

## 📄 License

This project is licensed under the **MIT License**. Feel free to use, modify, and distribute for both academic and industrial purposes.
