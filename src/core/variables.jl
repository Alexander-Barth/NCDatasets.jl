#=
Functionality and definitions
related with the `Variables` types/subtypes
=#

############################################################
# Types and subtypes
############################################################

abstract type AbstractVariable{T,N} <: AbstractArray{T,N} end

# Variable (as stored in NetCDF file, without using
# add_offset, scale_factor and _FillValue)
mutable struct Variable{NetCDFType,N} <: AbstractVariable{NetCDFType, N}
    ncid::Cint
    varid::Cint
    dimids::NTuple{N,Cint}
    attrib::Attributes
    isdefmode::Vector{Bool}
end

# Variable (with applied transformations following the CF convention)
mutable struct CFVariable{T,N,TV,TA}  <: AbstractArray{T, N}
    var::TV # this var is a `Variable` type
    attrib::TA
end

NCDataset(var::CFVariable) = NCDataset(var.var)

Base.size(v::CFVariable) = size(v.var)
dimnames(v::CFVariable)  = dimnames(v.var)

NCDataset(var::Variable) = NCDataset(var.ncid,var.isdefmode)

# the size of a variable can change, i.e. for a variable with an unlimited
# dimension
Base.size(v::Variable{T,N}) where {T,N} = ntuple(i -> nc_inq_dimlen(v.ncid,v.dimids[i]),Val(N))

############################################################
# Creating variables
############################################################

"""
    defVar(ds::NCDataset,name,vtype,dimnames; kwargs...)
    defVar(ds::NCDataset,name,data,dimnames; kwargs...)

Define a variable with the name `name` in the dataset `ds`.  `vtype` can be
Julia types in the table below (with the corresponding NetCDF type). The
parameter `dimnames` is a tuple with the names of the dimension.  For scalar
this parameter is the empty tuple `()`.
The variable is returned (of the type CFVariable).


Instead of
providing the variable type one can directly give also the data `data` which
will be used to fill the NetCDF variable. In this case, the dimensions with
the appropriate size will be created as required using the names in `dimnames`.


!!! note

    Note if `data` is a vector or array of `DateTime` objects, then the dates
    are saved as double-precision floats and units
    "$(CFTime.DEFAULT_TIME_UNITS)" (unless a time unit
    is specifed with the `attrib` keyword as described below). Dates are
    converted to the default calendar in the CF conversion which is the
    mixed Julian/Gregorian calendar.

## Keyword arguments

* `fillvalue`: A value filled in the NetCDF file to indicate missing data.
   It will be stored in the _FillValue attribute.
* `chunksizes`: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.
* `deflatelevel`: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.
* `shuffle`: If true, the shuffle filter is activated which can improve the compression ratio.
* `checksum`: The checksum method can be `:fletcher32` or `:nochecksum` (checksumming is disabled, which is the default)
* `attrib`: An iterable of attribute name and attribute value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a vector of pairs (see example below)
* `typename` (string): The name of the NetCDF type required for [vlen arrays](https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc_005fdef_005fvlen.html)

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
julia> NCDataset("test_file.nc","c") do ds
          defVar(ds,"temp",data,("lon","lat"), attrib = [
             "units" => "degree_Celsius",
             "long_name" => "Temperature"
          ])
       end;

```
"""
function defVar(ds::NCDataset,name,vtype::DataType,dimnames; kwargs...)
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

# data has the type e.g. Array{Union{Missing,Float64},3}
function defVar(ds::NCDataset,
                name,
                data::AbstractArray{Union{Missing,nctype},N},
                dimnames;
                kwargs...) where nctype <: Union{Int8,UInt8,Int16,Int32,Int64,Float32,Float64} where N
    _defVar(ds::NCDataset,name,data,nctype,dimnames; kwargs...)
end

# data has the type e.g. Vector{DateTime}, Array{Union{Missing,DateTime},3} or
# Vector{DateTime360Day}
# Data is always stored as Float64 in the NetCDF file
function defVar(ds::NCDataset,
                name,
                data::AbstractArray{<:Union{Missing,nctype},N},
                dimnames;
                kwargs...) where nctype <: Union{DateTime,AbstractCFDateTime} where N
    _defVar(ds::NCDataset,name,data,Float64,dimnames; kwargs...)
end

function defVar(ds::NCDataset,name,data,dimnames; kwargs...)
    nctype = eltype(data)
    _defVar(ds::NCDataset,name,data,nctype,dimnames; kwargs...)
end

function _defVar(ds::NCDataset,name,data,nctype,dimnames; kwargs...)
    # define the dimensions if necessary
    for i = 1:length(dimnames)
        if !(dimnames[i] in ds.dim)
            ds.dim[dimnames[i]] = size(data,i)
        end
    end

    v =
        if Missing <: eltype(data)
            # make sure a fill value is set (it might be overwritten by kwargs...)
            defVar(ds,name,nctype,dimnames;
                   fillvalue = ncFillValue[nctype],
                   kwargs...)
        else
            defVar(ds,name,nctype,dimnames; kwargs...)
        end
    v[:] = data
    return v
end


function defVar(ds::NCDataset,name,data::T; kwargs...) where T <: Number
    v = defVar(ds,name,T,(); kwargs...)
    v[:] = data
    return v
end


function renameVar(ds::NCDataset,oldname,newname)
    defmode(ds.ncid,ds.isdefmode) # make sure that the file is in define mode
    varid = nc_inq_varid(ds.ncid,oldname)
    nc_rename_var(ds.ncid,varid,newname)
    return nothing
end
export renameVar


############################################################
# Obtaining variables
############################################################

"""
    v = variable(ds::NCDataset,varname::String)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.Variable`. No scaling or other transformations are applied when the
variable `v` is indexed.
"""
function variable(ds::NCDataset,varname::AbstractString)
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


function compute_element_type(v)
    attnames = keys(v.attrib)


    if "units" in attnames
        units = v.attrib["units"]
        if occursin(" since ",units)
            # type of data changes
            calendar = lowercase(get(v.attrib,"calendar","standard"))
            DT = CFTime.timetype(calendar)
            # this is the only supported option for NCDatasets
            prefer_datetime = true

            if prefer_datetime &&
                (DT in [DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian])
                return DateTime
            else
                return DT
            end
        end
    end

    rettype = eltype(v)

    if eltype(v) <: Number
        scale_factor = get(v.attrib,"scale_factor",nothing)
        if scale_factor != nothing
            rettype = promote_type(rettype, typeof(scale_factor))
            @show rettype
        end

        add_offset = get(v.attrib,"add_offset",nothing)
        if add_offset != nothing
            rettype = promote_type(rettype, typeof(add_offset))
            @show rettype
        end
    end

    if "_FillValue" in attnames
        rettype = Union{Missing,rettype}
    end

    return rettype
end

"""
    v = getindex(ds::NCDataset,varname::AbstractString)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The CF convention are honored when the
variable is indexed:
* `_FillValue` will be returned as `missing`
* `scale_factor` and `add_offset` are applied
* time variables (recognized by the units attribute) are returned usually as
  `DateTime` object. Note that `DateTimeAllLeap`, `DateTimeNoLeap` and
  `DateTime360Day` cannot be converted to the proleptic gregorian calendar used in
  julia and are returned as such.


A call `getindex(ds,varname)` is usually written as `ds[varname]`.
"""
function Base.getindex(ds::AbstractDataset,varname::AbstractString)
    v = variable(ds,varname)

    #return element type of any index operation
    # if eltype(v) <: Number
    #     rettype = Union{Missing,Number,DateTime,AbstractCFDateTime}
    # else
    #     rettype = Union{Missing,eltype(v)}
    # end
    rettype = compute_element_type(v)
    return CFVariable{rettype,ndims(v),typeof(v),typeof(v.attrib)}(v,v.attrib)
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

Load data from `ncvar` in the [contiguous ragged array representation](https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_contiguous_ragged_array_representation) as a
vector of vectors. It is typically used to load a list of profiles
or time series of different length each.

The [indexed ragged array representation](https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_indexed_ragged_array_representation) is currently not supported.
"""
function loadragged(ncvar,index::Colon)
    ds = NCDataset(ncvar.var.ncid,ncvar.var.isdefmode)

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



############################################################
# User API regarding Variables
############################################################
"""
    dimnames(v::Variable)
    dimnames(v::CFVariable)

Return a tuple of strings with the dimension names of the variable `v`.
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
    dimsize(v::CFVariable)
Get the size of a `CFVariable` as a named tuple of dimension → length.
"""
function dimsize(v::CFVariable)
    s = size(v)
    names = Symbol.(dimnames(v))
    return NamedTuple{names}(s)
end
export dimsize

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

name(v::CFVariable) = name(v.var)
chunking(v::CFVariable,storage,chunksize) = chunking(v.var,storage,chunksize)
chunking(v::CFVariable) = chunking(v.var)

deflate(v::CFVariable,shuffle,dodeflate,deflate_level) = deflate(v.var,shuffle,dodeflate,deflate_level)
deflate(v::CFVariable) = deflate(v.var)

checksum(v::CFVariable,checksummethod) = checksum(v.var,checksummethod)
checksum(v::CFVariable) = checksum(v.var)





"""
    a = nomissing(da)

Return the values of the array `da` of type `Array{Union{T,Missing},N}`
(potentially containing missing values) as a regular Julia array `a` of the same
element type. It raises an error if the array contains at least one missing value.

"""
function nomissing(da::AbstractArray{Union{T,Missing},N}) where {T,N}
    if any(ismissing, da)
        error("arrays contains missing values (values equal to the fill values attribute in the NetCDF file)")
    end
    if VERSION >= v"1.2"
        # Illegal instruction (core dumped) in Julia 1.0.5
        # but works on Julia 1.2
        return Array{T,N}(da)
    else
        # old
        if isempty(da)
            return Array{T,N}([])
        else
            return replace(da, missing => da[1])
        end
    end
end

nomissing(a::AbstractArray) = a

"""
    a = nomissing(da,value)

Retun the values of the array `da` of type `Array{Union{T,Missing},N}`
as a regular Julia array `a` by replacing all missing value by `value`
(converted to type `T`).
This function is identical to `coalesce.(da,T(value))` where T is the element
tyoe of `da`.
## Example:

```julia-repl
julia> nomissing([missing,1.,2.],NaN)
# returns [NaN, 1.0, 2.0]
```
"""
function nomissing(da::Array{Union{T,Missing},N},value) where {T,N}
    return replace(da, missing => T(value))
end
