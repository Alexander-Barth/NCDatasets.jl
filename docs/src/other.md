# Other features

## Multi-file support

Multiple files can also be aggregated over a given dimension (or the record dimension). In this example, 3 sea surface temperature fields from the
1992-01-01 to 1992-01-03 are aggregated using the OPeNDAP service from PODAAC.

```julia
using NCDatasets, Printf, Dates

function url(dt)
  doy = @sprintf("%03d",Dates.dayofyear(dt))
  y = @sprintf("%04d",Dates.year(dt))
  yyyymmdd = Dates.format(dt,"yyyymmdd")
  return "https://podaac-opendap.jpl.nasa.gov:443/opendap/allData/ghrsst/data/GDS2/L4/GLOB/CMC/CMC0.2deg/v2/$y/$doy/$(yyyymmdd)120000-CMC-L4_GHRSST-SSTfnd-CMC0.2deg-GLOB-v02.0-fv02.0.nc"
end

ds = NCDataset(url.(DateTime(1992,1,1):Dates.Day(1):DateTime(1992,1,3)),aggdim = "time");
SST2 = ds["analysed_sst"][:,:,:];
close(ds)
```

If there is a network or server issue, you will see an error message like `NetCDF: I/O failure`.

## CF Standard Names

The CF Conventions do not define how the different NetCDF variables are named, but the meaning of a variable is defined by the [`standard_name`](https://cfconventions.org/standard-names.html) attribute.

```jldoctest mylabel
using NCDatasets, DataStructures
ds = NCDataset(tempname(),"c")

nclon = defVar(ds,"lon", 1:10, ("lon",),attrib = OrderedDict(
    "standard_name"             => "longitude",
))
nclat = defVar(ds,"lat", 1:11, ("lat",),attrib = OrderedDict(
    "standard_name"             => "latitude",
))
ncvar = defVar(ds,"bat", zeros(10,11), ("lon", "lat"), attrib = OrderedDict(
    "standard_name"             => "height",
))

ncbat = ds[CF"height"]
# the same as
# ncbat = varbyattrib(ds,standard_name = "height")[1]

name(ncbat)
# output
"bat"
```

If there are multiple variables with the `standard_name` equal to `height`, an error is returned because it is ambiguous which variable should be accessed.

All variables whose dimensions are also dimensions of `ncbat` are considered as related and can also be accessed by sub-setting `ncbat` with their variable names
of CF Standard name:

```jldoctest mylabel
nclon_of_bat = ncbat[CF"longitude"]
# same as
# nclon_of_bat = ncbat["lon"]
name(nclon_of_bat)
# output
"lon"
```

The previous call to `ncbat[CF"longitude"]` would also worked if there are multiple variables with a standard name `longitude` defined in a dataset as long as they have different dimension names (which is commonly the case for model output on staggered grid such as [Regional Ocean Modeling System](https://www.myroms.org/)).

## Views

In Julia, a [view of an array](https://docs.julialang.org/en/v1/base/arrays/#Views-(SubArrays-and-other-view-types)) is a subset of an array but whose elements still point to the original parent array. If one modifies an element of a view, the corresponding element in the parent array is modified too:

```jldoctest example_view_julia
A = zeros(4,4)
subset = @view A[2:3,2:4]
# or
# subset = view(A,2:3,2:4)

subset[1,1] = 2
A[2,2]
# output
2.0
```

Views do not use copy of the array. The parent array and the indices of the view are obtained via the function [`parent`](https://docs.julialang.org/en/v1/base/arrays/#Base.parent) and [`parentindices`](https://docs.julialang.org/en/v1/base/arrays/#Base.parentindices).

```jldoctest example_view_julia
parent(subset) == A
# true, as both arrays are the same

parentindices(subset)
# output
(2:3, 2:4)
```

In NCDatasets, variables can also be sliced as a view:


```jldoctest example_view_ncdatasets
using NCDatasets, DataStructures
ds = NCDataset(tempname(),"c")

nclon = defVar(ds,"lon", 1:10, ("lon",))
nclat = defVar(ds,"lat", 1:11, ("lat",))
ncvar = defVar(ds,"bat", zeros(10,11), ("lon", "lat"), attrib = OrderedDict(
    "standard_name"             => "height",
))

ncvar_subset = @view ncvar[2:4,2:3]
# or
# ncvar_subset = view(ncvar,2:4,2:3)

ncvar_subset[1,1] = 2
# ncvar[2,2] is now 2

ncvar_subset.attrib["standard_name"]

# output
"height"
```

This is useful for example when even the sliced array is too large to be loaded in RAM or when all attributes need to be preserved for the sliced array.

The variables `lon` and `lat` are related to `bat` because all dimensions of the variables `lon` and `lat` are also dimensions of `bat` (which is commonly the case for coordinate variables). Such related variables can be retrieved by indexing the NetCDF variables with the name of the corresponding variable:

```jldoctest example_view_ncdatasets
lon_subset = ncvar_subset["lon"]
lon_subset[:] == [2, 3, 4]
# output
true
```

A view of a NetCDF variable also implements the function `parent` and `parentindices` with the same meaning as for julia `Array`s.

A whole dataset can also be sliced using a `view(ds, dim1=range1, dim2=range2...)`. For example:

```jldoctest example_view_ncdatasets
ds_subset = view(ds, lon = 2:3, lat = 2:4)
# or
# ds_subset = @view ds[lon = 2:3, lat = 2:4]
ds_subset.dim["lon"]

# output
2
```

Such sliced datasets can for example be saved into a new NetCDF file using `write`:

```julia
write("slice.nc",ds_subset)
```

Any dimension not mentioned in the `@view` call is not sliced.
While `@view` produces a slice based on indices, the `NCDatasets.@select` macro produces a slice (of an NetCDF variable or dataset)
based on the values of other related variables (typically coordinates).

## Data selection based on values

```@docs
NCDatasets.@select
```


## Experimental functions

```@docs
NCDatasets.ancillaryvariables
NCDatasets.filter
```
