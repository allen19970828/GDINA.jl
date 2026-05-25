using GDINA
using Test
using Random
using Turing
using MCMCChains

@testset "Bayesian Estimation (GDINABayesExt)" begin
    # Create simple data
    qmat = [1 0; 0 1; 1 1]
    
    # N=20 responses to make it fast
    Random.seed!(42)
    dat = rand((0, 1), 20, 3)
    
    # Run GDINA with Bayesian MCMC
    # We use very few iterations for testing speed
    res_bayes = gdina(dat, qmat, model=:GDINA, method=:MCMC, mcmc_iter=10, n_chains=1, mcmc_warmup=10)
    
    @test res_bayes isa GDINA.BayesGDINAResult
    @test res_bayes.n_chains == 1
    @test res_bayes.n_samples == 10
    
    # Check that chains object is present
    @test res_bayes.chains !== nothing
    
    # Check that the dummy point estimate has correct dimensions
    pt = res_bayes.point_estimate
    @test pt.nitems == 3
    @test length(pt.att_prior) == 4
    
    # It should correctly have sampled pi_c
    pi_samples = pt.att_prior
    @test sum(pi_samples) ≈ 1.0 atol=1e-5
end
