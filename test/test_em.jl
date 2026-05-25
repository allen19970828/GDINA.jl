using GDINA
using Test
using Random

@testset "EM Engine and Likelihood" begin
    # Create simple data
    # K=2 attributes, J=3 items. 
    # Item 1 needs attr 1
    # Item 2 needs attr 2
    # Item 3 needs attr 1 & 2
    qmat = [1 0; 0 1; 1 1]
    
    # N=10 responses
    Random.seed!(42)
    dat = rand((0, 1), 10, 3)
    
    # Run GDINA with Saturated model
    res_gdina = gdina(dat, qmat, model=:GDINA)
    
    @test res_gdina.nitems == 3
    @test res_gdina.npersons == 10
    @test res_gdina.n_iter > 0
    @test size(res_gdina.posterior) == (10, 4)
    
    # Check that parameters are bounded [0, 1]
    for j in 1:3
        probs = coef(res_gdina, :catprob)[j]
        @test all(0 .<= probs .<= 1)
    end
    
    # Run GDINA with DINA model
    res_dina = gdina(dat, qmat, model=:DINA)
    
    # DINA has 2 params per item = 6 total item params + 3 prior params = 9 parameters
    @test res_dina.npar == 9
    
    for j in 1:3
        probs = coef(res_dina, :catprob)[j]
        @test all(0 .<= probs .<= 1)
        # DINA only has 2 probabilities (guessing, 1-slip) for non-zero Kj
        # Kj for item 1,2 is 1 (groups: 2)
        # Kj for item 3 is 2 (groups: 4, but only 2 unique prob values usually)
    end
    
    # Mix models
    res_mix = gdina(dat, qmat, model=[:GDINA, :DINA, :DINO])
    @test res_mix.model_names == [:GDINA, :DINA, :DINO]
end
