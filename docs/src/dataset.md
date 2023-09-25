# Datasets

This page is about loading/writing, examining and operating directly on entire NetCDF datasets. For functions regarding the variables stored in them, see the [Variables](@ref) page.

Both variables and datasets share the functionality of the [Attributes](@ref) section.

```@docs
NCDataset
```

Useful functions that operate on datasets are:

```@docs
keys(ds::NCDataset)
haskey
getindex(ds::NCDataset,varname::AbstractString)
variable
cfvariable
sync
close
NCDatasets.path
ncgen
varbyattrib
write
```

Notice that DateTime-structures from [CFTime](http://juliageo.org/CFTime.jl/stable/) are used to represent time for non-standard calendars.
Otherwise, we attempt to use standard structures from the Julia standard library `Dates`.


## Groups

```@docs
defGroup
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

for (attribname,attrib) in ds.attrib
    # all attributes
    @show (attribname,attrib)
end

for (groupname,group) in ds.groups
    # all groups
    @show (groupname,group)
end
```
