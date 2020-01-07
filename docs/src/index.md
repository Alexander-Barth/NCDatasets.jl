# NCDatasets.jl

Documentation for NCDatasets.jl

## Installation

Inside the Julia shell, you can download and install the package by pressing `]` to go into package manager mode and then simply

```
add NCDatasets
```

### Latest development version

If you want to try the latest development version, again go into package manager mode and simply type

```
add NCDatasets#master
```

## Quickstart

This is a quickstart guide that outlines basic loading, reading, etc. usage.
For more details please see the individual pages of the documentation.


* [Explore the content of a netCDF file](#explore-the-content-of-a-netcdf-file)
* [Load a netCDF file](#load-a-netcdf-file)
* [Create a netCDF file](#create-a-netcdf-file)
* [Edit an existing netCDF file](#edit-an-existing-netcdf-file)
* [Create a netCDF file using the metadata of an existing netCDF file as template](@ref)
* [Get one or several variables by specifying the value of an attribute](@ref)
* [Load a file with unknown structure](@ref)

### Explore the content of a netCDF file

Before reading the data from a netCDF file, it is often useful to explore the list of variables and attributes defined in it.

For interactive use, the following commands (without ending semicolon) display the content of the file similarly to `ncdump -h file.nc`:

```julia
using NCDatasets
ds = Dataset("file.nc")
```

This creates the central structure of NCDatasets.jl, `Dataset`, which represents the contents of the netCDF file (without immediatelly loading everything in memory). `NCDataset` is an alias for `Dataset`.

The following displays the information just for the variable `varname`:

```julia
ds["varname"]
```

while to get the global attributes you can do:
```julia
ds.attrib
```
which produces a listing like:

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

### Load a netCDF file

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
data =
Dataset(filename,"r") do ds
    ds["temperature"][:,:]
end # ds is closed
```

### Create a netCDF file

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

### Edit an existing netCDF file

When you need to modify the variables or the attributes of a netCDF, you have
to open it with the `"a"` option. Here of instance we add a global attribute *creator* to the
file created in the previous step.

```julia
ds = Dataset("/tmp/test.nc","a")
ds.attrib["creator"] = "your name"
close(ds);
```

### Create a netCDF file using the metadata of an existing netCDF file as template

The utility function [`ncgen`](https://alexander-barth.github.io/NCDatasets.jl/stable/#NCDatasets.ncgen)
generates the Julia code that would produce a netCDF file with the same metadata as a template netCDF file.
It is thus similar to the [command line tool `ncgen`](https://www.unidata.ucar.edu/software/netcdf/netcdf/ncgen.html).

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

### Get one or several variables by specifying the value of an attribute

The variable name are not always standardized, for example the longitude we can
find: `lon`, `LON`, `longitude`, ...

The solution implemented in the function `varbyattrib` consists in searching for the
variables that have specified value for a given attribute.

```julia
nclon = varbyattrib(ds, standard_name="longitude");
```
will return the list of variables of the dataset `ds` that have "longitude"
as standard name. To directly load the data of the first variable with the
attribute `standard_name` equal to `"longitude"` one can the following:

```julia
data = varbyattrib(ds, standard_name = "longitude")[1][:]
```

### Load a file with unknown structure

If the structure of the netCDF file is not known before-hand, the program must check if a variable or attribute exists (with the `haskey` function) before loading it or alternatively place the loading in a `try`-`catch` block.
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


## Datasets

```@docs
Dataset
keys(ds::Dataset)
haskey
getindex(ds::Dataset,varname::AbstractString)
variable
sync
close
path
```

## Variables

```@docs
defVar
dimnames
name
nsize
chunking
deflate
checksum
loadragged
NCDatasets.load!
```

Different type of arrays are involved when working with NCDatasets. For instance assume that `test.nc` is a file with a `Float32` variable called `var`. Assume that we open this data set in append mode (`"a"`):

```julia
using NCDatasets
ds = Dataset("test.nc","a")
v_cf = ds["var"]
```

The variable `v_cf` has the type `CFVariable`. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, ... by the functions `size`, `ndims`, `length` as ordinary Julia arrays. Once you index, the variable `v_cf`, then the data is loaded and stored as an `Array`:

```julia
v_da = v_cf[:,:] # or v_da = v_cf[:]
```

Note that even if the variable `v_cf` has 2 (or more dimension), the index operation `v_cf[:]` preserves its actual shape and does not generate a flat vector of the data (unlike regular Julia arrays). As load operations are very common, it was consired advantageous to have a consice syntax.

### Coordinate variables

```@docs
coord
```



## Attributes

The NetCDF dataset (as return by `Dataset` or NetCDF groups) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.


```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
```

## Dimensions

```@docs
defDim
setindex!(d::NCDatasets.Dimensions,len,name::AbstractString)
dimnames(v::NCDatasets.Variable)
unlimited(d::NCDatasets.Dimensions)
```


## Groups

```@docs
defGroup(ds::Dataset,groupname)
getindex(g::NCDatasets.Groups,groupname::AbstractString)
Base.keys(g::NCDatasets.Groups)
```

## Common methods

One can iterate over a dataset, attribute list, dimensions and NetCDF groups.

```julia
for (varname,var) in ds
    # all variables
    @show (varname,size(var))
end

for (dimname,dim) in ds.dims
    # all dimensions
    @show (dimname,dim)
end

for (attribname,attrib) in ds.attrib
    # all attributes
    @show (attribname,attrib)
end

for (groupname,group) in ds.groups
    # all groups
    @show (groupname,group)
end
```


# Time functions

See DateTime-structures from [CFTime](http://juliageo.org/CFTime.jl/stable/) are used to represent time for non-standard calendars.

# Utility functions

```@docs
ncgen
nomissing
varbyattrib
```

# Multi-file support (experimental)

Multiple files can also be aggregated over a given dimensions (or the record dimension). In this example, 3 sea surface temperature fields from the
1992-01-01 to 1992-01-03 are aggregated using the OpenDAP service from PODAAC.

```
using NCDatasets, Printf, Dates

function url(dt)
  doy = @sprintf("%03d",Dates.dayofyear(dt))
  y = @sprintf("%04d",Dates.year(dt))
  yyyymmdd = Dates.format(dt,"yyyymmdd")
  return "https://podaac-opendap.jpl.nasa.gov:443/opendap/allData/ghrsst/data/GDS2/L4/GLOB/CMC/CMC0.2deg/v2/$y/$doy/$(yyyymmdd)120000-CMC-L4_GHRSST-SSTfnd-CMC0.2deg-GLOB-v02.0-fv02.0.nc"
end

ds = Dataset(url.(DateTime(1992,1,1):Dates.Day(1):DateTime(1992,1,3)),aggdim = "time");
SST2 = ds["analysed_sst"][:,:,:];
close(ds)
```

If there is a network or server issue, you will see an error message like "NetCDF: I/O failure".


# Experimental functions

```@docs
NCDatasets.ancillaryvariables
NCDatasets.filter
```
