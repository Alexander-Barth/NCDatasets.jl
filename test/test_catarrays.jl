if VERSION >= v"0.7"
    using Test
else
    using Base.Test
    using Compat
    using Compat: cat
end

using NCDatasets

A = [randn(2,3),randn(2,3),randn(2,3)]

C = cat(A...; dims = 3)
CA = CatArrays.CatArray(3,A...)

idx_global,idx_local,sz = CatArrays.idx_global_local_(CA,(1:1,1:1,1:1))

@inferred CatArrays.idx_global_local_(CA,(1:1,1:1,1:1))

@testset "CatArrays" begin
    @test CA[1:1,1:1,1:1] == C[1:1,1:1,1:1]
    @test CA[1:1,1:1,1:2] == C[1:1,1:1,1:2]
    @test CA[1:2,1:1,1:2] == C[1:2,1:1,1:2]


    @test CA[:,:,1] == C[:,:,1]
    @test CA[:,:,2] == C[:,:,2]
    @test CA[:,2,:] == C[:,2,:]
    @test CA[:,1:2:end,:] == C[:,1:2:end,:]
    @test CA[1,1,1] == C[1,1,1]
end


