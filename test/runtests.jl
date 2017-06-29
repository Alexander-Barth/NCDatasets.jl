using NCDatasets
using Base.Test

sz = (123,145)
data = randn(sz)

filename = "/tmp/test1.nc"
ds = Dataset(filename,"c") do ds
    defDim(ds,"lon",sz[1])
    defDim(ds,"lat",sz[2])
    v = defVar(ds,"var",Float64,("lon","lat"))
    v[:,:] = data
end

ds = Dataset(filename)
v = ds["var"]

println("NetCDF library: ",NCDatasets.libnetcdf)
println("NetCDF version: ",NCDatasets.nc_inq_libvers())

@testset "NCDatasets" begin

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

    filename = "/tmp/test-2.nc"
    # The mode "c" stands for creating a new file (clobber)
    ds = Dataset(filename,"c")

    # define the dimension "lon" and "lat" with the size 100 and 110 resp.
    defDim(ds,"lon",100)
    defDim(ds,"lat",110)

    # define a global attribute
    ds.attrib["title"] = "this is a test file"


    v = defVar(ds,"temperature",Float32,("lon","lat"))
    S = defVar(ds,"salinity",Float32,("lon","lat"))

    data = [Float32(i+j) for i = 1:100, j = 1:110]

    # write a single column
    v[:,1] = data[:,1]

    # write a the complete data set
    v[:,:] = data

    # write attributes
    v.attrib["units"] = "degree Celsius"
    v.attrib["comment"] = "this is a string attribute with unicode Ω ∈ ∑ ∫ f(x) dx "

    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
        # scalar attribute
        name = "scalar-attrib-$T"
        #@show name
        v.attrib[name] = T(123)

        if T == Int64
            # not supported in NetCDF, converted as Int32
            @test typeof(v.attrib[name]) == Int32
        else
            @test typeof(v.attrib[name]) == T
        end

        @test v.attrib[name] == 123


        # vector attribute
        name = "vector-attrib-$T"
        #@show name
        v.attrib[name] = T[1,2,3,4]

        if T == Int64
            # not supported in NetCDF, converted as Int32
            @test eltype(v.attrib[name]) == Int32
        else
            @test eltype(v.attrib[name]) == T
        end

        @test v.attrib[name] == [1,2,3,4]
    end


    

    close(ds)

    # Load a file (with known structure)

    # The mode "c" stands for creating a new file (clobber)
    ds = Dataset(filename,"r")
    v = ds["temperature"]

    # load a subset
    subdata = v[10:30,30:5:end]

    # load all data
    data = v[:,:]

    # load an attribute
    unit = v.attrib["units"]
    close(ds)

    # Load a file (with unknown structure)

    ds = Dataset(filename,"r")

    # check if a file has a variable with a given name
    if "temperature" in ds
        println("The file has a variable 'temperature'")
    end

    # get an list of all variable names
    @test "temperature" in keys(ds)

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

    # when opening a Dataset with a do block, it will be closed automatically when leaving the do block.

    Dataset(filename,"r") do ds
        data = ds["temperature"][:,:]    
    end



    # define scalar
    
    filename = tempname()
    filename = "/tmp/toto.nc"
    
    Dataset(filename,"c") do ds
        v = defVar(ds,"scalar",Float32,())
        v[:] = 123.f0
    end
    
    Dataset(filename,"r") do ds
        v2 = ds["scalar"][:]
        @test typeof(v2) == Float32
        @test v2 == 123.f0
    end
    rm(filename)

    # time
    filename = "/tmp/toto3.nc"
    
    Dataset(filename,"c") do ds
        defDim(ds,"time",3)            
        v = defVar(ds,"time",Float64,("time",))
        v.attrib["units"] = "days since 2000-01-01 00:00:00"
        v[:] = [DateTime(2000,1,2), DateTime(2000,1,3), DateTime(2000,1,4)]
        #v.var[:] = [1.,2.,3.]
    end
    
    Dataset(filename,"r") do ds
        v2 = ds["time"].var[:]
        @test v2[1] == 1.

        v2 = ds["time"][:]
        @test v2[1] == DateTime(2000,1,2)
    end
    #rm(filename)

    include("test_scaling.jl")

    # error handling
    @test_throws NCDatasets.NetCDFError Dataset(":/does/not/exist")


    # display
    s = IOBuffer()
    filename = "/tmp/toto3.nc"    
    Dataset(filename,"c") do ds
        # define the dimension "lon" and "lat" with the size 100 and 110 resp.
        defDim(ds,"lon",100)
        defDim(ds,"lat",110)
        
        # define a global attribute
        ds.attrib["title"] = "this is a test file"       
        v = defVar(ds,"temperature",Float32,("lon","lat"))
        v.attrib["units"] = "degree Celsius"
        
        show(s,ds)
        @test contains(String(take!(s)),"temperature")

        show(s,ds.attrib)
        @test contains(String(take!(s)),"title")

        show(s,ds["temperature"])
        @test contains(String(take!(s)),"temperature")

        show(s,ds["temperature"].attrib)
        @test contains(String(take!(s)),"Celsius")
    end

end
