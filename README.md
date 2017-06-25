# NCDatasets

[![Build Status](https://travis-ci.org/Alexander-Barth/NCDatasets.jl.svg?branch=master)](https://travis-ci.org/Alexander-Barth/NCDatasets.jl)

[![Coverage Status](https://coveralls.io/repos/Alexander-Barth/NCDatasets.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/Alexander-Barth/NCDatasets.jl?branch=master)

[![codecov.io](http://codecov.io/github/Alexander-Barth/NCDatasets.jl/coverage.svg?branch=master)](http://codecov.io/github/Alexander-Barth/NCDatasets.jl?branch=master)


`NCDatasets` allows to read and create NetCDF files.
NetCDF data set and attribute list behaviour like Julia dictionaries and variables like Julia Arrays.

However, unlike Julia dictionaries, the order of the attributes and variables is preserved as they a stored in the netCDF file.

For interactive use, the following (without ending semicolon) 
displays the content of the file similar to `ncdump -h file.nc"

```julia
using NCDatasets
ds = Dataset("file.nc")
```

The following displays the information just for the variable `varname` and the global attributes:

```julia
ds["varname"]
ds.attrib
```

Support for the NetCDF CF Convention:
* _FillValue will be returned as NA (DataArrays)
* `scale_factor` and `add_offset` are applied
* time variables (recognised by the `units` attribute) are returned as `DateTime` object.

The raw data can also be accessed (without the transformation above).


## Create a NetCDF file

```julia
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
v.attrib["units_string"] = "this is a string attribute with unicode Ω ∈ ∑ ∫ f(x) dx"

close(ds)
```

## Load a file (with known structure)

```julia
# The mode "c" stands for creating a new file (clobber)
ds = Dataset(filename,"r")
v = ds["temperature"]

# load a subset
subdata = v[10:30,30:5:end]

# load all data
data = v[:,:]

# load all data ignoring attributes like scale_factor, add_offset, _FillValue and time units
data2 = v.var[:,:]


# load an attribute
unit = v.attrib["units"]
close(ds)
```

# Load a file (with unknown structure)

```julia
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
```


An alternative way to open a file is to use a do block.

```julia
# when opening a Dataset with a do block, it will be closed automatically when leaving the do block.

Dataset(filename,"r") do ds
    data = ds["temperature"][:,:]
end
```

# Credits

`netcdf_c.jl`, `build.jl` and the error handling code of the NetCDF C API are from NetCDF.jl by Fabian Gans (Max-Planck-Institut für Biogeochemie, Jena, Germany) released under the MIT license.
