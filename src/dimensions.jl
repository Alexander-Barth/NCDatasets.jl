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
ds = NCDataset("/tmp/test.nc","c")
defDim(ds,"lon",100)
```

This defines the dimension `lon` with the size 100.
"""
function defDim(ds::NCDataset,name,len)
    defmode(ds) # make sure that the file is in define mode
    dimid = nc_def_dim(ds.ncid,name,(isinf(len) ? NC_UNLIMITED : len))
    return nothing
end
export defDim

function renameDim(ds::NCDataset,oldname,newname)
    defmode(ds) # make sure that the file is in define mode
    dimid = nc_inq_dimid(ds.ncid,oldname)
    nc_rename_dim(ds.ncid,dimid,newname)
    return nothing
end
export renameDim
