using GDINA
using Test

@testset "Advanced Models (Phase 5)" begin
    @testset "Sequential G-DINA Data Expansion" begin
        # 3 examinees, 2 items
        # Item 1 max score = 2
        # Item 2 max score = 3
        # Total pseudo-items = 5
        
        data = [
            0  missing; # Person 1: failed step 1 of item 1, item 2 missing
            1  3;       # Person 2: passed step 1, failed step 2 of item 1. max score on item 2.
            2  0;       # Person 3: passed both steps of item 1. failed step 1 of item 2.
            3  2        # Person 4: invalid score (3 > 2) clamped to 2 for item 1. passed 1, 2, failed 3 for item 2.
        ]
        categories = [2, 3]
        
        exp_data = expand_sequential_data(data, categories)
        
        @test size(exp_data) == (4, 5)
        
        # Person 1
        @test isequal(exp_data[1, :], [0, missing, missing, missing, missing])
        
        # Person 2
        @test isequal(exp_data[2, :], [1, 0, 1, 1, 1])
        
        # Person 3
        @test isequal(exp_data[3, :], [1, 1, 0, missing, missing])
        
        # Person 4 (clamps 3->2 for item 1)
        @test isequal(exp_data[4, :], [1, 1, 1, 1, 0])
        
        # Test error throwing on length mismatch
        @test_throws ArgumentError expand_sequential_data(data, [2, 3, 4])
    end

    @testset "Nominal/MC-DINA Data Expansion" begin
        # 3 examinees, 2 nominal items
        # Item 1 has 3 options (1, 2, 3)
        # Item 2 has 4 options (1, 2, 3, 4)
        
        data = [
            1  4;
            2  missing;
            3  1;
            0  5; # invalid options -> treated as missing
        ]
        categories = [3, 4]
        
        exp_data = expand_nominal_data(data, categories)
        @test size(exp_data) == (4, 7)
        
        # Person 1 chose option 1 for item 1, option 4 for item 2
        @test isequal(exp_data[1, :], [1, 0, 0,  0, 0, 0, 1])
        
        # Person 2 chose option 2 for item 1, missing for item 2
        @test isequal(exp_data[2, :], [0, 1, 0,  missing, missing, missing, missing])
        
        # Person 3 chose option 3 for item 1, option 1 for item 2
        @test isequal(exp_data[3, :], [0, 0, 1,  1, 0, 0, 0])
        
        # Person 4 has invalid choices (0 and 5), should be all missing
        @test isequal(exp_data[4, :], [missing, missing, missing,  missing, missing, missing, missing])
        
        @test_throws ArgumentError expand_nominal_data(data, [3, 4, 5])
    end
end
