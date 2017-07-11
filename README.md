# NCDatasets

[![Build Status](https://travis-ci.org/Alexander-Barth/NCDatasets.jl.svg?branch=master)](https://travis-ci.org/Alexander-Barth/NCDatasets.jl)

[![Coverage Status](https://coveralls.io/repos/Alexander-Barth/NCDatasets.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/Alexander-Barth/NCDatasets.jl?branch=master)

[![codecov.io](http://codecov.io/github/Alexander-Barth/NCDatasets.jl/coverage.svg?branch=master)](http://codecov.io/github/Alexander-Barth/NCDatasets.jl?branch=master)


`NCDatasets` allows to read and create NetCDF files.
NetCDF data set and attribute list behave like Julia dictionaries and variables like Julia arrays.


The module `NCDatasets` has support for the following NetCDF CF conventions:
* _FillValue will be returned as NA (DataArrays)
* `scale_factor` and `add_offset` are applied
* time variables (recognized by the `units` attribute) are returned as `DateTime` object.

The raw data can also be accessed (without the transformations above).


## Installation

Inside the Julia shell, you can download and install the package by issuing:

```julia
Pkg.clone("https://github.com/Alexander-Barth/NCDatasets.jl")
```

## Exploring the content of a NetCDF file

Before reading the data from a NetCDF file, it is often useful to explore the list of variables and attributes defined in a NetCDF file.

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

## Create a NetCDF file

The following gives an example of how to create a NetCDF file by defining dimensions, variables and attributes.

```julia
# This creates a new NetCDF file /tmp/test.nc.
# The mode "c" stands for creating a new file (clobber)
ds = Dataset("/tmp/test.nc","c")

# Define the dimension "lon" and "lat" with the size 100 and 110 resp.
defDim(ds,"lon",100)
defDim(ds,"lat",110)

# Define a global attribute
ds.attrib["title"] = "this is a test file"

# Define the variables temperature and salinity
v = defVar(ds,"temperature",Float32,("lon","lat"))
S = defVar(ds,"salinity",Float32,("lon","lat"))

# Generate some example data
data = [Float32(i+j) for i = 1:100, j = 1:110]

# write a single column
v[:,1] = data[:,1]

# write a the complete data set
v[:,:] = data

# write attributes
v.attrib["units"] = "degree Celsius"
v.attrib["units_string"] = "this is a string attribute with Unicode Ω ∈ ∑ ∫ f(x) dx"

close(ds)
```

## Load a file (with known structure)

Loading a variable with known structure can be achieved by accessing the variables and attributes directly by their name.

```julia
# The mode "r" stands for read-only. The mode "r" is the default mode and the parameter can be omitted.
ds = Dataset("/tmp/test.nc","r")
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

## Load a file (with unknown structure)


If the structure of the NetCDF file is not known before-hand, the program must check if a variable or attribute exist (with the `in` operator) before-loading it or alternatively place the loading in a `try`-`catch` block.
It is also possible to iterate over all variables or attributes (global attributes or variable attributes) in the same syntax as iterating over a dictionary. However, unlike Julia dictionaries, the order of the attributes and variables is preserved and presented as they are stored in the NetCDF file.


```julia
# Open a file as read-only 
ds = Dataset("/tmp/test.nc","r")

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

An alternative way to open a file is to use a `do` block. The file will be closed automatically when leaving the do block.

```julia
Dataset(filename,"r") do ds
    data = ds["temperature"][:,:]
end
```

# Issues

## libnetcdf not properly installed

If you see the following error,

```
ERROR: LoadError: LoadError: libnetcdf not properly installed. Please run Pkg.build("NCDatasets")
```

you can try to install netcdf explicitly with Conda:

```julia
using Conda
Conda.add("libnetcdf")
```

# Credits

`netcdf_c.jl`, `build.jl` and the error handling code of the NetCDF C API are from NetCDF.jl by Fabian Gans (Max-Planck-Institut für Biogeochemie, Jena, Germany) released under the MIT license.

<!--  LocalWords:  NCDatasets codecov io NetCDF FillValue DataArrays
 -->
<!--  LocalWords:  DateTime ncdump nc julia ds Dataset varname attrib
 -->
<!--  LocalWords:  lon defDim defVar dx subdata println attname jl
 -->
<!--  LocalWords:  attval filename netcdf API Gans Institut für Jena
 -->
<!--  LocalWords:  Biogeochemie
 -->
