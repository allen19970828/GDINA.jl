using GDINA
using Test

@testset "Types and Constructors" begin
    # Test QMatrix
    mat = [1 0; 0 1; 1 1]
    q = QMatrix(mat)
    @test q.nitems == 3
    @test q.natt == 2
    @test q.Kj == [1, 1, 2]
    @test q.req_att[1] == [1]
    @test q.req_att[3] == [1, 2]

    # Test ResponseData
    dat = [1 0 missing; 0 1 1]
    rd = ResponseData(dat)
    @test rd.npersons == 2
    @test rd.nitems == 3
    @test rd.nmissing == 1
    @test ismissing(rd.data[1, 3])
    @test rd.data[1, 1] == 1
end
