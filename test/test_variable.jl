if VERSION >= v"0.7.0-beta.0"
    using Test
    using Dates
    using Printf
else
    using Base.Test
end
using NCDatasets


sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"

# The mode "c" stands for creating a new file (clobber)
NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat"
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    v = NCDatasets.defVar(ds,"small",Float64,("lon","lat"))
    @test_throws NCDatasets.NetCDFError v[:] = zeros(sz[1]+1,sz[2])
    #@test_throws NCDatasets.NetCDFError v[1:sz[1],1:sz[2]] = zeros(sz[1]+1,sz[2])
    @test_throws NCDatasets.NetCDFError v[sz[1]+1,1] = 1
    @test_throws NCDatasets.NetCDFError v[-1,1] = 1

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in []
        local data
        data = [T(i+2*j) for i = 1:sz[1], j = 1:sz[2]]

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = data
        @test v[:,:] == data[:,:]

        @test v[2,:] == data[2,:]

        @test v[:,3] == data[:,3]

        @test v[2,3] == data[2,3]

        # ignore extra index
        @test v[2,3,1,1] == data[2,3,1,1]

        # ignore extra index
        @test v[2:3,3,1,1] == data[2:3,3,1,1]


        # write scalar,
        v.var[:,:] = T(100)
        @test all(v.var[:,:][:] .== 100)

    end
end

# quick interface
Dataset(filename,"c") do ds
    data = Int32[i+3*j for i = 1:sz[1], j = 1:sz[2]]
    defVar(ds,"temp",data,("lon","lat"), attrib = [
        "units" => "degree_Celsius",
        "long_name" => "Temperature"
    ])
    @test ds["temp"][:] == data
    @test eltype(ds["temp"].var) == Int32
    @test ds.dim["lon"] == sz[1]
    @test ds.dim["lat"] == sz[2]
end
