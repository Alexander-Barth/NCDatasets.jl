# NCDatasets.jl

Documentation for NCDatasets.jl

## Datasets

```@docs
Dataset
keys
haskey
variable
sync
close
```

## Variables

```@docs
defVar
dimnames
name
chunking
deflate
checksum
Base.start(ds::Dataset)
```

## Attributes

The NetCDF dataset (as return by `Dataset`) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.


```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
```


## Dimensions

```@docs
defDim
setindex!(d::NCDatasets.Dimensions,len,name::AbstractString)
```
