using GDINA
using Test
using SparseArrays

@testset "Utils" begin
    # attributepattern
    K = 3
    pat = GDINA.attributepattern(K)
    @test size(pat) == (8, 3)
    @test pat[1, :] == [false, false, false]
    @test pat[2, :] == [true, false, false]
    @test pat[3, :] == [false, true, false]
    @test pat[4, :] == [true, true, false]
    @test pat[8, :] == [true, true, true]

    # latent_group_map
    qmat = [1 0; 1 1]
    q = QMatrix(qmat)
    pat2 = GDINA.attributepattern(2)
    lmap = GDINA.latent_group_map(q, pat2)
    
    @test length(lmap) == 2
    # Item 1 needs attr 1. 
    # classes: [0,0]->1, [1,0]->2, [0,1]->1, [1,1]->2
    @test lmap[1] == [1, 2, 1, 2]
    # Item 2 needs attr 1 and 2.
    # classes: [0,0]->1, [1,0]->2, [0,1]->3, [1,1]->4
    @test lmap[2] == [1, 2, 3, 4]

    # bdiag_matrix
    M1 = [1.0 2.0; 3.0 4.0]
    M2 = [5.0 6.0]
    B = GDINA.bdiag_matrix([M1, M2])
    @test size(B) == (3, 4)
    @test B[1, 1] == 1.0
    @test B[3, 3] == 5.0
    @test B[3, 1] == 0.0
end
