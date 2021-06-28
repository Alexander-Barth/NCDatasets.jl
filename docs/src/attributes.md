## Attributes

The NetCDF dataset (as returned by `NCDataset` or NetCDF groups) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.

```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
delete!(a::NCDatasets.Attributes,name::AbstractString)
```

Loading all attributes as a `Dict` can be achieved by passing `ds.attrib` (where `ds` is the `NCDataset`) as argument to `Dict`.

```julia
using NCDatasets
ncfile = download("https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc");
ds = NCDataset(ncfile);
attributes_as_dictionary = Dict(ds.attrib)
typeof(attributes_as_dictionary)
# returns Dict{String,Any}
```


## Possible type promotion in Julia

There is a subtile problem with the following code:

```julia
ncv1 = defVar(ds,"v1", UInt8, ("longitude", "latitude", "time"), attrib = [
    "add_offset"                => -1.0,
    "scale_factor"              => 5.0,
    "_FillValue"                => UInt8(255),
])
```

Julia effectively promotes the `_FillValue` to Float64 which leads to a `"NetCDF: Not a valid data type or _FillValue type mismatch"` as the fillvalue has to have exactly the same type as the NetCDF data type. Other parameters could be equally promoted.

```julia
[
           "add_offset"                => -1.0,
           "scale_factor"              => 5.0,
           "_FillValue"                => UInt8(255),
]
# returns
# 3-element Array{Pair{String,Float64},1}:
#   "add_offset" => -1.0
# "scale_factor" => 5.0
#   "_FillValue" => 255.0
```

Note that the type of the second element of the `Pair`.

Using a Julia `Dict` does not show this behaviour:

```julia
ncv1 = defVar(ds,"v1", UInt8, ("longitude", "latitude", "time"), attrib = Dict(
    "add_offset"                => -1.0,
    "scale_factor"              => 5.0,
    "_FillValue"                => UInt8(255),
))
```

Note that `Dict` does not perserve the order of the attributes. Therefore an `OrderedDict` from the package `DataStructures` is preferable.

Or one could use simply the `fillvalue` parameter of `defVar`.

```julia
ncv1 = defVar(ds,"v1", UInt8, ("longitude", "latitude", "time"), fillvalue = UInt8(255), attrib = [
    "add_offset"                => -1.0,
    "scale_factor"              => 5.0,
])
```
