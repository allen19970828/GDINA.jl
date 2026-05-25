using GDINA
using Test

@testset "Design Matrices" begin
    # Saturated GDINA
    m_sat = GDINA.designmatrix(2, GDINA.SaturatedGDINA())
    @test size(m_sat) == (4, 4)
    # [0,0]: int only
    @test m_sat[1, :] == [1.0, 0.0, 0.0, 0.0]
    # [1,1]: int, A1, A2, A1xA2
    @test m_sat[4, :] == [1.0, 1.0, 1.0, 1.0]

    # DINA
    m_dina = GDINA.designmatrix(2, GDINA.DINA())
    @test size(m_dina) == (4, 2)
    @test m_dina[1, :] == [1.0, 0.0]
    @test m_dina[3, :] == [1.0, 0.0]
    @test m_dina[4, :] == [1.0, 1.0]

    # DINO
    m_dino = GDINA.designmatrix(2, GDINA.DINO())
    @test size(m_dino) == (4, 2)
    @test m_dino[1, :] == [1.0, 0.0]
    @test m_dino[2, :] == [1.0, 1.0]
    @test m_dino[4, :] == [1.0, 1.0]

    # ACDM
    m_acdm = GDINA.designmatrix(2, GDINA.ACDM())
    @test size(m_acdm) == (4, 3)
    @test m_acdm[1, :] == [1.0, 0.0, 0.0]
    @test m_acdm[2, :] == [1.0, 1.0, 0.0]
    @test m_acdm[4, :] == [1.0, 1.0, 1.0]
end
