using NCDatasets
using Base.Test

sz = (123,145)
data = randn(sz)

filename = "/tmp/test1.nc"
ds = Dataset(filename,"c") do ds
    defDim(ds,"lon",123)
    defDim(ds,"lat",145)
    v = defVar(ds,"var",Float64,("lon","lat"))
    v[:,:] = data
end

ds = Dataset(filename)
v = ds["var"]

@testset "NCDatasets" begin

    @time A = v[:,:]
    @test A == data

    @time A = v[1:1:end,1:1:end]
    @test A == data

    @time A = v[1:end,1:1:end]
    @test A == data

    @test v[1,1] == data[1,1]
    @test v[end,end] == data[end,end]

    close(ds)

end


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
#v.attrib["units_s"] = Int16(111)
#v.attrib["units_i"] = Int32(111)
#v.attrib["units_i2"] = 111
#v.attrib["units_string"] = "this is a string attribute with unicode Ω ∈ ∑ ∫ f(x) dx "  


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
@show keys(ds)

# iterate over all variables
for (varname,var) in ds
    @show (varname,size(var))
end

# query size of a variable (without loading it)
v = ds["temperature"]
@show size(v)

# similar for global and variable attributes

if "title" in ds.attrib
    println("The file has the global attribute 'title'")
end

# get an list of all attribute names
@show keys(ds.attrib)

# iterate over all attributes
for (attname,attval) in ds.attrib
    @show (attname,attval)
end

close(ds)

# when opening a Dataset with a do block, it will be closed automatically when leaving the do block.

Dataset(filename,"r") do ds
    data = ds["temperature"][:,:]    
end


@testset "NCDatasets2" begin

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
        @show v2
        @test v2[1] == 1.

        v2 = ds["time"][:]
        @show v2
        @test v2[1] == DateTime(2000,1,2)
    end
    #rm(filename)
    
end
