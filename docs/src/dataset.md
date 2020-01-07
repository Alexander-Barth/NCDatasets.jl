# Datasets

This page is about loading/writing, examining and operating directly on entire NetCDF datasets. For functions regarding the variables stored in them, see the [Variables](@ref) page.

Both variables and datasets share the functionality of the [Attributes](@ref) section.

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


## Attributes

The NetCDF dataset (as return by `Dataset` or NetCDF groups) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.


```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
```
