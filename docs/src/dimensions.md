# Dimensions

In the NetCDF data model, dimensions have names and a length (but possibly an unlimited length) and are defined for a NetCDF dataset (or group).
For a given `Variable` or `CFVariable`,the names of the corresponding dimensions are obtained with using [`dimnames`](@ref).

```@docs
keys(d::NCDatasets.Dimensions)
haskey(a::NCDatasets.NCIterable,name::AbstractString)
defDim
unlimited(d::NCDatasets.Dimensions)
setindex!(d::NCDatasets.Dimensions,len,name::AbstractString)
renameDim(ds::NCDataset,oldname::Union{AbstractString,Symbol},newname::Union{AbstractString,Symbol})
```

One can iterate over a list of dimensions as follows:

```julia
for (dimname,dim) in ds.dim
    # all dimensions
    @show (dimname,dim)
end
```
