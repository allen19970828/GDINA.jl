module GDINA

using LinearAlgebra, SparseArrays, Statistics
using Distributions, LogExpFunctions
using Optim, ForwardDiff
using Printf

# 核心 API
export gdina, simgdina, qval, modelfit, modelcomp, dif
export personparm, coef, extract
export QMatrix, ResponseData, GDINAResult

# 子模組
include("types.jl")          # 型別定義
include("utils.jl")          # 工具函數
include("designmatrix.jl")   # 設計矩陣
include("likelihood.jl")     # 概似度計算
include("estep.jl")          # E-Step
include("mstep.jl")          # M-Step
include("em.jl")             # EM 主迴圈
# include("gdina_fit.jl")      # 使用者主入口
# include("submodels.jl")      # 子模型轉換
include("se.jl")             # 標準誤
include("person_params.jl")  # 人員參數受測者參數
include("advanced_models.jl")# 進階模型 (Sequential G-DINA, etc.)
# include("simulate.jl")       # 資料模擬
# include("qval.jl")           # Q 矩陣驗證
# include("modelfit.jl")       # 模型擬合度
# include("modelcomp.jl")      # 模型比較
# include("dif.jl")            # DIF 檢測
# include("sequential.jl")     # 序列 G-DINA（多分類）
# include("dtm.jl")            # 診斷樹模型
# include("mcmodel.jl")        # MC-DINA
# include("gmscdm.jl")         # 多策略模型
include("io.jl")             # I/O 與顯示

# 條件載入：貝氏模組（避免強制依賴 Turing.jl）
function __init__()
    @static if Base.identify_package("GDINABayesExt") !== nothing
        @info "GDINABayesExt extension available. Use method=:MCMC for Bayesian estimation."
    end
end

end # module
