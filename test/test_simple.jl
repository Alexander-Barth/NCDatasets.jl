    using NCDatasets
using Test
using Dates
using Printf
using Random

sz = (123,145)
data = randn(MersenneTwister(152), sz)

filename = tempname()
ds = NCDataset(filename,"c") do ds
    defDim(ds,"lon",sz[1])
    defDim(ds,"lat",sz[2])
    v = defVar(ds,"var",Float64,("lon","lat"))
    v[:,:] = data
end

ds = NCDataset(filename)
v = ds["var"]
@test v[:] == ds["var"][:]

A = v[:,:]
@test A == data

A = v[1:1:end,1:1:end]
@test A == data

A = v[1:end,1:1:end]
@test A == data

v[1,1] == data[1,1]
@test v[end,end] == data[end,end]

@test dimsize(v) == (lon = 123, lat = 145)
close(ds)

# Create a NetCDF file

sz = (4,5)
filename = tempname()
#filename = "/tmp/test-2.nc"
# The mode "c" stands for creating a new file (clobber)
ds = NCDataset(filename,"c")

# define the dimension "lon" and "lat"
ds.dim["lon"] = sz[1]
ds.dim["lat"] = sz[2]

# define a global attribute
ds.attrib["title"] = "this is a test file"


v = defVar(ds,"temperature",Float32,("lon","lat"))
S = defVar(ds,"salinity",Float32,("lon","lat"))

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

# write the complete data set
v[:,:] = 3*data
@test v[:,:] == 3*data

# test sync
sync(ds)
close(ds)
# close on closed file should not throw
close(ds)

# Load a file (with unknown structure)

ds = NCDataset(filename,"r")

# check if a file has a variable with a given name
@test haskey(ds,"temperature")
@test "temperature" in ds

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

# when opening a NCDataset with a do block, it will be closed automatically
# when leaving the do block.

NCDataset(filename,"r") do ds
    data = ds["temperature"][:,:]
end

# error handling
@test_throws NCDatasets.NetCDFError NCDataset("file","not-a-mode")
@test_throws NCDatasets.NetCDFError NCDataset(":/does/not/exist")
