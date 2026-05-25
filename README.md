# GDINA.jl

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Julia Version](https://img.shields.io/badge/julia-v1.9%2B-blue.svg)](https://julialang.org)

`GDINA.jl` 是一個為**認知診斷模型 (Cognitive Diagnosis Models, CDMs)** 開發的高效能原生 Julia 套件。本套件高度致敬並擴展了 R 語言中經典的 `GDINA` 套件，並發揮 Julia 的「多重分派 (Multiple Dispatch)」、「強大效能」與「動態擴充性」，專為處理大規模教育與心理測量數據而設計。

此外，本套件原生內建了現代 AI 時代的 **MCP (Model Context Protocol) 伺服器**，能無縫整合大語言模型（LLM，如 Claude、Cursor、ChatGPT），讓 AI 能夠直接調用並自動分析您的認知診斷數據！

---

## ✨ 核心特色

1. **高效的 EM 估計引擎 (EM Estimation Engine)**：
   - 捨棄傳統 R 語言繁雜的 `if-else` 分支，採用優雅的 Julia 抽象型別 (`CDMType`、`LinkFunction`)。
   - 支援多種經典認知診斷模型：
     - **Saturated G-DINA** (飽和 G-DINA 模型)
     - **DINA** (Deterministic Inputs, Noisy "And" gate)
     - **DINO** (Deterministic Inputs, Noisy "Or" gate)
     - **A-CDM** (Additive CDM) / **LLM** (Linear Logistic Model) / **RRUM** (Reduced RUM)
   - 支援 Identity、Logit 與 Log 連結函數。

2. **貝氏估計的無縫擴充 (Bayesian MCMC via Turing.jl)**：
   - 採用 Julia 最先進的 **Package Extensions** 機制，維持核心套件的極速載入。
   - 只要在環境中載入 `Turing.jl` (`using Turing`)，即可解鎖 `fit_mcmc` 引擎，使用進階的 NUTS (No-U-Turn Sampler) 進行貝氏馬可夫蒙地卡羅 (MCMC) 抽樣與參數推論。

3. ** Louis (1982) 精準標準誤 (Louis Standard Errors)**：
   - 完整實作了 Louis (1982) 的經驗交叉乘積矩陣法。
   - 結合 `ForwardDiff.jl` 自動微分技術，實現精確且免手刻導數的梯度計算，提供極具學術嚴謹性的項目參數標準誤 (Standard Errors)。

4. **進階認知模型支援**：
   - 內建 `expand_sequential_data` 等資料擴展工具，支援 **Sequential G-DINA** 等 polytomous (多元計分) 的項目反應分析。

5. **大模型時代的 MCP 伺服器**：
   - 在 `src/mcp_server.jl` 中實作了標準 JSON-RPC 2.0 的 Model Context Protocol。
   - 讓 LLM Agents 可以將您的 Julia 套件作為 Tool 調用，實現自動化數據估計與診斷報告生成。

6. **現代化 API 文件**：
   - 使用 `Documenter.jl` 自動生成高可讀性、支援 LaTeX 數學公式渲染的 API 文件與使用手冊。

---

## 🛠️ 安裝

目前本套件可直接透過 Git 庫或本地進行開發安裝：

```julia
using Pkg
# 從 GitHub 安裝 (請替換為您的 Git 網址)
Pkg.add(url="https://github.com/yourusername/GDINA.jl.git")
```

若要在本地進行開發，請在專案根目錄下啟動 Julia：

```bash
julia --project=.
```
並在 REPL 中鍵入 `]` 進入套件模式後執行 `instantiate`：
```julia
(GDINA) pkg> instantiate
```

---

## 🚀 快速上手

### 1. 使用 EM 演算法估計 G-DINA 模型

```julia
using GDINA

# 模擬或載入數據
# Y: N × J 的作答反應矩陣 (0/1)
# Q: J × K 的 Q-矩陣 (0/1)
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

# 估計 G-DINA 模型 (預設使用 Identity 連結函數)
model_em = fit_em(Y, Q; model=:GDINA, max_iter=200, tol=1e-4)

# 查看估計出的項目參數 (如: 答對機率)
println("Estimated Item Parameters: ", model_em.P)

# 估計學生的潛在屬性 (EAP, MAP, MLE)
est_eap = person_eap(model_em)
println("Students' Latent Attribute Profiles (EAP): ", est_eap)
```

### 2. 使用 MCMC (貝氏) 估計 DINA 模型

只要在環境中載入 `Turing`，`GDINA.jl` 就會自動載入貝氏估計擴充：

```julia
using GDINA
using Turing  # 啟動 Extension

# 使用 MCMC 進行估計
model_mcmc = fit_mcmc(Y, Q; model=:DINA, n_samples=1000, n_adapts=500)

# 取得鏈的摘要或後驗均值
println("Bayesian Posterior Estimates: ", model_mcmc.posterior_means)
```

---

## 🤖 AI Agent 整合：啟動 MCP 伺服器

`GDINA.jl` 專為 AI 輔助工作流設計。若要啟動 MCP 伺服器，讓 Cursor 或 Claude 能自動呼叫此套件分析資料：

1. 在終端機執行啟動腳本：
   ```bash
   julia --project=@. src/mcp_server.jl
   ```

2. 在您的 IDE (如 Cursor) 或 Claude Desktop 設定檔中加入此 MCP 伺服器：
   ```json
   {
     "mcpServers": {
       "gdina-jl": {
         "command": "julia",
         "args": ["--project=/absolute/path/to/GDINA.jl", "/absolute/path/to/GDINA.jl/src/mcp_server.jl"]
       }
     }
   }
   ```
之後，您就可以在聊天框中對 AI 說：**「幫我用本地的 GDINA 伺服器分析這份學生作答 CSV 檔，並產出一份診斷報告。」** AI 將會自動呼叫套件並完成分析！

---

## 📚 生成 API 文檔

本套件採用 `Documenter.jl` 構建文檔。在本地建置並檢視文件：

```bash
julia --project=docs docs/make.jl
```
編譯完成後，用瀏覽器打開 `docs/build/index.html` 即可閱讀精美的本地文檔。

---

## 🧪 運行測試

本套件內建豐富的單元測試，涵蓋各連結函數、邊際概率計算、標準誤估計與貝氏擴充。

```julia
using Pkg
Pkg.test("GDINA")
```
或者在終端機中執行：
```bash
julia --project=. test/runtests.jl
```

---

## 📂 專案結構

```text
GDINA.jl/
├── Project.toml              # 套件宣告與依賴關係
├── src/
│   ├── GDINA.jl              # 主模組與匯出 API 入口
│   ├── types.jl              # 模型型別與連結函數定義
│   ├── em.jl                 # EM 演算法主迴圈與估計邏輯
│   ├── likelihood.jl         # 觀測似然度與邊際概率計算
│   ├── person_params.jl      # 人員屬性估計 (EAP/MAP/MLE)
│   ├── se.jl                 # Louis (1982) 標準誤與 ForwardDiff 自動微分
│   ├── advanced_models.jl    # Polytomous / Sequential G-DINA 數據展開
│   └── mcp_server.jl         # MCP (Model Context Protocol) 伺服器
├── ext/
│   └── GDINABayesExt/        # 貝氏擴充模組 (Turing.jl 的 Package Extension)
├── test/
│   └── runtests.jl           # 完整單元測試套件
└── docs/
    ├── make.jl               # Documenter.jl 構建指令
    └── src/                  # 文檔 Markdown 原始檔
```

---

## 📄 授權條款

本專案採用 **MIT License** 授權。歡迎學術界與業界自由使用、修改並貢獻代碼！
