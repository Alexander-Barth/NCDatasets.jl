# `Dimensions` is a collection of named dimensions
# each dimension has a name and a size (possibly unlimited)

"""
    keys(d::Dimensions)

Return a list of all dimension names in NCDataset `ds`.

# Examples

```julia-repl
julia> ds = NCDataset("results.nc", "r");
julia> dimnames = keys(ds.dim)
```
"""
function Base.keys(d::Dimensions)
    return String[nc_inq_dimname(d.ds.ncid,dimid)
                  for dimid in nc_inq_dimids(d.ds.ncid,false)]
end

Base.show(io::IO, d::AbstractDimensions) = CommonDataModel.show_dim(io,d)

function Base.getindex(d::Dimensions,name::AbstractString)
    dimid = nc_inq_dimid(d.ds.ncid,name)
    return nc_inq_dimlen(d.ds.ncid,dimid)
end

"""
    unlimited(d::Dimensions)

Return the names of all unlimited dimensions.
"""
function unlimited(d::Dimensions)
    return String[nc_inq_dimname(d.ds.ncid,dimid)
                  for dimid in nc_inq_unlimdims(d.ds.ncid)]
end

export unlimited

"""
    Base.setindex!(d::Dimensions,len,name::AbstractString)

Defines the dimension called `name` to the length `len`.
Generally dimension are defined by indexing, for example:

```julia
ds = NCDataset("file.nc","c")
ds.dim["longitude"] = 100
```

If `len` is the special value `Inf`, then the dimension is considered as
`unlimited`, i.e. it will grow as data is added to the NetCDF file.
"""
function Base.setindex!(d::Dimensions,len,name::AbstractString)
    defmode(d.ds) # make sure that the file is in define mode
    dimid = nc_def_dim(d.ds.ncid,name,(isinf(len) ? NC_UNLIMITED : len))
    return len
end

"""
    defDim(ds::NCDataset,name,len)

Define a dimension in the data set `ds` with the given `name` and length `len`.
If `len` is the special value `Inf`, then the dimension is considered as
`unlimited`, i.e. it will grow as data is added to the NetCDF file.

For example:

```julia
using NCDatasets
ds = NCDataset("/tmp/test.nc","c")
defDim(ds,"lon",100)
# [...]
close(ds)
```

This defines the dimension `lon` with the size 100.

To create a variable with an unlimited dimensions use for example:

```julia
using NCDatasets
ds = NCDataset("/tmp/test2.nc","c")
defDim(ds,"lon",10)
defDim(ds,"lat",10)
defDim(ds,"time",Inf)
defVar(ds,"unlimited_variable",Float64,("lon","lat","time"))
@show ds.dim["time"]
# returns 0 as no data is added
ds["unlimited_variable"][:,:,:] = randn(10,10,4)
@show ds.dim["time"]
# returns now 4 as 4 time slice have been added
close(ds)
```
"""
function defDim(ds::NCDataset,name::SymbolOrString,len)
    defmode(ds) # make sure that the file is in define mode
    dimid = nc_def_dim(ds.ncid,name,(isinf(len) ? NC_UNLIMITED : len))
    return nothing
end
export defDim

function renameDim(ds::NCDataset,oldname::SymbolOrString,newname::SymbolOrString)
    defmode(ds) # make sure that the file is in define mode
    dimid = nc_inq_dimid(ds.ncid,oldname)
    nc_rename_dim(ds.ncid,dimid,newname)
    return nothing
end
export renameDim
