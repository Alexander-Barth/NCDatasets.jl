# NCDatasets

[![Build Status Linux and macOS](https://travis-ci.org/Alexander-Barth/NCDatasets.jl.svg?branch=master)](https://travis-ci.org/Alexander-Barth/NCDatasets.jl)
[![Build Status Windows](https://ci.appveyor.com/api/projects/status/github/Alexander-Barth/NCDatasets.jl?branch=master&svg=true)](https://ci.appveyor.com/project/Alexander-Barth/ncdatasets-jl)

[![Coverage Status](https://coveralls.io/repos/Alexander-Barth/NCDatasets.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/Alexander-Barth/NCDatasets.jl?branch=master)
[![codecov.io](http://codecov.io/github/Alexander-Barth/NCDatasets.jl/coverage.svg?branch=master)](http://codecov.io/github/Alexander-Barth/NCDatasets.jl?branch=master)

[![documentation stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://alexander-barth.github.io/NCDatasets.jl/stable/)
[![documentation latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://alexander-barth.github.io/NCDatasets.jl/latest/)


`NCDatasets` allows one to read and create netCDF files.
NetCDF data set and attribute list behave like Julia dictionaries and variables like Julia arrays.


The module `NCDatasets` provides support for the following [netCDF CF conventions](http://cfconventions.org/):
* `_FillValue` will be returned as `missing` (DataArrays),
* `scale_factor` and `add_offset` are applied,
* time variables (recognized by the `units` attribute) are returned as `DateTime` objects.

The raw data can also be accessed (without the transformations above).

The module also includes an utility function `ncgen` which generates the Julia code that would produce a netCDF file with the same metadata as a template netCDF file.

## Installation

Inside the Julia shell, you can download and install the package by issuing:

```julia
Pkg.add("NCDatasets")
```

### Latest development version

If you want to try the latest development version, you can do this with the following commands:

```julia
Pkg.clone("https://github.com/Alexander-Barth/NCDatasets.jl")
Pkg.build("NCDatasets")
```

## Exploring the content of a netCDF file

Before reading the data from a netCDF file, it is often useful to explore the list of variables and attributes defined in it.

For interactive use, the following commands (without ending semicolon) display the content of the file similarly to `ncdump -h file.nc`

```julia
using NCDatasets
ds = Dataset("file.nc")
```

The following displays the information just for the variable `varname` and for the global attributes:

```julia
ds["varname"]
ds.attrib
```

## Create a netCDF file

The following gives an example of how to create a netCDF file by defining dimensions, variables and attributes.

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

## Create a netCDF file from a template

```julia
# download example file
ncfile = download("https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc")
# generate Julia code
ncgen(ncfile)
```

The produces the Julia code (only the beginning of the code is shown):

```julia
ds = Dataset("filename.nc","c")
# Dimensions

ds.dim["lat"] = 128;
ds.dim["lon"] = 256;
ds.dim["bnds"] = 2;
ds.dim["plev"] = 17;
ds.dim["time"] = 1;

# Declare variables

ncarea = defVar(ds,"area", Float32, ("lon", "lat"))
ncarea.attrib["long_name"] = "Surface area";
ncarea.attrib["units"] = "meter2";
# ...
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

In the example above, the subset can also be loaded with:

```julia
subdata = Dataset("/tmp/test.nc")["temperature"][10:30,30:5:end]
```

This might be useful in an interactive session. However, the file `test.nc` is not closed, which can be a problem if you open many files. On Linux the number of opened files is often limited to 1024 (soft limit). If you write to a file, you should also always close the file to make sure that the data is properly written to the disk.

An alternative way to ensure the file has been closed is to use a `do` block: the file will be closed automatically when leaving the block.

```julia
Dataset(filename,"r") do ds
    data = ds["temperature"][:,:]
end # ds is closed
```


## Load a file (with unknown structure)

If the structure of the netCDF file is not known before-hand, the program must check if a variable or attribute exists (with the `in` operator) before loading it or alternatively place the loading in a `try`-`catch` block.
It is also possible to iterate over all variables or attributes (global attributes or variable attributes) in the same syntax as iterating over a dictionary. However, unlike Julia dictionaries, the order of the attributes and variables is preserved and presented as they are stored in the netCDF file.


```julia
# Open a file as read-only
ds = Dataset("/tmp/test.nc","r")

# check if a file has a variable with a given name
if haskey(ds,"temperature")
    println("The file has a variable 'temperature'")
end

# get a list of all variable names
@show keys(ds)

# iterate over all variables
for (varname,var) in ds
    @show (varname,size(var))
end

# query size of a variable (without loading it)
v = ds["temperature"]
@show size(v)

# similar for global and variable attributes

if haskey(ds.attrib,"title")
    println("The file has the global attribute 'title'")
end

# get an list of all attribute names
@show keys(ds.attrib)

# iterate over all attributes
for (attname,attval) in ds.attrib
    @show (attname,attval)
end

# get the attribute "units" of the variable v
# but return the default value (here "adimensional")
# if the attribute does not exists

units = get(v,"units","adimensional")
close(ds)
```

## Get one or several variables by specifying the value of an attribute

The variable name are not always standardized, for example the longitude we can
find: `lon`, `LON`, `longitude`, ...

The solution implemented in the function `varbyattrib` consists in searching for the
variables that have specified value for a given attribute.

```julia
lon = varbyattrib(ds, standard_name="longitude");
```
will return the list of variables of the dataset `ds` that have "longitude"
as standard name. 

# Filing an issue

When you file an issue, please include sufficient information that would _allow somebody else to reproduce the issue_, in particular:
1. Provide the code that generates the issue.
2. If necessary to run your code, provide the used netCDF file(s).
3. Make your code and netCDF file(s) as simple as possible (while still showing the error and being runnable). A big thank you for the 5-star-premium-gold users who do not forget this point! 👍🏅🏆
4. The full error message that you are seeing (in particular file names and line numbers of the stack-trace).
5. Which version of Julia and `NCDatasets` are you using? Please include the output of:
```
versioninfo()
Pkg.installed()["NCDatasets"]
```
6. Does `NCDatasets` pass its test suite? Please include the output of:

```julia
Pkg.test("NCDatasets")
```

# Alternative

The package [NetCDF.jl](https://github.com/JuliaGeo/NetCDF.jl) from Fabian Gans and contributors is an alternative to this package which supports a more Matlab/Octave-like interface for reading and writing NetCDF files.

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
<!--  LocalWords:  Biogeochemie macOS haskey runnable versioninfo
 -->
