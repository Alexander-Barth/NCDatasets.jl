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

Notice that DateTime-structures from [CFTime](http://juliageo.org/CFTime.jl/stable/) are used to represent time for non-standard calendars.
Otherwise, we attempt to use standard structures from the Julia standard library `Dates`.

## Attributes

The NetCDF dataset (as returned by `Dataset` or NetCDF groups) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.

```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
```

## Groups

```@docs
defGroup(ds::Dataset,groupname)
getindex(g::NCDatasets.Groups,groupname::AbstractString)
Base.keys(g::NCDatasets.Groups)
```
