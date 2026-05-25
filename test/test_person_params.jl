using GDINA
using Test
using Random

@testset "Inference & Person Params (Phase 4)" begin
    # 1. Create Data and Model
    qmat = [1 0; 0 1; 1 1]
    
    Random.seed!(42)
    # Give some structured responses: 
    # Person 1 has profile [0, 0] -> gets all 0
    # Person 2 has profile [1, 0] -> gets item 1 correct
    # Person 3 has profile [0, 1] -> gets item 2 correct
    # Person 4 has profile [1, 1] -> gets all 1
    dat_raw = [
        0 0 0;
        1 0 0;
        0 1 0;
        1 1 1;
    ]
    # N=4 is too small for EM to converge reliably, let's duplicate 10 times
    dat = repeat(dat_raw, 10, 1)
    
    res = gdina(dat, qmat, model=:GDINA)
    
    # 2. Test Person Parameters
    # EAP
    eap = person_eap(res)
    @test size(eap) == (40, 2)
    @test all(0 .<= eap .<= 1)
    
    # MAP
    map_prof = person_map(res)
    @test size(map_prof) == (40, 2)
    @test all(in.(map_prof, Ref([0, 1])))
    
    # MLE
    mle_prof = person_mle(res, dat)
    @test size(mle_prof) == (40, 2)
    @test all(in.(mle_prof, Ref([0, 1])))
    
    # 3. Test Standard Errors
    # Empirical Cross-Product Method
    se_list = standard_error(res, dat)
    
    @test length(se_list) == 3 # 3 items
    for j in 1:3
        # SE should be positive
        @test all(se_list[j] .>= 0.0)
    end
end
