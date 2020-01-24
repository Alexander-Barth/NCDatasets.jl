#=
Core type definitions for the `NCDataset` struct,
the `Attributes` and `Group` parts as well.
and the `Attributes` part of it.
Helper functions defined for these as well.

High-level interface is at the "High-level" section about actually
loading/reading/making datasets.
=#

############################################################
# Type definitions
############################################################
# -----------------------------------------------------
# base type of attributes list
# concrete types are Attributes (single NetCDF file) and
# MFAttributes (multiple NetCDF files)

abstract type BaseAttributes
end

abstract type AbstractDataset
end


abstract type AbstractDimensions
end

abstract type AbstractGroups
end

function Base.get(a::BaseAttributes, name::AbstractString,default)
    if haskey(a,name)
        return a[name]
    else
        return default
    end
end


# -----------------------------------------------------
# List of attributes (for a single NetCDF file)
# all ids should be Cint

mutable struct Attributes <: BaseAttributes
    ncid::Cint
    varid::Cint
    isdefmode::Vector{Bool}
end

mutable struct Groups <: AbstractGroups
    ncid::Cint
    isdefmode::Vector{Bool}
end

mutable struct Dimensions <: AbstractDimensions
    ncid::Cint
    isdefmode::Vector{Bool}
end

mutable struct NCDataset <: AbstractDataset
    ncid::Cint
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be an array, so that it is copied by reference
    isdefmode::Vector{Bool}
    attrib::Attributes
    dim::Dimensions
    group::Groups
end

"Alias to `NCDataset`"
const Dataset = NCDataset

const NCIterable = Union{BaseAttributes,AbstractDimensions,AbstractDataset,AbstractGroups}
Base.length(a::NCIterable) = length(keys(a))


############################################################
# Mappings
############################################################

# Mapping between NetCDF types and Julia types
const jlType = Dict(
    NC_BYTE   => Int8,
    NC_UBYTE  => UInt8,
    NC_SHORT  => Int16,
    NC_USHORT => UInt16,
    NC_INT    => Int32,
    NC_UINT   => UInt32,
    NC_INT64  => Int64,
    NC_UINT64 => UInt64,
    NC_FLOAT  => Float32,
    NC_DOUBLE => Float64,
    NC_CHAR   => Char,
    NC_STRING => String
)

# Inverse mapping
const ncType = Dict(value => key for (key, value) in jlType)

# default fill value per types
const ncFillValue = Dict(
    Int8    => NC_FILL_BYTE,
    UInt8   => NC_FILL_UBYTE,
    Int16   => NC_FILL_SHORT,
    UInt16  => NC_FILL_USHORT,
    Int32   => NC_FILL_INT,
    UInt32  => NC_FILL_UINT,
    Int64   => NC_FILL_INT64,
    UInt64  => NC_FILL_UINT64,
    Float32 => NC_FILL_FLOAT,
    Float64 => NC_FILL_DOUBLE,
    Char    => NC_FILL_CHAR,
    String  => NC_FILL_STRING
)

############################################################
# Helper functions (internal)
############################################################
"Return all variable names"
listVar(ncid) = String[nc_inq_varname(ncid,varid)
                       for varid in nc_inq_varids(ncid)]

"Return all attribute names"
function listAtt(ncid,varid)
    natts = nc_inq_varnatts(ncid,varid)
    names = Vector{String}(undef,natts)

    for attnum = 0:natts-1
        names[attnum+1] = nc_inq_attname(ncid,varid,attnum)
    end

    return names
end

"Make sure that a dataset is in data mode"
function datamode(ncid,isdefmode::Vector{Bool})
    if isdefmode[1]
        nc_enddef(ncid)
        isdefmode[1] = false
    end
end

"Make sure that a dataset is in define mode"
function defmode(ncid,isdefmode::Vector{Bool})
    if !isdefmode[1]
        nc_redef(ncid)
        isdefmode[1] = true
    end
end

############################################################
# Groups
############################################################
"""
    Base.keys(g::NCDatasets.Groups)

Return the names of all subgroubs of the group `g`.
"""
function Base.keys(g::Groups)
    return String[nc_inq_grpname(ncid)
                  for ncid in nc_inq_grps(g.ncid)]
end


"""
    group = getindex(g::NCDatasets.Groups,groupname::AbstractString)

Return the NetCDF `group` with the name `groupname`.
For example:

```julia-repl
julia> ds = NCDataset("results.nc", "r");
julia> forecast_group = ds.group["forecast"]
julia> forecast_temp = forecast_group["temperature"]
```

"""
function Base.getindex(g::Groups,groupname::AbstractString)
    grp_ncid = nc_inq_grp_ncid(g.ncid,groupname)
    return NCDataset(grp_ncid,g.isdefmode)
end

"""
    defGroup(ds::NCDataset,groupname, attrib = []))

Create the group with the name `groupname` in the dataset `ds`.
`attrib` is a list of attribute name and attribute value pairs (see `NCDataset`).
"""
function defGroup(ds::NCDataset,groupname; attrib = [])
    grp_ncid = nc_def_grp(ds.ncid,groupname)
    ds = NCDataset(grp_ncid,ds.isdefmode)

    # set global attributes for group
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

group(ds::AbstractDataset,groupname) = ds.group[groupname]

############################################################
# High-level
############################################################

"""
    NCDataset(filename::AbstractString, mode = "r";
            format::Symbol = :netcdf4, attrib = [])

Load, create, or even overwrite a NetCDF file at `filename`, depending on `mode`:

* `"r"` (default) : open an existing netCDF file or OPeNDAP URL
   in read-only mode.
* `"c"` : create a new NetCDF file at `filename` (an existing file with the same
  name will be overwritten).
* `"a"` : open `filename` into append mode (i.e. existing data in the netCDF
  file is not overwritten and a variable can be added).

Notice that this does not close the dataset, use `close` on the
result (or see below the `do`-block).

The optional parameter `attrib` is an iterable of attribute name and attribute
value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a
vector of pairs (see example below).

# Supported `format` values:

* `:netcdf4` (default): HDF5-based NetCDF format.
* `:netcdf4_classic`: Only netCDF 3 compatible API features will be used.
* `:netcdf3_classic`: classic netCDF format supporting only files smaller than 2GB.
* `:netcdf3_64bit_offset`: improved netCDF format supporting files larger than 2GB.

Files can also be open and automatically closed with a `do` block.

```julia
NCDataset("file.nc") do ds
    data = ds["temperature"][:,:]
end
```

Here is an attribute example:
```julia
NCDataset("file.nc", "c", attrib = ["title" => "my first netCDF file"]) do ds
   defVar(ds,"temp",[10.,20.,30.],("time",))
end;
```

`NCDataset` is an alias to `NCDataset`.
"""
function NCDataset(filename::AbstractString,
                 mode::AbstractString = "r";
                 format::Symbol = :netcdf4,
                 diskless = false,
                 persist = false,
                 attrib = [])

    ncid = -1
    isdefmode = [false]

    if (mode == "r") || (mode == "a")
        ncmode =
            if (mode == "r")
                NC_NOWRITE
            else
                NC_WRITE
            end

        if diskless
            ncmode = ncmode | NC_DISKLESS
        end

        ncid = nc_open(filename,ncmode)
    elseif mode == "c"
        ncmode  = NC_CLOBBER

        if format == :netcdf3_64bit_offset
            ncmode = ncmode | NC_64BIT_OFFSET
        elseif format == :netcdf4_classic
            ncmode = ncmode | NC_NETCDF4 | NC_CLASSIC_MODEL
        elseif format == :netcdf4
            ncmode = ncmode | NC_NETCDF4
        elseif format == :netcdf3_classic
            # do nothing
        else
            throw(NetCDFError(-1, "Unkown format '$(format)' for filename '$(filename)'"))
        end

        if diskless
            ncmode = ncmode | NC_DISKLESS

            if persist
                ncmode = ncmode | NC_PERSIST
            end
        end


        ncid = nc_create(filename,ncmode)
        isdefmode[1] = true
    else
        throw(NetCDFError(-1, "Unsupported mode '$(mode)' for filename '$(filename)'"))
    end

    ds = NCDataset(ncid,isdefmode)

    # set global attributes
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

function NCDataset(ncid::Integer,
                 isdefmode::Vector{Bool})
    attrib = Attributes(ncid,NC_GLOBAL,isdefmode)
    dim = Dimensions(ncid,isdefmode)
    group = Groups(ncid,isdefmode)
    return NCDataset(ncid,isdefmode,attrib,dim,group)
end

function NCDataset(f::Function,args...; kwargs...)
    ds = NCDataset(args...; kwargs...)
    try
        f(ds)
    finally
        #@debug "closing netCDF NCDataset $(NCDatasets.path(ds))"
        close(ds)
    end
end


"""
    getindex(a::Attributes,name::AbstractString)

Return the value of the attribute called `name` from the
attribute list `a`. Generally the attributes are loaded by
indexing, for example:

```julia
ds = NCDataset("file.nc")
title = ds.attrib["title"]
```
"""
function Base.getindex(a::Attributes,name::AbstractString)
    return nc_get_att(a.ncid,a.varid,name)
end


"""
    Base.setindex!(a::Attributes,data,name::AbstractString)

Set the attribute called `name` to the value `data` in the
attribute list `a`. Generally the attributes are defined by
indexing, for example:

```julia
ds = NCDataset("file.nc","c")
ds.attrib["title"] = "my title"
```
"""
function Base.setindex!(a::Attributes,data,name::AbstractString)
    defmode(a.ncid,a.isdefmode) # make sure that the file is in define mode
    return nc_put_att(a.ncid,a.varid,name,data)
end

"""
    Base.keys(a::Attributes)

Return a list of the names of all attributes.
"""
Base.keys(a::Attributes) = listAtt(a.ncid,a.varid)

############################################################
# High-level: user convenience
############################################################
"""
    keys(ds::NCDataset)

Return a list of all variables names in NCDataset `ds`.
"""
Base.keys(ds::NCDataset) = listVar(ds.ncid)

"""
    path(ds::NCDataset)
Return the file path (or the opendap URL) of the NCDataset `ds`
"""
path(ds::NCDataset) = nc_inq_path(ds.ncid)


"""
    groupname(ds::NCDataset)
Return the group name of the NCDataset `ds`
"""
groupname(ds::NCDataset) = nc_inq_grpname(ds.ncid)


"""
    sync(ds::NCDataset)

Write all changes in NCDataset `ds` to the disk.
"""
function sync(ds::NCDataset)
    datamode(ds.ncid,ds.isdefmode)
    nc_sync(ds.ncid)
end

"""
    close(ds::NCDataset)

Close the NCDataset `ds`. All pending changes will be written
to the disk.
"""
Base.close(ds::NCDataset) = nc_close(ds.ncid)

############################################################
# Dimensions
############################################################


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
    return String[nc_inq_dimname(d.ncid,dimid)
                  for dimid in nc_inq_dimids(d.ncid,false)]
end

function Base.getindex(a::Dimensions,name::AbstractString)
    dimid = nc_inq_dimid(a.ncid,name)
    return nc_inq_dimlen(a.ncid,dimid)
end

"""
    unlimited(d::Dimensions)

Return the names of all unlimited dimensions.
"""
function unlimited(d::Dimensions)
    return String[nc_inq_dimname(d.ncid,dimid)
                  for dimid in nc_inq_unlimdims(d.ncid)]
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
    defmode(d.ncid,d.isdefmode) # make sure that the file is in define mode
    dimid = nc_def_dim(d.ncid,name,(isinf(len) ? NC_UNLIMITED : len))
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
    defmode(ds.ncid,ds.isdefmode) # make sure that the file is in define mode
    dimid = nc_def_dim(ds.ncid,name,(isinf(len) ? NC_UNLIMITED : len))
    return nothing
end


function renameDim(ds::NCDataset,oldname,newname)
    defmode(ds.ncid,ds.isdefmode) # make sure that the file is in define mode
    dimid = nc_inq_dimid(ds.ncid,oldname)
    nc_rename_dim(ds.ncid,dimid,newname)
    return nothing
end
export renameDim

############################################################
# Common methods
############################################################
function Base.iterate(a::NCIterable, state = keys(a))
    if length(state) == 0
        return nothing
    end

    return (state[1] => a[popfirst!(state)], state)
end

"""
    varbyattrib(ds, attname = attval)

Returns a list of variable(s) which has the attribute `attname` matching the value `attval`
in the dataset `ds`.
The list is empty if the none of the variables has the match.
The output is a list of `CFVariable`s.

# Examples

Load all the data of the first variable with standard name "longitude" from the
NetCDF file `results.nc`.

```julia-repl
julia> ds = NCDataset("results.nc", "r");
julia> data = varbyattrib(ds, standard_name = "longitude")[1][:]
```

"""
function varbyattrib(ds::NCDataset; kwargs...)
    # Start with an empty list of variables
    varlist = []

    # Loop on the variables
    for v in keys(ds)
        var = ds[v]

        matchall = true

        for (attsym,attval) in kwargs
            attname = String(attsym)

            # Check if the variable has the desired attribute
            if haskey(var.attrib, attname)
                # Check if the attribute value is the selected one
                if var.attrib[attname] != attval
                    matchall = false
                    break
                end
            else
                matchall = false
                break
            end
        end

        if matchall
            push!(varlist, var)
        end
    end

    return varlist
end

"""
    haskey(ds::NCDataset,name)
    haskey(d::Dimensions,name)
    haskey(ds::Attributes,name)

Return true if the NCDataset `ds` (or dimension/attribute list) has a variable (dimension/attribute) with the name `name`.
For example:

```julia
ds = NCDataset("/tmp/test.nc","r")
if haskey(ds,"temperature")
    println("The file has a variable 'temperature'")
end

if haskey(ds.dim,"lon")
    println("The file has a dimension 'lon'")
end
```

This example checks if the file `/tmp/test.nc` has a variable with the
name `temperature` and a dimension with the name `lon`.
"""
Base.haskey(a::NCIterable,name::AbstractString) = name in keys(a)
Base.in(name::AbstractString,a::NCIterable) = name in keys(a)
