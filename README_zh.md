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

## 🤖 AI Agent 整合：本地端 MCP 伺服器部署與使用手冊

`GDINA.jl` 內建了標準的 Model Context Protocol (MCP) 伺服器，能讓您的 AI 助手（如 Claude Desktop 或 Cursor IDE）直接將本套件作為本地工具呼叫，自動為您進行統計模型估計與數據分析！

### 1. 準備工作：初始化環境依賴
在首次執行 MCP 伺服器前，請確保套件的依賴（如 `JSON3`、`CSV`、`DataFrames`）已在本機環境中完整下載與初始化：
```bash
julia --project=@. -e 'using Pkg; Pkg.instantiate()'
```

### 2. 對接 Claude Desktop
若要將伺服器整合至 **Claude Desktop**，請開啟您的設定檔：
*   **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
*   **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

在 `mcpServers` 區塊下加入 `gdina-jl` 的配置（請務必將 `/absolute/path/to/GDINA.jl` 替換為您本機中該專案的**絕對路徑**）：
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
儲存後，重新啟動 Claude Desktop 即可生效。

### 3. 對接 Cursor IDE（強力推薦！）
若要整合至 **Cursor** 編輯器中：
1. 開啟 Cursor，點選右上角的 **Settings** ➡️ **Features** ➡️ **MCP**。
2. 點選 **+ Add New MCP Server**。
3. 填入以下配置：
   *   **Name**: `gdina-jl`
   *   **Type**: `stdio`
   *   **Command**: `julia --project=/absolute/path/to/GDINA.jl /absolute/path/to/GDINA.jl/src/mcp_server.jl` （請將路徑替換為您的本機絕對路徑）
4. 點選 **Save** 儲存。此時狀態燈應會顯示綠色，代表連線成功！

### 4. 使用方式與提示詞 (Prompt) 範例
連線成功後，您不需要手動啟動伺服器。當您在與 AI 對話時，只要直接把 CSV 檔案丟給它，並輸入以下指令即可：
> 「請幫我用本地的 `gdina-jl` MCP 伺服器，分析路徑在 `/absolute/path/to/responses.csv` 的學生作答反應檔，以及在 `/absolute/path/to/qmatrix.csv` 的 Q-矩陣。擬合一個 DINA 模型，並為我寫一份詳細的心理計量診斷報告。」

AI 助理收到後，會自動在背景啟動您的 Julia 引擎，估計項目參數（包含精準的 Louis 標準誤）、計算擬合指標，並自動將分析結果排版成精美的 Markdown 表格呈現給您！

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
