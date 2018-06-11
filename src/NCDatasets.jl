__precompile__()

module NCDatasets
using Base
using Base.Test
#using NullableArrays
using DataArrays
import Base.convert

include("time.jl")

# NetCDFError, error check and netcdf_c.jl from NetCDF.jl (https://github.com/JuliaGeo/NetCDF.jl)
# Copyright (c) 2012-2013: Fabian Gans, Max-Planck-Institut fuer Biogeochemie, Jena, Germany
# MIT

# Exception type for error thrown by the NetCDF library
type NetCDFError <: Exception
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

### type definition


# -----------------------------------------------------
# base type of attribytes list
# concrete types are Attributes (single NetCDF file) and MFAttributes (multiple NetCDF files)

abstract type BaseAttributes
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

type Attributes <: BaseAttributes
    ncid::Cint
    varid::Cint
    isdefmode::Vector{Bool}
end

type Groups
    ncid::Cint
    isdefmode::Vector{Bool}
end

type Dimensions
    ncid::Cint
    isdefmode::Vector{Bool}
end

type Dataset
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
    names = Vector{String}(natts)

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
    # use the same order of attributes than in the NetCDF file

   for (attname,attval) in a
       print(io,indent,@sprintf("%-20s = ",attname))
       print_with_color(:blue, io, @sprintf("%s",attval))
       print(io,"\n")
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

type MFAttributes <: BaseAttributes
    as::Vector{Attributes}
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

Base.keys(a::MFAttributes) = keys(a.as)

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
    defGroup(ds::Dataset,groupname)

Create the group with the name `groupname` in the dataset `ds`.
"""
function defGroup(ds::Dataset,groupname)
    grp_ncid = nc_def_grp(ds.ncid,groupname)
    return Dataset(grp_ncid,ds.isdefmode)
end

function group(ds::Dataset,groupname)
    grp_ncid = nc_inq_grp_ncid(ds.ncid,groupname)
    return Dataset(grp_ncid,ds.isdefmode)
end


# -----------------------------------------------------
# Dataset


"""
    Dataset(filename::AbstractString,mode::AbstractString = "r";
                     format::Symbol = :netcdf4)

Create a new NetCDF file if the `mode` is "c". An existing file with the same
name will be overwritten. If `mode` is "a", then an existing file is open into
append mode (i.e. existing data in the netCDF file is not overwritten and
a variable can be added). With the mode set to "r", an existing netCDF file or
OPeNDAP URL can be open in read-only mode.  The default mode is "r".

# Supported formats:

* :netcdf4 (default): HDF5-based NetCDF format.
* :netcdf4_classic: Only netCDF 3 compatible API features will be used.
* :netcdf3_classic: classic netCDF format supporting only files smaller than 2GB.
* :netcdf3_64bit_offset: improved netCDF format supporting files larger than 2GB.

Files can also be open and automatically closed with a `do` block.

```julia
Dataset("file.nc") do ds
    data = ds["temperature"][:,:]
end
```

"""

function Dataset(filename::AbstractString,mode::AbstractString = "r";
                 format::Symbol = :netcdf4)
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
            error("Unkown format $(format)")
        end

        ncid = nc_create(filename,mode)
        isdefmode[1] = true
    end

    return Dataset(ncid,isdefmode)
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

Define a variable with the name `name` in the dataset `ds`.  `vtype` can be
Julia types in the table below (with the corresponding NetCDF type).  The parameter `dimnames` is a tuple with the
names of the dimension.  For scalar this parameter is the empty tuple ().
The variable is returned (of the type CFVariable).

## Keyword arguments

* `fillvalue`: A value filled in the NetCDF file to indicate missing data.
   It will be stored in the _FillValue attribute.
* `chunksizes`: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.
* `deflatelevel`: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.
* `shuffle`: If true, the shuffle filter is activated which can improve the compression ratio.
* `checksum`: The checksum method can be `:fletcher32` or `:nochecksum` (checksumming is disabled, which is the default)
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

[1] https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc_005fdef_005fvlen.html
"""

function defVar(ds::Dataset,name,vtype,dimnames; kwargs...)
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

    return ds[name]
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
    sync(ds::Dataset)

Write all changes in Dataset `ds` to the disk.
"""

sync(ds::Dataset) = nc_sync(ds.ncid)

"""
    close(ds::Dataset)

Close the Dataset `ds`. All pending changes will be written
to the disk.
"""

Base.close(ds::Dataset) = nc_close(ds.ncid)

"""
    variable(ds::Dataset,varname::String)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.Variable`. No scaling is applied when this variable is
indexes.
"""

function variable(ds::Dataset,varname::String)
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
                                  (reverse(dimids)...),
                                  attrib,ds.isdefmode)
end

function Base.show(io::IO,ds::Dataset; indent="")
    print_with_color(:red, io, indent, "Dataset: ",path(ds),"\n")
    print(io,indent,"Group: ",nc_inq_grpname(ds.ncid),"\n")
    print(io,"\n")

    dimids = nc_inq_dimids(ds.ncid,false)

    if length(dimids) > 0
        print_with_color(:red, io, indent, "Dimensions\n")

        for dimid in dimids
            dimname = nc_inq_dimname(ds.ncid,dimid)
            dimlen = nc_inq_dimlen(ds.ncid,dimid)
            print(io,indent,"   $(dimname) = $(dimlen)\n")
        end
        print(io,"\n")
    end

    varnames = keys(ds)

    if length(varnames) > 0

        print_with_color(:red, io, indent, "Variables\n")

        for name in varnames
            show(io,variable(ds,name); indent = "$(indent)  ")
            print(io,"\n")
        end
    end

    # global attribues
    if length(ds.attrib) > 0
        print_with_color(:red, io, indent, "Global attributes\n")
        show(io,ds.attrib; indent = "$(indent)  ");
    end

    # groups
    grpids = nc_inq_grps(ds.ncid)

    if length(grpids) > 0
        print_with_color(:red, io, indent, "Groups\n")
        for grpid in grpids
            grpname = nc_inq_grpname(grpid)
            show(io,group(ds,grpname); indent = "  ")
        end
    end

end

"""
    getindex(ds::Dataset,varname::AbstractString)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The CF convention are honored when the
variable is indexed:
* `_FillValue` will be returned as `missing` (DataArrays)
* `scale_factor` and `add_offset` are applied
* time variables (recognized by the units attribute) are returned
as `DateTime` object.

A call `getindex(ds,varname)` is usually written as `ds[varname]`.
"""

function Base.getindex(ds::Dataset,varname::AbstractString)
    v = variable(ds,varname)
    # fillvalue = zero(eltype(v))
    # add_offset = 0
    # scale_factor = 1

    attrib = Attributes(v.ncid,v.varid,ds.isdefmode)
    # attnames = keys(attrib)

    # has_fillvalue = "_FillValue" in attnames
    # if has_fillvalue
    #     fillvalue = attrib["_FillValue"]
    # end

    # has_add_offset = "add_offset" in attnames
    # if has_add_offset
    #     add_offset = attrib["add_offset"]
    # end

    # has_scale_factor = "scale_factor" in attnames
    # if has_scale_factor
    #     scale_factor = attrib["scale_factor"]
    # end

    # return element type of any index operation

    if eltype(v) <: Number
        rettype = Float64
    else
        rettype = eltype(v)
    end

    # return CFVariable{eltype(v),rettype,ndims(v)}(v,attrib,has_fillvalue,has_add_offset,
    #                                               has_scale_factor,fillvalue,
    #                                               add_offset,scale_factor)

    return CFVariable{eltype(v),rettype,ndims(v)}(v,attrib)
end



# -----------------------------------------------------
# Variable (as stored in NetCDF file, without using
# add_offset, scale_factor and _FillValue)

type Variable{NetCDFType,N}  <: AbstractArray{NetCDFType, N}
    ncid::Cint
    varid::Cint
    dimids::NTuple{N,Cint}
    attrib::Attributes
    isdefmode::Vector{Bool}
end

# the size of a variable can change, i.e. for a variable with an unlimited
# dimension
Base.size(v::Variable) = (Int[nc_inq_dimlen(v.ncid,dimid) for dimid in v.dimids]...)

"""
    dimnames(v::Variable)

Return a tuple of the dimension names of the variable `v`.
"""
function dimnames(v::Variable)
    return (String[nc_inq_dimname(v.ncid,dimid) for dimid in v.dimids]...)
end

"""
    name(v::Variable)

Return the name of the NetCDF variable `v`.
"""

name(v::Variable) = nc_inq_varname(v.ncid,v.varid)

chunking(v::Variable,storage,chunksizes) = nc_def_var_chunking(v.ncid,v.varid,storage,reverse(chunksizes))

"""
    storage,chunksizes = chunking(v::Variable)

Return the storage type (:contiguous or :chunked) and the chunk sizes
of the varable `v`.
"""
function chunking(v::Variable)
    storage,chunksizes = nc_inq_var_chunking(v.ncid,v.varid)
    return storage,reverse(chunksizes)
end

"""
    shuffle,deflate,deflate_level = deflate(v::Variable)

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

function Base.getindex{T,N}(v::Variable{T,N},indexes::Colon...)
    # special case for scalar NetCDF variable
    if N == 0
        data = Vector{T}(1)
        nc_get_var!(v.ncid,v.varid,data)
        return data[1]
    else
        #@show v.shape,typeof(v.shape),T,N
        #@show v.ncid,v.varid
        data = Array{T,N}(size(v))
        nc_get_var!(v.ncid,v.varid,data)
        return data
    end
end

function Base.setindex!{T,N}(v::Variable{T,N},data::T,indexes::Colon...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp = fill(data,size(v))
    #@show "here number",indexes,size(v),fill(data,size(v))
    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Number,indexes::Colon...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp = fill(convert(T,data),size(v))
    #@show "here number",indexes,size(v),tmp
    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Array{T,N},indexes::Colon...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    #@show @__LINE__,@__FILE__
    nc_put_var(v.ncid,v.varid,data)
    return data
end

function Base.setindex!{T,T2,N}(v::Variable{T,N},data::Array{T2,N},indexes::Colon...)
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
    jlshape = (count[end:-1:1]...)
    return start,count,stride,jlshape
end

function Base.getindex{T,N}(v::Variable{T,N},indexes::StepRange{Int,Int}...)
    #@show "get sr",indexes
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    data = Array{T,N}(jlshape)
    nc_get_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::T,indexes::StepRange{Int,Int}...)
    #@show @__FILE__,@__LINE__,indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(data,jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Number,indexes::StepRange{Int,Int}...)
    #@show @__FILE__,@__LINE__,indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(convert(T,data),jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Array{T,N},indexes::StepRange{Int,Int}...)
    #@show "sr",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    nc_put_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

# data can be Array{T2,N} or BitArray{N}
function Base.setindex!{T,N}(v::Variable{T,N},data::AbstractArray,indexes::StepRange{Int,Int}...)
    #@show "sr2",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])

    tmp = convert(Array{T,ndims(data)},data)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)

    return data
end

function normalizeindexes(sz,indexes)
    ndims = length(sz)
    ind = Vector{StepRange}(ndims)
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
        return squeeze(data,(find(squeezedim)...))
    else
        return data
    end
end


function Base.setindex!(v::Variable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    #@show "any",indexes
    ind,squeezedim = normalizeindexes(size(v),indexes)

    # make arrays out of scalars
    if ndims(data) == 0
        data = fill(data,([length(i) for i in ind]...))
    end

    if ndims(data) == 1 && size(data,1) == 1
        data = fill(data[1],([length(i) for i in ind]...))
    end

    # return data
    return v[ind...] = data
end


# -----------------------------------------------------
# Variable (with applied transformation following the CF convention)


type CFVariable{NetCDFType,T,N}  <: AbstractArray{Float64, N}
    var::Variable{NetCDFType,N}
    attrib::Attributes
    #has_fillvalue::Bool
    #has_add_offset::Bool
    #has_scale_factor::Bool

    #fillvalue::NetCDFType
    #add_offset
    #scale_factor
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
        mask = falses(data)
    end

    # do not scale characters and strings
    if eltype(v.var) != Char
        if "scale_factor" in attnames
            data = v.attrib["scale_factor"] * data
        end

        if "add_offset" in attnames
            data = data + v.attrib["add_offset"]
        end
    end

    if "units" in attnames
        units = v.attrib["units"]
        if contains(units," since ")
            # type of data changes
            calendar = get(v.attrib,"calendar","standard")
            data = timedecode(data,units,calendar)
        end
    end

    if isscalar
        #return NullableArray(data,mask)[1]
        return DataArray(data,mask)[1]
    else
        #return NullableArray(data,mask)
        return DataArray(data,mask)
    end
end

function Base.setindex!(v::CFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    x =
        if typeof(data) <: AbstractArray
            Array{eltype(data),ndims(data)}(size(data))
        else
            Array{typeof(data),1}(1)
        end

    #@show typeof(data)
    #@show eltype(v.var)

    attnames = keys(v.attrib)

    #@show "here",ndims(x),ndims(data)

    if isa(data,DataArray)
        mask = ismissing.(data)
        x[.!mask] = data[.!mask]
    else
        if !(typeof(data) <: AbstractArray)
            # for scalars
            x = [data]
            mask = [false]
        else
            x = copy(data)
            mask = falses(data)
        end
    end

    if "units" in attnames
        units = v.attrib["units"]
        if contains(units," since ")
            calendar = get(v.attrib,"calendar","standard")
            x = timeencode(x,units,calendar)
        end
    end

    if "_FillValue" in attnames
        x[mask] = v.attrib["_FillValue"]
    else
        # should we issue a warning?
    end

    # do not scale characters and strings
    if eltype(v.var) != Char
        if "add_offset" in attnames
            x[.!mask] = x[.!mask] - v.attrib["add_offset"]
        end

        if "scale_factor" in attnames
            x[.!mask] = x[.!mask] / v.attrib["scale_factor"]
        end
    end

    if !(typeof(data) <: AbstractArray)
        v.var[indexes...] = x[1]
    else
        v.var[indexes...] = x
    end

    return data
end



function Base.show(io::IO,v::Variable; indent="")
    delim = " × "
    sz = size(v)

    print_with_color(:green, io, indent, name(v))
    if length(sz) > 0
        print(io,indent," (",join(sz,delim),")\n")
        print(io,indent,"  Datatype:    ",eltype(v),"\n")
        print(io,indent,"  Dimensions:  ",join(dimnames(v),delim),"\n")
    else
        print(io,indent,"\n")
    end

    if length(v.attrib) > 0
        print(io,indent,"  Attributes:\n")
        show(io,v.attrib; indent = "$(indent)   ")
    end
end

Base.show(io::IO,v::CFVariable; indent="") = Base.show(io::IO,v.var; indent=indent)

Base.display(v::Union{Variable,CFVariable}) = show(STDOUT,v)


# Common methods

const NCIterable = Union{BaseAttributes,Dimensions,Dataset,Groups}

Base.length(a::NCIterable) = length(keys(a))

"""
    haskey(ds::Dataset,varname)

Return true of the Dataset `ds` has a variable with the name `varname`.
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
# for iteration as a Dict

"""
    start(ds::NCDatasets.Dataset)
    start(a::NCDatasets.Attributes)
    start(d::NCDatasets.Dimensions)
    start(g::NCDatasets.Groups)

Allow one to iterate over a dataset, attribute list, dimensions and NetCDF groups.

```julia
for (varname,var) in ds
    # all variables
    @show (varname,size(var))
end

for (dimname,dim) in ds.dims
    # all dimensions
    @show (dimname,dim)
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
"""

Base.start(a::NCIterable) = keys(a)
Base.done(a::NCIterable,state) = length(state) == 0
Base.next(a::NCIterable,state) = (state[1] => a[shift!(state)], state)


"""
    escape(val)

Escape backslash, dollar and quote from string `val`.
"""
function escape(val)
     valescaped = val
     # backslash must come first
     for c in ['\\','$','"']
        valescaped = replace(valescaped,c,"\\$c")
    end
	return valescaped
end


function ncgen(io::IO,fname; newfname = "filename.nc")
    ds = Dataset(fname)

    print(io,"ds = Dataset(\"$(escape(newfname))\",\"c\")\n")

    print(io,"# Dimensions\n\n")
    for (d,v) in ds.dim
        print(io,"ds.dim[\"$d\"] = $v\n")
    end

    print(io,"\n# Declare variables\n\n")

    for (d,v) in ds
        print(io,"nc$d = defVar(ds,\"$d\", $(eltype(v.var)), $(dimnames(v))) \n")
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

ncgen(fname; kwargs...)  = ncgen(STDOUT,fname; kwargs...)

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
    a = nomissing(da::DataArray)

Retun the values of the DataArray `da` as a regular Julia array `a` of the same
element type and checks that no missing values are present.
"""
function nomissing(da::DataArray)
    if any(ismissing.(da))
        error("arrays contains missing values (values equal to the fill values attribute in the NetCDF file)")
    end

    return da.data
end

"""
    a = nomissing(da::DataArray,value)

Retun the values of the DataArray `da` as a regular Julia array `a`
by replacing all missing value by `value`.
"""
function nomissing(da::DataArray,value)
    d = copy(da.data)
    d[ismissing.(da)] = value

    return d
end

export defVar, defDim, Dataset, close, sync, variable, dimnames, name,
    deflate, chunking, checksum, fillvalue, fillmode, ncgen
export nomissing
export varbyattrib
export path
export defGroup

# it is good practise to use the default fill-values, thus we export them
export NC_FILL_BYTE, NC_FILL_CHAR, NC_FILL_SHORT, NC_FILL_INT, NC_FILL_FLOAT,
    NC_FILL_DOUBLE, NC_FILL_UBYTE, NC_FILL_USHORT, NC_FILL_UINT, NC_FILL_INT64,
    NC_FILL_UINT64, NC_FILL_STRING

end # module
