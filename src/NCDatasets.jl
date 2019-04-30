VERSION < v"0.7.0-beta2.199" && __precompile__()

module NCDatasets
if VERSION >= v"0.7.0-beta.0"
    using Dates
    using Printf
end

using Base
using Missings
using Compat
using DataStructures: OrderedDict
import Base.convert
import Compat: @debug, findfirst

import Base: close
include("CFTime.jl")
using .CFTime

include("CatArrays.jl")
export CatArrays


# NetCDFError, error check and netcdf_c.jl from NetCDF.jl (https://github.com/JuliaGeo/NetCDF.jl)
# Copyright (c) 2012-2013: Fabian Gans, Max-Planck-Institut fuer Biogeochemie, Jena, Germany
# MIT

# Exception type for error thrown by the NetCDF library
mutable struct NetCDFError <: Exception
    code::Cint
    msg::String
end

"""
    NetCDFError(code::Cint)

Construct a NetCDFError from the error code.
"""
NetCDFError(code::Cint) = NetCDFError(code, nc_strerror(code))

#function Base.showerror(io::IO, err::NetCDFError)
#    print(io, "NetCDF error code $(err.code):\n\t$(err.msg)")
#end

"Check the NetCDF error code, raising an error if nonzero"
function check(code::Cint)
    # zero means success, return
    if code == Cint(0)
        return
        # otherwise throw an error message
    else
        throw(NetCDFError(code))
    end
end

include("netcdf_c.jl")

# end of code from NetCDF.jl

const default_timeunits = "days since 1900-00-00 00:00:00"

### type definition


# -----------------------------------------------------
# base type of attribytes list
# concrete types are Attributes (single NetCDF file) and MFAttributes (multiple NetCDF files)

abstract type BaseAttributes
end

abstract type AbstractDataset
end

abstract type AbstractVariable{T,N} <: AbstractArray{T,N}
end

abstract type AbstractDimensions
end

abstract type AbstractGroups
end

function Base.get(a::BaseAttributes,name::AbstractString,default)
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

mutable struct Dataset <: AbstractDataset
    ncid::Cint
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be an array, so that it is copied by reference
    isdefmode::Vector{Bool}
    attrib::Attributes
    dim::Dimensions
    group::Groups
end


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
                    NC_STRING => String)

# Inverse mapping
const ncType = Dict(value => key for (key, value) in jlType)

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

function Base.show(io::IO,a::BaseAttributes; indent = "  ")
    try
        # use the same order of attributes than in the NetCDF file
        for (attname,attval) in a
            print(io,indent,@sprintf("%-20s = ",attname))
            printstyled(io, @sprintf("%s",attval),color=:blue)
            print(io,"\n")
        end
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                print(io,"NetCDF attributes (file closed)")
                return
            end
        end
        rethrow
    end
end



### Dimensions


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
ds = Dataset("file.nc","c")
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


# Attributes


"""
    getindex(a::Attributes,name::AbstractString)

Return the value of the attribute called `name` from the
attribute list `a`. Generally the attributes are loaded by
indexing, for example:

```julia
ds = Dataset("file.nc")
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
ds = Dataset("file.nc","c")
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

# -----------------------------------------------------

mutable struct MFAttributes{T} <: BaseAttributes where T <: BaseAttributes
    as::Vector{T}
end

function Base.getindex(a::MFAttributes,name::AbstractString)
    return a.as[1][name]
end

function Base.setindex!(a::MFAttributes,data,name::AbstractString)
    for a in a.as
        a[name] = data
    end
    return data
end

Base.keys(a::MFAttributes) = keys(a.as[1])

# -----------------------------------------------------

struct Resource
    filename::String
    mode::String
    metadata::OrderedDict
end

mutable struct DeferAttributes <: BaseAttributes
    r::Resource
    varname::String # "/" for global attributes
    data::OrderedDict
end

mutable struct DeferDimensions <: AbstractDimensions
    r::Resource
    data::OrderedDict
end

mutable struct DeferGroups <: AbstractGroups
    r::Resource
    data::OrderedDict
end


# -----------------------------------------------------

mutable struct MFDimensions{T} <: AbstractDimensions where T <: AbstractDimensions
    as::Vector{T}
    aggdim::String
end


mutable struct MFGroups{T} <: AbstractGroups where T <: AbstractGroups
    as::Vector{T}
    aggdim::String
end



function Base.getindex(a::MFDimensions,name::AbstractString)
    if name == a.aggdim
        return sum(d[name] for d in a.as)
    else
        return a.as[1][name]
    end
end

function Base.setindex!(a::MFDimensions,data,name::AbstractString)
    for a in a.as
        a[name] = data
    end
    return data
end

Base.keys(a::Union{MFDimensions,MFGroups}) = keys(a.as[1])


function Base.getindex(a::MFGroups,name::AbstractString)
    ds = getindex.(a.as,name)
    attrib = MFAttributes([d.attrib for d in ds])
    dim = MFDimensions([d.dim for d in ds],a.aggdim)
    group = MFGroups([d.group for d in ds],a.aggdim)

    return MFDataset(ds,a.aggdim,attrib,dim,group)
end

#---
mutable struct MFDataset{T,N,TA,TD,TG} <: AbstractDataset where T <: AbstractDataset
    ds::Array{T,N}
    aggdim::AbstractString
    attrib::MFAttributes{TA}
    dim::MFDimensions{TD}
    group::MFGroups{TG}
end


mutable struct DeferDataset <: AbstractDataset
    r::Resource
    groupname::String
    attrib::DeferAttributes
    dim::DeferDimensions
    group::DeferGroups
    data::OrderedDict
end


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
julia> ds = Dataset("results.nc", "r");
julia> forecast_group = ds.group["forecast"]
julia> forecast_temp = forecast_group["temperature"]
```

"""
function Base.getindex(g::Groups,groupname::AbstractString)
    grp_ncid = nc_inq_grp_ncid(g.ncid,groupname)
    return Dataset(grp_ncid,g.isdefmode)
end

"""
    defGroup(ds::Dataset,groupname, attrib = []))

Create the group with the name `groupname` in the dataset `ds`.
`attrib` is a list of attribute name and attribute value pairs (see `Dataset`).
"""
function defGroup(ds::Dataset,groupname; attrib = [])
    grp_ncid = nc_def_grp(ds.ncid,groupname)
    ds = Dataset(grp_ncid,ds.isdefmode)

    # set global attributes for group
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

group(ds::AbstractDataset,groupname) = ds.group[groupname]

# -----------------------------------------------------
# Dataset


"""
    Dataset(filename::AbstractString,mode::AbstractString = "r";
                     format::Symbol = :netcdf4, attrib = [])

Create a new NetCDF file if the `mode` is `"c"`. An existing file with the same
name will be overwritten. If `mode` is `"a"`, then an existing file is open into
append mode (i.e. existing data in the netCDF file is not overwritten and
a variable can be added). With the mode set to `"r"`, an existing netCDF file or
OPeNDAP URL can be open in read-only mode.  The default mode is `"r"`.
The optional parameter `attrib` is an iterable of attribute name and attribute
value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a
vector of pairs (see example below).

# Supported formats:

* `:netcdf4` (default): HDF5-based NetCDF format.
* `:netcdf4_classic`: Only netCDF 3 compatible API features will be used.
* `:netcdf3_classic`: classic netCDF format supporting only files smaller than 2GB.
* `:netcdf3_64bit_offset`: improved netCDF format supporting files larger than 2GB.

Files can also be open and automatically closed with a `do` block.

```julia
Dataset("file.nc") do ds
    data = ds["temperature"][:,:]
end
```

```julia
Dataset("file.nc", "c", attrib = ["title" => "my first netCDF file"]) do ds
   defVar(ds,"temp",[10.,20.,30.],("time",))
end;
```

"""
function Dataset(filename::AbstractString,mode::AbstractString = "r";
                 format::Symbol = :netcdf4, attrib = [])
    ncid = -1
    isdefmode = [false]

    if mode == "r"
        ncid = nc_open(filename,NC_NOWRITE)
    elseif mode == "a"
        ncid = nc_open(filename,NC_WRITE)
    elseif mode == "c"
        mode  = NC_CLOBBER

        if format == :netcdf3_64bit_offset
            mode = mode | NC_64BIT_OFFSET
        elseif format == :netcdf4_classic
            mode = mode | NC_NETCDF4 | NC_CLASSIC_MODEL
        elseif format == :netcdf4
            mode = mode | NC_NETCDF4
        elseif format == :netcdf3_classic
            # do nothing
        else
            throw(NetCDFError(-1, "Unkown format '$(format)' for filename '$(filename)'"))
        end

        ncid = nc_create(filename,mode)
        isdefmode[1] = true
    else
        throw(NetCDFError(-1, "Unsupported mode '$(mode)' for filename '$(filename)'"))
    end

    ds = Dataset(ncid,isdefmode)

    # set global attributes
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

function Dataset(ncid::Integer,
                 isdefmode::Vector{Bool})
    attrib = Attributes(ncid,NC_GLOBAL,isdefmode)
    dim = Dimensions(ncid,isdefmode)
    group = Groups(ncid,isdefmode)
    return Dataset(ncid,isdefmode,attrib,dim,group)
end

function Dataset(f::Function,args...; kwargs...)
    ds = Dataset(args...; kwargs...)
    try
        f(ds)
    finally
        #@debug "closing netCDF Dataset $(NCDatasets.path(ds))"
        close(ds)
    end
end



"""
    defDim(ds::Dataset,name,len)

Define a dimension in the data set `ds` with the given `name` and length `len`.
If `len` is the special value `Inf`, then the dimension is considered as
`unlimited`, i.e. it will grow as data is added to the NetCDF file.

For example:

```julia
ds = Dataset("/tmp/test.nc","c")
defDim(ds,"lon",100)
```

This defines the dimension `lon` with the size 100.
"""
defDim(ds::Dataset,name,len) = nc_def_dim(ds.ncid,name,
                                          (isinf(len) ? NC_UNLIMITED : len))

"""
    defVar(ds::Dataset,name,vtype,dimnames; kwargs...)
    defVar(ds::Dataset,name,data,dimnames; kwargs...)

Define a variable with the name `name` in the dataset `ds`.  `vtype` can be
Julia types in the table below (with the corresponding NetCDF type). Instead of
providing the variable type one can directly give also the data `data` which
will be used to fill the NetCDF variable. The parameter `dimnames` is a tuple with the
names of the dimension.  For scalar this parameter is the empty tuple `()`.
The variable is returned (of the type CFVariable).

Note if `data` is a vector or array of `DateTime` objects, then the dates are
saved as double-precision floats and units "$(CFTime.DEFAULT_TIME_UNITS)" (unless a time unit
is specifed with the `attrib` keyword described below)

## Keyword arguments

* `fillvalue`: A value filled in the NetCDF file to indicate missing data.
   It will be stored in the _FillValue attribute.
* `chunksizes`: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.
* `deflatelevel`: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.
* `shuffle`: If true, the shuffle filter is activated which can improve the compression ratio.
* `checksum`: The checksum method can be `:fletcher32` or `:nochecksum` (checksumming is disabled, which is the default)
* `attrib`: An iterable of attribute name and attribute value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a vector of pairs (see example below)
* `typename` (string): The name of the NetCDF type required for vlen arrays [1]

`chunksizes`, `deflatelevel`, `shuffle` and `checksum` can only be
set on NetCDF 4 files.

## NetCDF data types

| NetCDF Type | Julia Type |
|-------------|------------|
| NC_BYTE     | Int8 |
| NC_UBYTE    | UInt8 |
| NC_SHORT    | Int16 |
| NC_INT      | Int32 |
| NC_INT64    | Int64 |
| NC_FLOAT    | Float32 |
| NC_DOUBLE   | Float64 |
| NC_CHAR     | Char |
| NC_STRING   | String |


## Example:

```julia-repl
julia> data = randn(3,5)
julia> Dataset("test_file.nc","c") do ds
          defVar(ds,"temp",data,("lon","lat"), attrib = [
             "units" => "degree_Celsius",
             "long_name" => "Temperature"
          ])
       end;

```

[1]: https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc_005fdef_005fvlen.html
"""
function defVar(ds::Dataset,name,vtype::DataType,dimnames; kwargs...)
    # all keyword arguments as dictionary
    kw = Dict(k => v for (k,v) in kwargs)

    defmode(ds.ncid,ds.isdefmode) # make sure that the file is in define mode
    dimids = Cint[nc_inq_dimid(ds.ncid,dimname) for dimname in dimnames[end:-1:1]]

    typeid =
        if vtype <: Vector
            # variable-length type
            typeid = nc_def_vlen(ds.ncid, kw[:typename], ncType[eltype(vtype)])
        else
            # base-type
            ncType[vtype]
        end

    varid = nc_def_var(ds.ncid,name,typeid,dimids)


    if haskey(kw,:chunksizes)
        storage = :chunked
        chunksizes = kw[:chunksizes]

        # this will fail on NetCDF-3 files
        nc_def_var_chunking(ds.ncid,varid,storage,reverse(chunksizes))
    end

    if haskey(kw,:shuffle) || haskey(kw,:deflatelevel)
        shuffle = get(kw,:shuffle,false)
        deflate = haskey(kw,:deflatelevel)
        deflate_level = get(kw,:deflatelevel,0)

        # this will fail on NetCDF-3 files
        nc_def_var_deflate(ds.ncid,varid,shuffle,deflate,deflate_level)
    end

    if haskey(kw,:checksum)
        checksum = kw[:checksum]
        nc_def_var_fletcher32(ds.ncid,varid,checksum)
    end

    if haskey(kw,:fillvalue)
        fillvalue = kw[:fillvalue]
        nofill = get(kw,:nofill,false)
        nc_def_var_fill(ds.ncid, varid, nofill, vtype(fillvalue))
    end

    if haskey(kw,:attrib)
        v = ds[name]
        for (attname,attval) in kw[:attrib]
            v.attrib[attname] = attval
        end
    end

    return ds[name]
end

function defVar(ds::Dataset,name,data,dimnames; kwargs...)
    vtype = eltype(data)
    if vtype == DateTime
        vtype = Float64
    end

    # define the dimensions if necessary
    for i = 1:length(dimnames)
        if !(dimnames[i] in ds.dim)
            ds.dim[dimnames[i]] = size(data,i)
        end
    end

    v = defVar(ds,name,vtype,dimnames; kwargs...)
    v[:] = data
    return v
end

"""
    keys(ds::Dataset)

Return a list of all variables names in Dataset `ds`.
"""
Base.keys(ds::Dataset) = listVar(ds.ncid)

"""
    path(ds::Dataset)
Return the file path (or the opendap URL) of the Dataset `ds`
"""
path(ds::Dataset) = nc_inq_path(ds.ncid)


"""
    groupname(ds::Dataset)
Return the group name of the Dataset `ds`
"""
groupname(ds::Dataset) = nc_inq_grpname(ds.ncid)


"""
    sync(ds::Dataset)

Write all changes in Dataset `ds` to the disk.
"""
function sync(ds::Dataset)
    datamode(ds.ncid,ds.isdefmode)
    nc_sync(ds.ncid)
end

"""
    close(ds::Dataset)

Close the Dataset `ds`. All pending changes will be written
to the disk.
"""
Base.close(ds::Dataset) = nc_close(ds.ncid)

"""
    v = variable(ds::Dataset,varname::String)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.Variable`. No scaling or other transformations are applied when the
variable `v` is indexed.
"""
function variable(ds::Dataset,varname::AbstractString)
    varid = nc_inq_varid(ds.ncid,varname)
    name,nctype,dimids,nattr = nc_inq_var(ds.ncid,varid)
    ndims = length(dimids)
    #@show ndims
    shape = zeros(Int,ndims)
    #@show typeof(shape),typeof(Int(1))

    for i = 1:ndims
        shape[ndims-i+1] = nc_inq_dimlen(ds.ncid,dimids[i])
    end
    #@show shape
    #@show typeof(shape)

    attrib = Attributes(ds.ncid,varid,ds.isdefmode)

    # reverse dimids to have the dimension order in Fortran style
    return Variable{nctype,ndims}(ds.ncid,varid,
                                  #(shape...),
                                  (reverse(dimids)...,),
                                  attrib,ds.isdefmode)
end

function Base.show(io::IO,ds::AbstractDataset; indent="")
    try
        dspath = path(ds)
        printstyled(io, indent, "Dataset: ",dspath,"\n", color=:red)
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                print(io,"closed NetCDF Dataset")
                return
            end
        end
        rethrow
    end

    print(io,indent,"Group: ",groupname(ds),"\n")
    print(io,"\n")

    dims = collect(ds.dim)

    if length(dims) > 0
        printstyled(io, indent, "Dimensions\n",color=:red)

        for (dimname,dimlen) in dims
            print(io,indent,"   $(dimname) = $(dimlen)\n")
        end
        print(io,"\n")
    end

    varnames = keys(ds)

    if length(varnames) > 0

        printstyled(io, indent, "Variables\n",color=:red)

        for name in varnames
            show(io,variable(ds,name); indent = "$(indent)  ")
            print(io,"\n")
        end
    end

    # global attribues
    if length(ds.attrib) > 0
        printstyled(io, indent, "Global attributes\n",color=:red)
        show(io,ds.attrib; indent = "$(indent)  ");
    end

    # groups
    groupnames = keys(ds.group)

    if length(groupnames) > 0
        printstyled(io, indent, "Groups\n",color = :red)
        for groupname in groupnames
            show(io,group(ds,groupname); indent = "  ")
        end
    end

end

"""
    v = getindex(ds::Dataset,varname::AbstractString)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The CF convention are honored when the
variable is indexed:
* `_FillValue` will be returned as `missing`
* `scale_factor` and `add_offset` are applied
* time variables (recognized by the units attribute) are returned as `DateTime` object.

A call `getindex(ds,varname)` is usually written as `ds[varname]`.
"""
function Base.getindex(ds::AbstractDataset,varname::AbstractString)
    v = variable(ds,varname)

    # return element type of any index operation
    if eltype(v) <: Number
        rettype = Union{Missing,Number,DateTime,AbstractCFDateTime}
    else
        rettype = Union{Missing,eltype(v)}
    end

    return CFVariable{rettype,ndims(v),typeof(v),typeof(v.attrib)}(v,v.attrib)
end



# -----------------------------------------------------
# Variable (as stored in NetCDF file, without using
# add_offset, scale_factor and _FillValue)

mutable struct Variable{NetCDFType,N} <: AbstractVariable{NetCDFType, N}
    ncid::Cint
    varid::Cint
    dimids::NTuple{N,Cint}
    attrib::Attributes
    isdefmode::Vector{Bool}
end

mutable struct MFVariable{T,N,M,TA} <: AbstractVariable{T,N}
    var::CatArrays.CatArray{T,N,M,TA}
    attrib::MFAttributes
    dimnames::NTuple{N,String}
    varname::String
end

mutable struct DeferVariable{T,N} <: AbstractVariable{T,N}
    r::Resource
    varname::String
    attrib::DeferAttributes
    data::OrderedDict
end

# the size of a variable can change, i.e. for a variable with an unlimited
# dimension
Base.size(v::Variable) = (Int[nc_inq_dimlen(v.ncid,dimid) for dimid in v.dimids]...,)


"""
    dimnames(v::Variable)

Return a tuple of the dimension names of the variable `v`.
"""
function dimnames(v::Variable)
    return (String[nc_inq_dimname(v.ncid,dimid) for dimid in v.dimids]...,)
end

"""
    name(v::Variable)

Return the name of the NetCDF variable `v`.
"""
name(v::Variable) = nc_inq_varname(v.ncid,v.varid)

chunking(v::Variable,storage,chunksizes) = nc_def_var_chunking(v.ncid,v.varid,storage,reverse(chunksizes))

"""
    storage,chunksizes = chunking(v::Variable)

Return the storage type (`:contiguous` or `:chunked`) and the chunk sizes
of the varable `v`.
"""
function chunking(v::Variable)
    storage,chunksizes = nc_inq_var_chunking(v.ncid,v.varid)
    return storage,reverse(chunksizes)
end

"""
    isshuffled,isdeflated,deflate_level = deflate(v::Variable)

Return compression information of the variable `v`. If shuffle
is `true`, then shuffling (byte interlacing) is activaded. If
deflate is `true`, then the data chunks (see `chunking`) are
compressed using the compression level `deflate_level`
(0 means no compression and 9 means maximum compression).
"""
deflate(v::Variable,shuffle,deflate,deflate_level) = nc_def_var_deflate(v.ncid,v.varid,shuffle,deflate,deflate_level)
deflate(v::Variable) = nc_inq_var_deflate(v.ncid,v.varid)

checksum(v::Variable,checksummethod) = nc_def_var_fletcher32(v.ncid,v.varid,checksummethod)

"""
   checksummethod = checksum(v::Variable)

Return the checksum method of the variable `v` which can be either
be `:fletcher32` or `:nochecksum`.
"""
checksum(v::Variable) = nc_inq_var_fletcher32(v.ncid,v.varid)


function fillmode(v::Variable)
    no_fill,fv = nc_inq_var_fill(v.ncid, v.varid)
    return no_fill,fv
end

function fillvalue(v::Variable)
    no_fill,fv = nc_inq_var_fill(v.ncid, v.varid)
    return fv
end


function Base.getindex(v::Variable,indexes::Int...)
    #    @show "ind",indexes
    return nc_get_var1(eltype(v),v.ncid,v.varid,[i-1 for i in indexes[ndims(v):-1:1]])
end

function Base.setindex!(v::Variable{T,N},data,indexes::Int...) where N where T
    datamode(v.ncid,v.isdefmode)
    # use zero-based indexes and reversed order
    nc_put_var1(v.ncid,v.varid,[i-1 for i in indexes[ndims(v):-1:1]],T(data))
    return data
end

function Base.getindex(v::Variable{T,N},indexes::Colon...) where {T,N}
    # special case for scalar NetCDF variable
    if N == 0
        data = Vector{T}(undef,1)
        nc_get_var!(v.ncid,v.varid,data)
        return data[1]
    else
        #@show v.shape,typeof(v.shape),T,N
        #@show v.ncid,v.varid
        data = Array{T,N}(undef,size(v))
        nc_get_var!(v.ncid,v.varid,data)
        return data
    end
end

function Base.setindex!(v::Variable{T,N},data::T,indexes::Colon...) where {T,N}
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp = fill(data,size(v))
    #@show "here number",indexes,size(v),fill(data,size(v))
    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

# call to v .= 123
function Base.setindex!(v::Variable{T,N},data::Number) where {T,N}
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp = fill(convert(T,data),size(v))
    #@show "here number",indexes,size(v),tmp
    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

Base.setindex!(v::Variable,data::Number,indexes::Colon...) = setindex!(v::Variable,data)

function Base.setindex!(v::Variable{T,N},data::AbstractArray{T,N},indexes::Colon...) where {T,N}
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    #@show @__LINE__,@__FILE__
    nc_put_var(v.ncid,v.varid,data)
    return data
end

function Base.setindex!(v::Variable{T,N},data::AbstractArray{T2,N},indexes::Colon...) where {T,T2,N}
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp =
        if T <: Integer
            round.(T,data)
        else
            convert(Array{T,N},data)
        end

    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

function ncsub(indexes)
    count = [length(i) for i in indexes[end:-1:1]]
    start = [first(i)-1 for i in indexes[end:-1:1]]     # use zero-based indexes
    stride = [step(i) for i in indexes[end:-1:1]]
    jlshape = (count[end:-1:1]...,)
    return start,count,stride,jlshape
end

function Base.getindex(v::Variable{T,N},indexes::TR...) where {T,N} where TR <: Union{StepRange{Int,Int},UnitRange{Int}}
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    data = Array{T,N}(undef,jlshape)
    nc_get_vars!(v.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!(v::Variable{T,N},data::T,indexes::StepRange{Int,Int}...) where {T,N}
    #@show @__FILE__,@__LINE__,indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(data,jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!(v::Variable{T,N},data::Number,indexes::StepRange{Int,Int}...) where {T,N}
    #@show @__FILE__,@__LINE__,indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(convert(T,data),jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!(v::Variable{T,N},data::Array{T,N},indexes::StepRange{Int,Int}...) where {T,N}
    #@show "sr",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    nc_put_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

# data can be Array{T2,N} or BitArray{N}
function Base.setindex!(v::Variable{T,N},data::AbstractArray,indexes::StepRange{Int,Int}...) where {T,N}
    #@show "sr2",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])

    tmp = convert(Array{T,ndims(data)},data)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)

    return data
end

function normalizeindexes(sz,indexes)
    ndims = length(sz)
    ind = Vector{StepRange}(undef,ndims)
    squeezedim = falses(ndims)

    # normalize indexes
    for i = 1:ndims
        indT = typeof(indexes[i])
        # :
        if indT == Colon
            ind[i] = 1:1:sz[i]
            # just a number
        elseif indT == Int
            ind[i] = indexes[i]:1:indexes[i]
            squeezedim[i] = true
            # range with a step equal to 1
        elseif indT == UnitRange{Int}
            ind[i] = first(indexes[i]):1:last(indexes[i])
        elseif indT == StepRange{Int,Int}
            ind[i] = indexes[i]
        else
            #@show indT
            error("unsupported index")
        end
    end

    return ind,squeezedim
end

function Base.getindex(v::Variable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    #    @show "any",indexes
    ind,squeezedim = normalizeindexes(size(v),indexes)

    data = v[ind...]
    # squeeze any dimension which was indexed with a scalar
    if any(squeezedim)
        return @static if VERSION >= v"0.7.0-beta2.188"
            dropdims(data,dims=(findall(squeezedim)...,))
        else
            squeeze(data,dims=(findall(squeezedim)...,))
        end
    else
        return data
    end
end


function Base.setindex!(v::Variable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    #@show "any",indexes
    ind,squeezedim = normalizeindexes(size(v),indexes)

    # make arrays out of scalars
    if ndims(data) == 0
        data = fill(data,([length(i) for i in ind]...,))
    end

    if ndims(data) == 1 && size(data,1) == 1
        data = fill(data[1],([length(i) for i in ind]...,))
    end

    # return data
    return v[ind...] = data
end



"""
    load!(ncvar::Variable, data, indices)

Loads a NetCDF variables `ncvar` and puts the result in `data` along the
specified `indices`.

```julia
data = zeros(5,6); # must have the right shape and type
load!(ds["temp"].var,data,:,:) # loads all data

data = zeros(5); # must have the right shape and type
load!(ds["temp"].var,data,:,1) # loads the 1st column
```
"""
@inline function load!(ncvar::NCDatasets.Variable{T,N}, data, indices::Union{Integer, UnitRange, StepRange, Colon}...) where {T,N}
    ind = to_indices(ncvar,indices)
    start,count,stride,jlshape = ncsub(ind)
    nc_get_vars!(ncvar.ncid,ncvar.varid,start,count,stride,data)
end

@inline function load!(ncvar::NCDatasets.Variable{T,2}, data, i::Colon,j::UnitRange) where T
    # reversed and 0-based
    start = [first(j)-1,0]
    count = [length(j),size(ncvar,1)]
    nc_get_vara!(ncvar.ncid,ncvar.varid,start,count,data)
end


"""
     data = loadragged(ncvar,index::Colon)

Load data from `ncvar` in the contiguous ragged array representation [1] as a
vector of vectors. It is typically used to load a list of profiles
or time series of different length each.

The indexed ragged array representation [2] is currently not supported.

[1]: https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_contiguous_ragged_array_representation
[2]: https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_indexed_ragged_array_representation
"""
function loadragged(ncvar,index::Colon)
    ds = Dataset(ncvar.var.ncid,ncvar.var.isdefmode)

    dimensionnames = dimnames(ncvar)
    if length(dimensionnames) !== 1
        throw(NetCDFError(-1, "NetCDF variable $(name(ncvar)) should have only one dimensions"))
    end
    dimname = dimensionnames[1]

    ncvarsizes = varbyattrib(ds,sample_dimension = dimname)
    if length(ncvarsizes) !== 1
        throw(NetCDFError(-1, "There should be exactly one NetCDF variable with the attribiute sample_dimension equal to '$(dimname)'"))
    end

    ncvarsize = ncvarsizes[1]
    varsize = ncvarsize.var[:]

    istart = 0;
    tmp = ncvar[:]

    T = typeof(view(tmp,1:varsize[1]))
    data = Vector{T}(undef,length(varsize))

    for i = 1:length(varsize)
        data[i] = view(tmp,istart+1:istart+varsize[i]);
        istart += varsize[i]
    end
    return data
end


# -----------------------------------------------------
# Variable (with applied transformations following the CF convention)


mutable struct CFVariable{T,N,TV,TA}  <: AbstractArray{T, N}
    var::TV
    attrib::TA
end

Base.size(v::CFVariable) = size(v.var)
dimnames(v::CFVariable)  = dimnames(v.var)
name(v::CFVariable)  = name(v.var)
chunking(v::CFVariable,storage,chunksize) = chunking(v.var,storage,chunksize)
chunking(v::CFVariable) = chunking(v.var)

deflate(v::CFVariable,shuffle,dodeflate,deflate_level) = deflate(v.var,shuffle,dodeflate,deflate_level)
deflate(v::CFVariable) = deflate(v.var)

checksum(v::CFVariable,checksummethod) = checksum(v.var,checksummethod)
checksum(v::CFVariable) = checksum(v.var)

fillmode(v::CFVariable) = fillmode(v.var)
fillvalue(v::CFVariable) = fillvalue(v.var)

function Base.getindex(v::CFVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    attnames = keys(v.attrib)

    data = v.var[indexes...]
    isscalar =
        if typeof(data) == String || typeof(data) == DateTime
            true
        else
            ndims(data) == 0
        end

    if isscalar
        data = [data]
    end

    if "_FillValue" in attnames
        fillvalue = v.attrib["_FillValue"]
        if isnan(fillvalue)
            mask = isnan.(data)
        else
            mask = data .== v.attrib["_FillValue"]
        end
    else
        mask = falses(size(data))
    end

    # do not scale characters and strings
    if eltype(v.var) != Char
        if "scale_factor" in attnames
            data = v.attrib["scale_factor"] * data
        end

        if "add_offset" in attnames
            data = data .+ v.attrib["add_offset"]
        end
    end

    if "units" in attnames
        units = v.attrib["units"]
        if occursin(" since ",units)
            # type of data changes
            calendar = get(v.attrib,"calendar","standard")
            data = timedecode(data,units,calendar)
        end
    end

    if isscalar
        if mask[1]
            missing
        else
            data[1]
        end
    else
        datam = Array{Union{eltype(data),Missing}}(data)
        datam[mask] .= missing
        return datam
    end
end

function Base.setindex!(v::CFVariable,data::Array{Missing,N},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N
    v.var[indexes...] = fill(v.attrib["_FillValue"],size(data))
end


function Base.setindex!(v::CFVariable,data::Union{T,Array{T,N}},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N where T <: Union{AbstractCFDateTime,DateTime,Union{Missing,DateTime}}

    #@show "data-",typeof(data)
    attnames = keys(v.attrib)
    units =
        if "units" in attnames
            v.attrib["units"]
        else
            @debug "set time units to $CFTime.DEFAULT_TIME_UNITS"
            v.attrib["units"] = CFTime.DEFAULT_TIME_UNITS
            CFTime.DEFAULT_TIME_UNITS
        end

    if occursin(" since ",units)
        calendar = get(v.attrib,"calendar","standard")
        v[indexes...] = timeencode(data,units,calendar)
        return data
    end

    throw(NetCDFError(-1, "time unit ('$units') of the variable $(name(v)) does not include the word ' since '"))
end

@static if VERSION < v"0.7"
    function Base.setindex!(v::CFVariable,data::T,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where T <: Union{AbstractCFDateTime,DateTime,Union{Missing,DateTime}}

        attnames = keys(v.attrib)
        units =
            if "units" in attnames
                v.attrib["units"]
            else
                @debug "set time units to $CFTime.DEFAULT_TIME_UNITS"
                v.attrib["units"] = CFTime.DEFAULT_TIME_UNITS
                CFTime.DEFAULT_TIME_UNITS
            end

        if occursin(" since ",units)
            calendar = get(v.attrib,"calendar","standard")
            v[indexes...] = timeencode(data,units,calendar)
            return data
        end

        throw(NetCDFError(-1, "time unit ('$units') of the variable $(name(v)) does not include the word ' since '"))
    end
end

function transform(v,offset,scale)
    if offset !== nothing
        if scale !== nothing
            return (v - offset) / scale
        else
            return v - offset
        end
    else
        if scale !== nothing
            return v / scale
        else
            return v
        end
    end
end

# the transformv function is necessary to avoid "iterating" over a single character
# https://discourse.julialang.org/t/broadcasting-and-single-characters/16836
transformv(data,offset,scale) = transform.(data,offset,scale)
transformv(data::Char,offset,scale) = data

function Base.setindex!(v::CFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    offset,scale =
        if eltype(v.var) == Char
            (nothing,nothing)
        else
            (get(v.attrib,"add_offset",nothing),
             get(v.attrib,"scale_factor",nothing))
        end

    fillvalue = get(v.attrib,"_FillValue",nothing)

    v.var[indexes...] =
        if fillvalue == nothing
            transformv(data,offset,scale)
        else
            coalesce.(transformv(data,offset,scale),fillvalue)
        end

    return data
end



function Base.show(io::IO,v::AbstractVariable; indent="")
    delim = " × "
    dims =
        try
            dimnames(v)
        catch err
            if isa(err,NetCDFError)
                if err.code == NC_EBADID
                    print(io,"NetCDF variable (file closed)")
                    return
                end
            end
            rethrow
        end
    sz = size(v)

    printstyled(io, indent, name(v),color=:green)
    if length(sz) > 0
        print(io,indent," (",join(sz,delim),")\n")
        print(io,indent,"  Datatype:    ",eltype(v),"\n")
        print(io,indent,"  Dimensions:  ",join(dims,delim),"\n")
    else
        print(io,indent,"\n")
    end

    if length(v.attrib) > 0
        print(io,indent,"  Attributes:\n")
        show(io,v.attrib; indent = "$(indent)   ")
    end
end

Base.show(io::IO,v::CFVariable; indent="") = Base.show(io::IO,v.var; indent=indent)

Base.display(v::Union{Variable,CFVariable}) = show(Compat.stdout,v)


# Common methods

const NCIterable = Union{BaseAttributes,AbstractDimensions,AbstractDataset,AbstractGroups}

Base.length(a::NCIterable) = length(keys(a))

"""
    haskey(ds::Dataset,varname)

Return true if the Dataset `ds` has a variable with the name `varname`.
For example:

```julia
ds = Dataset("/tmp/test.nc","r")
if haskey(ds,"temperature")
    println("The file has a variable 'temperature'")
end
```

This example checks if the file `/tmp/test.nc` has a variable with the
name `temperature`.
"""
Base.haskey(a::NCIterable,name::AbstractString) = name in keys(a)
Base.in(name::AbstractString,a::NCIterable) = name in keys(a)

@static if VERSION >= v"0.7.0-beta.0"
    function Base.iterate(a::NCIterable, state = keys(a))
        if length(state) == 0
            return nothing
        end

        return (state[1] => a[popfirst!(state)], state)
    end
else
    Base.start(a::NCIterable) = keys(a)
    Base.done(a::NCIterable,state) = length(state) == 0
    Base.next(a::NCIterable,state) = (state[1] => a[popfirst!(state)], state)
end

"""
    escape(val)

Escape backslash, dollar and quote from string `val`.
"""
function escape(val)
     valescaped = val
     # backslash must come first
     for c in ['\\','$','"']
        valescaped = replace(valescaped,c => "\\$c")
    end
	return valescaped
end


function ncgen(io::IO,fname; newfname = "filename.nc")
    ds = Dataset(fname)
    unlimited_dims = unlimited(ds.dim)

    print(io,"ds = Dataset(\"$(escape(newfname))\",\"c\")\n")

    print(io,"# Dimensions\n\n")
    for (d,v) in ds.dim
        if d in unlimited_dims
            print(io,"ds.dim[\"$d\"] = Inf # unlimited dimension\n")
        else
            print(io,"ds.dim[\"$d\"] = $v\n")
        end
    end

    print(io,"\n# Declare variables\n\n")

    for (d,v) in ds
        print(io,"nc$d = defVar(ds,\"$d\", $(eltype(v.var)), $(dimnames(v)))\n")
        ncgen_setattrib(io,"nc$d",v.attrib)
        print(io,"\n")
    end

    print(io,"# Global attributes\n\n")

    ncgen_setattrib(io,"ds",ds.attrib)

    print(io,"\n# Define variables\n\n")

    for d in keys(ds)
        print(io,"# nc$d[:] = ...\n")
    end

    print(io,"\nclose(ds)\n")
    close(ds)
end


"""
    ncgen(fname; ...)
    ncgen(fname,jlname; ...)

Generate the Julia code that would produce a NetCDF file with the same metadata
as the NetCDF file `fname`. The code is placed in the file `jlname` or printed
to the standard output. By default the new NetCDF file is called `filename.nc`.
This can be changed with the optional parameter `newfname`.
"""
ncgen(fname; kwargs...)  = ncgen(Compat.stdout,fname; kwargs...)

function ncgen(fname,jlname; kwargs...)
    open(jlname,"w") do io
        ncgen(io, fname; kwargs...)
    end
end


function ncgen_setattrib(io,v,attrib)
    for (d,val) in attrib
        litval = if typeof(val) == String
            "\"$(escape(val))\""
        elseif typeof(val) == Float64
            val
        elseif typeof(val) == Float32
            "$(eltype(val))($(val))"
        else
            val
        end

        print(io,"$(v).attrib[\"$d\"] = $litval\n");
    end
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
julia> ds = Dataset("results.nc", "r");
julia> data = varbyattrib(ds, standard_name = "longitude")[1][:]
```

"""
function varbyattrib(ds::Dataset; kwargs...)
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
    a = nomissing(da)

Retun the values of the array `da` of type `Array{Union{T,Missing},N}`
(potentially containing missing values) as a regular Julia array `a` of the same
element type and checks that no missing values are present.

"""
function nomissing(da::Array{Union{T,Missing},N}) where {T,N}
    if any(ismissing.(da))
        error("arrays contains missing values (values equal to the fill values attribute in the NetCDF file)")
    end

    if VERSION >= v"0.7.0-beta.0"
         if isempty(da)
            return Array{T,N}([])
         else
            return replace(da, missing => da[1])
         end
    else
        # Illegal instruction (core dumped) in Julia 1.0.1
        return Array{T,N}(da)
    end
end

"""
    a = nomissing(da,value)

Retun the values of the array `da` of type `Array{Union{T,Missing},N}`
as a regular Julia array `a` by replacing all missing value by `value`.
"""
function nomissing(da::Array{Union{T,Missing},N},value) where {T,N}
    if VERSION >= v"0.7.0-beta.0"
        return replace(da, missing => T(value))
    else
        tmp = fill(T(value),size(da))
        tmp[.!ismissing.(da)] = da[.!ismissing.(da)]
        return tmp
    end
end


export defVar, defDim, Dataset, close, sync, variable, dimnames, name,
    deflate, chunking, checksum, fillvalue, fillmode, ncgen
export nomissing
export varbyattrib
export path
export defGroup
export loadragged

include("multifile.jl")
export MFDataset, close

include("defer.jl")
export DeferDataset

include("cfconventions.jl")

# it is good practise to use the default fill-values, thus we export them
export NC_FILL_BYTE, NC_FILL_CHAR, NC_FILL_SHORT, NC_FILL_INT, NC_FILL_FLOAT,
    NC_FILL_DOUBLE, NC_FILL_UBYTE, NC_FILL_USHORT, NC_FILL_UINT, NC_FILL_INT64,
    NC_FILL_UINT64, NC_FILL_STRING

export CFTime
export daysinmonth, daysinyear, yearmonthday, yearmonth, monthday
export dayofyear, firstdayofyear

export DateTimeStandard, DateTimeJulian, DateTimeProlepticGregorian,
    DateTimeAllLeap, DateTimeNoLeap, DateTime360Day, AbstractCFDateTime


end # module
