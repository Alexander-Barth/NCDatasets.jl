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
mutable struct CFVariable{T,N,TV,TA,TSA}  <: AbstractArray{T, N}
    # this var is generally a `Variable` type
    var::TV
    # Dict-like object for all attributes read from disk
    attrib::TA
    # a named tuple with fill value, scale factor, offset,...
    # immutable for type-stability
    _storage_attrib::TSA
end

"""
    ds = NCDataset(var::CFVariable)
    ds = NCDataset(var::Variable)

Return the `NCDataset` containing the variable `var`.
"""
NCDataset(var::CFVariable) = NCDataset(var.var)
NCDataset(var::Variable) = NCDataset(var.ncid,var.isdefmode)

"""
    sz = size(var::CFVariable)

Return a tuple of integers with the size of the variable `var`.

!!! note

    Note that the size of a variable can change, i.e. for a variable with an
    unlimited dimension.
"""
Base.size(v::CFVariable) = size(v.var)
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

Instead of providing the variable type one can directly give also the data `data` which
will be used to fill the NetCDF variable. In this case, the dimensions with
the appropriate size will be created as required using the names in `dimnames`.

If `data` is a vector or array of `DateTime` objects, then the dates
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

In this example, `scale_factor` and `add_offset` are applied when the `data`
is saved.

```julia-repl
julia> using DataStructures
julia> data = randn(3,5)
julia> NCDataset("test_file.nc","c") do ds
          defVar(ds,"temp",data,("lon","lat"), attrib = OrderedDict(
             "units" => "degree_Celsius",
             "add_offset" => -273.15,
             "scale_factor" => 0.1,
             "long_name" => "Temperature"
          ))
       end;
```

!!! note

    If the attributes `_FillValue`, `add_offset`, `scale_factor`, `units` and
    `calendar` are used, they should be defined when calling `defVar` by using the
    parameter `attrib` as shown in the example above.
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

function _defVar(ds::NCDataset,name,data,nctype,dimnames; attrib = [], kwargs...)
    # define the dimensions if necessary
    for i = 1:length(dimnames)
        if !(dimnames[i] in ds.dim)
            ds.dim[dimnames[i]] = size(data,i)
        end
    end

    T = eltype(data)
    attrib = collect(attrib)

    if T <: Union{TimeType,Missing}
        dattrib = Dict(attrib)
        if !haskey(dattrib,"units")
            push!(attrib,"units" => CFTime.DEFAULT_TIME_UNITS)
        end
        if !haskey(dattrib,"calendar")
            # these dates cannot be converted to the standard calendar
            if T <: Union{DateTime360Day,Missing}
                push!(attrib,"calendar" => "360_day")
            elseif T <: Union{DateTimeNoLeap,Missing}
                push!(attrib,"calendar" => "365_day")
            elseif T <: Union{DateTimeAllLeap,Missing}
                push!(attrib,"calendar" => "366_day")
            end
        end
    end

    v =
        if Missing <: T
            # make sure a fill value is set (it might be overwritten by kwargs...)
            defVar(ds,name,nctype,dimnames;
                   fillvalue = ncFillValue[nctype],
                   attrib = attrib,
                   kwargs...)
        else
            defVar(ds,name,nctype,dimnames;
                   attrib = attrib,
                   kwargs...)
        end

    v[:] = data
    return v
end


function defVar(ds::NCDataset,name,data::T; kwargs...) where T <: Number
    v = defVar(ds,name,T,(); kwargs...)
    v[:] = data
    return v
end

"""
    renameVar(ds::NCDataset,oldname,newname)

Rename the variable called `oldname` to `newname`.
"""
function renameVar(ds::NCDataset,oldname::AbstractString,newname::AbstractString)
    # make sure that the file is in define mode
    defmode(ds.ncid,ds.isdefmode)
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
    shape = zeros(Int,ndims)

    for i = 1:ndims
        shape[ndims-i+1] = nc_inq_dimlen(ds.ncid,dimids[i])
    end

    attrib = Attributes(ds.ncid,varid,ds.isdefmode)

    # reverse dimids to have the dimension order in Fortran style
    return Variable{nctype,ndims}(ds.ncid,varid,
                                  (reverse(dimids)...,),
                                  attrib,ds.isdefmode)
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

    fillvalue = get(v.attrib,"_FillValue",nothing)
    scale_factor = get(v.attrib,"scale_factor",nothing)
    add_offset = get(v.attrib,"add_offset",nothing)

    calendar = nothing
    time_origin = nothing
    time_factor = nothing
    if haskey(v.attrib,"units")
        units = v.attrib["units"]
        if occursin(" since ",units)
            calendar = lowercase(get(v.attrib,"calendar","standard"))
            time_origin,time_factor = CFTime.timeunits(units, calendar)
        end
    end

    scaledtype = eltype(v)

    if eltype(v) <: Number
        if scale_factor != nothing
            scaledtype = promote_type(scaledtype, typeof(scale_factor))
        end

        if add_offset != nothing
            scaledtype = promote_type(scaledtype, typeof(add_offset))
        end
    end

    rettype = scaledtype

    if calendar != nothing
        units = get(v.attrib,"units","")
        if occursin(" since ",units)
            # type of data changes
            calendar = lowercase(get(v.attrib,"calendar","standard"))
            DT = CFTime.timetype(calendar)
            # this is the only supported option for NCDatasets
            prefer_datetime = true

            if prefer_datetime &&
                (DT in [DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian])
                rettype = DateTime
            else
                rettype = DT
            end
        end
    end

    if fillvalue != nothing
        rettype = Union{Missing,rettype}
    end

    storage_attrib = (
        fillvalue = fillvalue,
        scale_factor = scale_factor,
        add_offset = add_offset,
        calendar = calendar,
        time_origin = time_origin,
        time_factor = time_factor,
    )

    return CFVariable{rettype,ndims(v),typeof(v),typeof(v.attrib),typeof(storage_attrib)}(
        v,v.attrib,storage_attrib)
end


"""
    NCDatasets.load!(ncvar::Variable, data, indices)

Loads a NetCDF variables `ncvar` in-place and puts the result in `data` along the
specified `indices`.

```julia
ds = Dataset("file.nc")
ncv = ds["vgos"].var;
# data must have the right shape and type
data = zeros(eltype(ncv),size(ncv));
NCDatasets.load!(ncv,data,:,:,:)
close(ds)

# loading a subset
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
function dimnames(v::Variable{T,N}) where {T,N}
    return ntuple(i -> nc_inq_dimname(v.ncid,v.dimids[i]),Val(N))
end
dimnames(v::CFVariable)  = dimnames(v.var)

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

function fillvalue(v::Variable{NetCDFType,N}) where {NetCDFType,N}
    no_fill,fv = nc_inq_var_fill(v.ncid, v.varid)
    return fv::NetCDFType
end

name(v::CFVariable) = name(v.var)
chunking(v::CFVariable,storage,chunksize) = chunking(v.var,storage,chunksize)
chunking(v::CFVariable) = chunking(v.var)

deflate(v::CFVariable,shuffle,dodeflate,deflate_level) = deflate(v.var,shuffle,dodeflate,deflate_level)
deflate(v::CFVariable) = deflate(v.var)

checksum(v::CFVariable,checksummethod) = checksum(v.var,checksummethod)
checksum(v::CFVariable) = checksum(v.var)


fillmode(v::CFVariable) = fillmode(v.var)

fillvalue(v::CFVariable) = v._storage_attrib.fillvalue
scale_factor(v::CFVariable) = v._storage_attrib.scale_factor
add_offset(v::CFVariable) = v._storage_attrib.add_offset
time_origin(v::CFVariable) = v._storage_attrib.time_origin
calendar(v::CFVariable) = v._storage_attrib.calendar
""""
    tf = time_factor(v::CFVariable)

The time unit in milliseconds. E.g. seconds would be 1000., days would be 86400000.
The result can also be `nothing` if the variable has no time units.
"""
time_factor(v::CFVariable) = v._storage_attrib.time_factor



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

nomissing(a::AbstractArray,value) = a
