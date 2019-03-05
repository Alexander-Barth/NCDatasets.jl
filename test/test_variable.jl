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
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64,
              Char,String]
    #for T in []
        local data
        data, scalar_data =
            if T == String
                [Char(i+60) * Char(j+60) for i = 1:sz[1], j = 1:sz[2]], "abcde"
            else
                [T(i+2*j) for i = 1:sz[1], j = 1:sz[2]], T(100)
            end

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

        @test v[[1,2,3],:] == data[[1,2,3],:]

        # write scalar,
        v.var[:,:] = scalar_data
        @test all(v.var[:,:][:] .== scalar_data)

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

    # load in-place
    data2 = similar(data)
    NCDatasets.load!(ds["temp"].var,data2,:,:)
    @test data2 == data

    data2 = zeros(eltype(data),sz[1],2)
    NCDatasets.load!(ds["temp"].var,data2,:,1:2)
    @test data2 == data[:,1:2]
end


# issue 23
# return type using CartesianIndex

if VERSION >= v"0.7.0-beta.0"
    filename = tempname()
    ds = Dataset(filename, "c");
    ds.dim["lon"] = 5;
    ds.dim["lat"] = 10;
    ds.dim["time"] = Inf;

    ncvar = defVar(ds, "var", Int64, ("lon", "lat", "time"));

    nt = 25;
    data = reshape(1:5*10*nt, 5, 10, nt);
    ncvar[:,:,1:nt] = data;
    close(ds);

    ds = Dataset(filename);
    start = 1;
    all(data[CartesianIndex(1, 1), start:end] .== ds["var"][CartesianIndex(1, 1), start:end])
    data11 = ds["var"][CartesianIndex(1, 1), start:end]
    close(ds)

    @test typeof(data11[1]) == Int64
    rm(filename)
end
