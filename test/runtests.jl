using GDINA
using Test

@testset "GDINA.jl" begin
    include("test_types.jl")
    include("test_utils.jl")
    include("test_designmatrix.jl")
    include("test_em.jl")
    include("test_bayes.jl")
    include("test_person_params.jl")
    include("test_advanced.jl")
end
