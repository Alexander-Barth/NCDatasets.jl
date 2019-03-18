using NCDatasets
if VERSION >= v"0.7.0-beta.0"
    using Test
    using Dates
    using Printf
else
    using Base.Test
end

using Compat

println("NetCDF library: ",NCDatasets.libnetcdf)
println("NetCDF version: ",NCDatasets.nc_inq_libvers())

@testset "NCDatasets" begin
    global v

    sz = (123,145)
    data = randn(sz)

    filename = tempname()
    ds = Dataset(filename,"c") do ds
        defDim(ds,"lon",sz[1])
        defDim(ds,"lat",sz[2])
        v = defVar(ds,"var",Float64,("lon","lat"))
        v[:,:] = data
    end

    ds = Dataset(filename)
    v = ds["var"]

    A = v[:,:]
    @test A == data

    A = v[1:1:end,1:1:end]
    @test A == data

    A = v[1:end,1:1:end]
    @test A == data

    v[1,1] == data[1,1]
    @test v[end,end] == data[end,end]

    close(ds)



    # Create a NetCDF file

    sz = (4,5)
    filename = tempname()
    #filename = "/tmp/test-2.nc"
    # The mode "c" stands for creating a new file (clobber)
    ds = NCDatasets.Dataset(filename,"c")

    # define the dimension "lon" and "lat"
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    # define a global attribute
    ds.attrib["title"] = "this is a test file"


    v = NCDatasets.defVar(ds,"temperature",Float32,("lon","lat"))
    S = NCDatasets.defVar(ds,"salinity",Float32,("lon","lat"))

    data = [Float32(i+2*j) for i = 1:sz[1], j = 1:sz[2]]

    # write a single value
    for j = 1:sz[2]
        for i = 1:sz[1]
            v[i,j] = data[i,j]
        end
    end
    @test v[:,:] == data

    # write a single column
    for j = 1:sz[2]
        v[:,j] = 2*data[:,j]
    end
    @test v[:,:] == 2*data

    # write a the complete data set
    v[:,:] = 3*data
    @test v[:,:] == 3*data

    # test sync
    NCDatasets.sync(ds)
    NCDatasets.close(ds)

    # Load a file (with unknown structure)

    ds = NCDatasets.Dataset(filename,"r")

    # check if a file has a variable with a given name
    @test NCDatasets.haskey(ds,"temperature")
    @test "temperature" in ds

    # get an list of all variable names
    @test "temperature" in NCDatasets.keys(ds)

    # iterate over all variables
    for (varname,var) in ds
        @test typeof(varname) == String
    end

    # query size of a variable (without loading it)
    v = ds["temperature"]
    @test typeof(size(v)) == Tuple{Int,Int}

    # iterate over all attributes
    for (attname,attval) in ds.attrib
        @test typeof(attname) == String
    end

    close(ds)

    # when opening a Dataset with a do block, it will be closed automatically
    # when leaving the do block.

    NCDatasets.Dataset(filename,"r") do ds
        data = ds["temperature"][:,:]
    end



    # define scalar
    filename = tempname()
    NCDatasets.Dataset(filename,"c") do ds
        v = NCDatasets.defVar(ds,"scalar",Float32,())
        v[:] = 123.f0
    end

    NCDatasets.Dataset(filename,"r") do ds
        v2 = ds["scalar"][:]
        @test typeof(v2) == Float32
        @test v2 == 123.f0
    end
    rm(filename)

    # define scalar with .=
    filename = tempname()
    NCDatasets.Dataset(filename,"c") do ds
        v = NCDatasets.defVar(ds,"scalar",Float32,())
        v .= 1234.f0
        nothing
    end

    NCDatasets.Dataset(filename,"r") do ds
        v2 = ds["scalar"][:]
        @test v2 == 1234
    end
    rm(filename)

    include("test_append.jl")

    include("test_append2.jl")

    include("test_attrib.jl")

    include("test_writevar.jl")
    include("test_scaling.jl")

    include("test_fillvalue.jl")

    include("test_compression.jl")

    include("test_formats.jl")

    include("test_bitarray.jl")

    # error handling
    @test_throws NCDatasets.NetCDFError Dataset("file","not-a-mode")
    @test_throws NCDatasets.NetCDFError Dataset(":/does/not/exist")

    include("test_variable.jl")

    include("test_variable_unlim.jl")

    include("test_strings.jl")
    include("test_lowlevel.jl")

    include("test_ncgen.jl")
    include("test_varbyatt.jl")

    include("test_corner_cases.jl")

    # display
    buf = IOBuffer()
    filename = tempname()
    closedvar = NCDatasets.Dataset(filename,"c") do ds
        # define the dimension "lon" and "lat" with the size 100 and 110 resp.
        NCDatasets.defDim(ds,"lon",100)
        NCDatasets.defDim(ds,"lat",110)

        # define a global attribute
        ds.attrib["title"] = "this is a test file"
        v = NCDatasets.defVar(ds,"temperature",Float32,("lon","lat"))
        v.attrib["units"] = "degree Celsius"

        show(buf,ds)
        @test occursin("temperature",String(take!(buf)))

        show(buf,ds.attrib)
        @test occursin("title",String(take!(buf)))

        show(buf,ds["temperature"])
        @test occursin("temperature",String(take!(buf)))

        show(buf,ds["temperature"].attrib)
        @test occursin("Celsius",String(take!(buf)))
        v
    end

    # test displaying closed dataset
    show(buf,ds)
    @test occursin("closed",String(take!(buf)))

    show(buf,ds.attrib)
    @test occursin("closed",String(take!(buf)))

    show(buf,closedvar)
    @test occursin("closed",String(take!(buf)))

    include("test_cfconventions.jl")
    include("test_cont_ragged_array.jl")
end

@testset "NetCDF4 groups" begin
    include("test_group.jl")
    include("test_group2.jl")
end

@testset "Variable-length arrays" begin
    include("test_vlen_lowlevel.jl")
    include("test_vlen.jl")
end

@testset "Time and calendars" begin
    include("test_time.jl")
    include("test_timeunits.jl")
end

@testset "Multi-file datasets" begin
    include("test_catarrays.jl")
end

@testset "Deferred datasets" begin
    include("test_defer.jl")
end

