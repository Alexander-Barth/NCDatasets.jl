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
* `_FillValue` will be returned as `missing` ([more information](https://docs.julialang.org/en/latest/manual/missing/))
* `scale_factor` and `add_offset` are applied if present
* time variables (recognized by the `units` attribute) are returned as `DateTime` objects.
* Support of the [CF calendars](http://cfconventions.org/Data/cf-conventions/cf-conventions-1.7/cf-conventions.html#calendar) (standard, gregorian, proleptic gregorian, julian, all leap, no leap, 360 day)
* The raw data can also be accessed (without the transformations above).
* [Contiguous ragged array representation](http://cfconventions.org/Data/cf-conventions/cf-conventions-1.7/cf-conventions.html#_contiguous_ragged_array_representation)

Other features include:
* Support for NetCDF 4 compression and variable-length arrays (i.e. arrays of vectors where each vector can have potentailly a different length)
* The module also includes an utility function [`ncgen`](https://alexander-barth.github.io/NCDatasets.jl/stable/#NCDatasets.ncgen-Tuple{Any}) which generates the Julia code that would produce a netCDF file with the same metadata as a template netCDF file.

## Installation

Inside the Julia shell, you can download and install the package by issuing:

```julia
using Pkg
Pkg.add("NCDatasets")
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
which produces a listing the following:

```
Dataset: file.nc
Group: /

Dimensions
   time = 115

Variables
  time   (115)
    Datatype:    Float64
    Dimensions:  time
    Attributes:
     calendar             = gregorian
     standard_name        = time
     units                = days since 1950-01-01 00:00:00
[...]
```

## Create a netCDF file

The following gives an example of how to create a netCDF file by defining dimensions, variables and attributes.

```julia
using NCDatasets
# This creates a new NetCDF file /tmp/test.nc.
# The mode "c" stands for creating a new file (clobber)
ds = Dataset("/tmp/test.nc","c")

# Define the dimension "lon" and "lat" with the size 100 and 110 resp.
defDim(ds,"lon",100)
defDim(ds,"lat",110)

# Define a global attribute
ds.attrib["title"] = "this is a test file"

# Define the variables temperature
v = defVar(ds,"temperature",Float32,("lon","lat"))

# Generate some example data
data = [Float32(i+j) for i = 1:100, j = 1:110]

# write a single column
v[:,1] = data[:,1]

# write a the complete data set
v[:,:] = data

# write attributes
v.attrib["units"] = "degree Celsius"
v.attrib["comments"] = "this is a string attribute with Unicode Ω ∈ ∑ ∫ f(x) dx"

close(ds)
```

An equivalent way to create the previous netCDF would be the following code:

```julia
using NCDatasets
data = [Float32(i+j) for i = 1:100, j = 1:110]

Dataset("/tmp/test2.nc","c",attrib = ["title" => "this is a test file"]) do ds
    # Define the variable temperature. The dimension "lon" and "lat" with the
    # size 100 and 110 resp are implicetly created
    defVar(ds,"temperature",data,("lon","lat"), attrib = [
           "units" => "degree Celsius",
           "comments" => "this is a string attribute with Unicode Ω ∈ ∑ ∫ f(x) dx"
    ])
end
```

## Editing an existing netCDF

When you need to modify the variables or the attributes of a netCDF, you have
to open it with the `"a"` option. Here of instance we add a global attribute *creator* to the
file created in the previous step.

```julia
ds = Dataset("/tmp/test.nc","a")
ds.attrib["creator"] = "your name"
close(ds);
```



## Load a file

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
