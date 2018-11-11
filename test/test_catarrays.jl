if VERSION >= v"0.7"
    using Test
else
    using Base.Test
    using Compat
    using Compat: cat, @debug
end

using NCDatasets

function example_file(i,array)
    fname = "/tmp/filename_$(i).nc"
    if isfile(fname)
        rm(fname)
    end
    @debug begin
        @show fname
    end
    Dataset(fname,"c") do ds
        # Dimensions

        ds.dim["lon"] = size(array,1)
        ds.dim["lat"] = size(array,2)
        ds.dim["time"] = Inf

        # Declare variables

        ncvar = defVar(ds,"var", Float64, ("lon", "lat", "time"))
        ncvar.attrib["field"] = "u-wind, scalar, series"
        ncvar.attrib["units"] = "meter second-1"
        ncvar.attrib["long_name"] = "surface u-wind component"
        ncvar.attrib["time"] = "time"
        ncvar.attrib["coordinates"] = "lon lat"


        nclat = defVar(ds,"lat", Float64, ("lon", "lat"))
        nclat.attrib["units"] = "degrees_north"
        nclat.attrib["point_spacing"] = "uneven"
        nclat.attrib["axis"] = "Y"

        nclon = defVar(ds,"lon", Float64, ("lon", "lat"))
        nclon.attrib["units"] = "degrees_east"
        nclon.attrib["modulo"] = 360.0
        nclon.attrib["point_spacing"] = "even"
        nclon.attrib["axis"] = "X"

        nctime = defVar(ds,"time", Float64, ("time",))
        nctime.attrib["long_name"] = "surface wind time"
        nctime.attrib["field"] = "time, scalar, series"
        nctime.attrib["units"] = "days since 2000-01-01 00:00:00 GMT"

        # Global attributes

        ds.attrib["history"] = "foo"

        # Define variables

        g = defGroup(ds,"group")
        ncvarg = defVar(g,"var", Float64, ("lon", "lat", "time"))
        ncvarg.attrib["field"] = "u-wind, scalar, series"
        ncvarg.attrib["units"] = "meter second-1"
        ncvarg.attrib["long_name"] = "surface u-wind component"
        ncvarg.attrib["time"] = "time"
        ncvarg.attrib["coordinates"] = "lon lat"

        ncvar[:,:,1] = array
        ncvarg[:,:,1] = array.+1
        # nclat[:] = ...
        # nclon[:] = ...
        nctime[:] = i
    end
    return fname
end



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


fnames = example_file.(1:3,A)




@testset "Multi-file" begin
    mfds = MFDataset(fnames);
    varname = "var"
    var = variable(mfds,varname);
    data = var[:,:,:]

    @test C == var[:,:,:]
    @test mfds.attrib["history"] == "foo"
    @test var.attrib["units"] == "meter second-1"

    @test dimnames(var) == ("lon", "lat", "time")
    # lon does not vary in time and thus there should be no aggregation
    lon = variable(mfds,"lon");
    @test lon.attrib["units"] == "degrees_east"
    @test size(lon) == (size(data,1),size(data,2))

    var = mfds[varname]
    @test C == var[:,:,:]
    @test dimnames(var) == ("lon", "lat", "time")

    @test mfds.dim["lon"] == size(C,1)
    @test mfds.dim["lat"] == size(C,2)
    @test mfds.dim["time"] == size(C,3)


    close(mfds)
end

