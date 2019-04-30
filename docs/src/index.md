# NCDatasets.jl

Documentation for NCDatasets.jl

## Installation

Inside the Julia shell, you can download and install the package by issuing:

```julia
using Pkg
Pkg.add("NCDatasets")
```

### Latest development version

If you want to try the latest development version, you can do this with the following commands:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/Alexander-Barth/NCDatasets.jl", rev="master"))
Pkg.build("NCDatasets")
```

## Tutorial

### Load a variable from a netCDF file

In the following example, we load the variable with the name `tp` from the NetCDF file `"ECMWF_ERA-40_subset.nc"` and the attribute named `"units"`:.

```julia
using NCDatasets
download("https://www.unidata.ucar.edu/software/netcdf/examples/ECMWF_ERA-40_subset.nc","ECMWF_ERA-40_subset.nc");
ds = Dataset("ECMWF_ERA-40_subset.nc")
tp = ds["tp"][:];
tp_units = ds["tp"].attrib["units"]
close(ds)
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

### Load a file (with unknown structure)

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
chunking
deflate
checksum
loadragged
```

Different type of arrays are involved when working with NCDatasets. For instance assume that `test.nc` is a file with a `Float32` variable called `var`. Assume that we open this data set in append mode (`"a"`):

```julia
using NCDatasets
ds = Dataset("test.nc","a")
v_cf = ds["var"]
```

The variable `v_cf` has the type `CFVariable`. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, ... by the functions `size`, `ndims`, `length` as ordinary Julia arrays. Once you index, the variable `v_cf`, then the data is loaded and stored into a `DataArray`:

```julia
v_da = v_cf[:,:]
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

```@docs
DateTimeStandard
DateTimeJulian
DateTimeProlepticGregorian
DateTimeAllLeap
DateTimeNoLeap
DateTime360Day
NCDatasets.year(dt::AbstractCFDateTime)
NCDatasets.month(dt::AbstractCFDateTime)
NCDatasets.day(dt::AbstractCFDateTime)
NCDatasets.hour(dt::AbstractCFDateTime)
NCDatasets.minute(dt::AbstractCFDateTime)
NCDatasets.second(dt::AbstractCFDateTime)
NCDatasets.millisecond(dt::AbstractCFDateTime)
convert
reinterpret
daysinmonth
daysinyear
yearmonthday
yearmonth
monthday
firstdayofyear
dayofyear
CFTime.timedecode
CFTime.timeencode
```

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

## NetCDF: Not a valid data type or _FillValue type mismatch

Trying to define the `_FillValue`, procudes the following error:

```
ERROR: LoadError: NCDatasets.NetCDFError(-45, "NetCDF: Not a valid data type or _FillValue type mismatch")
```

The error could be generated by a code like this:

```julia
using NCDatasets
# ...
tempvar = defVar(ds,"temp",Float32,("lonc","latc","time"))
tempvar.attrib["_FillValue"] = -9999.
```

In fact, `_FillValue` must have the same data type as the corresponding variable. In the case above, `tempvar` is a 32-bit float and the number `-9999.` is a 64-bit float (aka double, which is the default floating point type in Julia). It is sufficient to convert the value `-9999.` to a 32-bit float:

```julia
tempvar.attrib["_FillValue"] = Float32(-9999.) # or
tempvar.attrib["_FillValue"] = -9999.f0
```


## Corner cases


* An attribute representing a vector with a single value (e.g. `[1]`) will be read back as a scalar (`1`) (same behavior in python netCDF4 1.3.1).

* NetCDF and Julia distinguishes between a vector of chars and a string, but both are returned as string for ease of use, in particular an attribute representing a vector of chars `['u','n','i','t','s']` will be read back as the string `"units"`.

* An attribute representing a vector of chars `['u','n','i','t','s','\0']` will also be read back as the string `"units"` (issue #12).


