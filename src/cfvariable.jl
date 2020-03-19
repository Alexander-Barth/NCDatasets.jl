

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


NCDataset(var::CFVariable) = NCDataset(var.var)


"""
    sz = size(var::CFVariable)

Return a tuple of integers with the size of the variable `var`.

!!! note

    Note that the size of a variable can change, i.e. for a variable with an
    unlimited dimension.
"""
Base.size(v::CFVariable) = size(v.var)

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
        elseif !(dimnames[i] in unlimited(ds.dim))
            dimlen = ds.dim[dimnames[i]]

            if (dimlen !== size(data,i))
                throw(NetCDFError(
                    -1,"dimension $(dimnames[i]) is already defined with the " *
                    "length $dimlen. It cannot be redefined with a length of $(size(data,i))."))
            end
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
                   fillvalue = fillvalue(nctype),
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
export defVar

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
    dimnames(v::CFVariable)

Return a tuple of strings with the dimension names of the variable `v`.
"""
dimnames(v::CFVariable)  = dimnames(v.var)


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


############################################################
# CFVariable
############################################################



# fillvalue can be NaN (unfortunately)
@inline isfillvalue(data,fillvalue) = data == fillvalue
@inline isfillvalue(data,fillvalue::AbstractFloat) = (isnan(fillvalue) ? isnan(data) : data == fillvalue)

@inline CFtransform_missing(data,fv) = (isfillvalue(data,fv) ? missing : data)
@inline CFtransform_missing(data,fv::Nothing) = data

@inline CFtransform_replace_missing(data,fv) = (ismissing(data) ? fv : data)
@inline CFtransform_replace_missing(data,fv::Nothing) = data

@inline CFtransform_scale(data,scale_factor) = data*scale_factor
@inline CFtransform_scale(data,scale_factor::Nothing) = data
@inline CFtransform_scale(data::T,scale_factor) where T <: Union{Char,String} = data
@inline CFtransform_scale(data::T,scale_factor::Nothing) where T <: Union{Char,String} = data

@inline CFtransform_offset(data,add_offset) = data + add_offset
@inline CFtransform_offset(data,add_offset::Nothing) = data
@inline CFtransform_offset(data::T,add_factor) where T <: Union{Char,String} = data
@inline CFtransform_offset(data::T,add_factor::Nothing) where T <: Union{Char,String} = data


@inline asdate(data::Missing,time_origin,time_factor,DTcast) = data
@inline asdate(data,time_origin::Nothing,time_factor,DTcast) = data
@inline asdate(data::Missing,time_origin::Nothing,time_factor,DTcast) = data
@inline asdate(data,time_origin,time_factor,DTcast) =
    convert(DTcast,time_origin + Dates.Millisecond(round(Int64,time_factor * data)))


@inline fromdate(data::TimeType,time_origin,inv_time_factor,DTcast) =
    Dates.value(DTcast(data) - time_origin) * inv_time_factor
@inline fromdate(data,time_origin,time_factor,DTcast) = data

@inline function CFtransform(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)
    return asdate(CFtransform_offset(CFtransform_scale(CFtransform_missing(data,fv),scale_factor),add_offset),time_origin,time_factor,DTcast)
end

# round float to integers
_approximate(::Type{T},data) where T <: Integer = round(T,data)
_approximate(::Type,data) = data


@inline function CFinvtransform(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
    return _approximate(DT,CFtransform_replace_missing(
        CFtransform_scale(CFtransform_offset(data,minus_offset),
                          inv_scale_factor),fv))
end


# this is really slow
# https://github.com/JuliaLang/julia/issues/28126
#@inline CFtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) =
#    # in boardcasting we trust..., or not
#    CFtransform.(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)

# for scalars
@inline CFtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) =
    CFtransform(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)

# for arrays
@inline function CFtransformdata(data::AbstractArray{T,N},fv,scale_factor,add_offset,time_origin,time_factor,DTcast) where {T,N}
    out = Array{DTcast,N}(undef,size(data))
    @inbounds @simd for i in eachindex(data)
        out[i] = CFtransform(data[i],fv,scale_factor,add_offset,time_origin,time_factor,DTcast)
    end
    return out
end

# this function is necessary to avoid "iterating" over a single character in Julia 1.0 (fixed Julia 1.3)
# https://discourse.julialang.org/t/broadcasting-and-single-characters/16836
@inline CFtransformdata(data::Char,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) = data
@inline CFinvtransformdata(data::Char,fv,scale_factor,add_offset,time_origin,time_factor,DT) = data


@inline _inv(x::Nothing) = nothing
@inline _inv(x) = 1/x
@inline _minus(x::Nothing) = nothing
@inline _minus(x) = -x


# # so slow
# @inline function CFinvtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DT)
#     inv_scale_factor = _inv(scale_factor)
#     minus_offset = _minus(add_offset)
#     inv_time_factor = _inv(time_factor)
#     return CFinvtransform.(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
# end

# for arrays
@inline function CFinvtransformdata(data::AbstractArray{T,N},fv,scale_factor,add_offset,time_origin,time_factor,DT) where {T,N}
    inv_scale_factor = _inv(scale_factor)
    minus_offset = _minus(add_offset)
    inv_time_factor = _inv(time_factor)

    out = Array{DT,N}(undef,size(data))
    @inbounds @simd for i in eachindex(data)
        out[i] = CFinvtransform(data[i],fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
    end
    return out
end

# for scalar
@inline function CFinvtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DT)
    inv_scale_factor = _inv(scale_factor)
    minus_offset = _minus(add_offset)
    inv_time_factor = _inv(time_factor)

    return CFinvtransform(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
end

function Base.getindex(v::CFVariable,
                       indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    data = v.var[indexes...]
    return CFtransformdata(data,fillvalue(v),scale_factor(v),add_offset(v),
                           time_origin(v),time_factor(v),eltype(v))
end

function Base.setindex!(v::CFVariable,data::Array{Missing,N},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N
    v.var[indexes...] = fill(fillvalue(v),size(data))
end

function Base.setindex!(v::CFVariable,data::Missing,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    v.var[indexes...] = fillvalue(v)
end

function Base.setindex!(v::CFVariable,data::Union{T,Array{T,N}},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N where T <: Union{AbstractCFDateTime,DateTime,Union{Missing,DateTime,AbstractCFDateTime}}

    units = get(v.attrib,"units",nothing)

    if calendar(v) !== nothing
        # can throw an convertion error if calendar attribute already exists and
        # is incompatible with the provided data
        v[indexes...] = timeencode(data,units,calendar(v))
        return data
    end

    throw(NetCDFError(-1, "Time units and calendar must be defined during defVar and cannot change"))
end


function Base.setindex!(v::CFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    v.var[indexes...] = CFinvtransformdata(
        data,fillvalue(v),scale_factor(v),add_offset(v),
        time_origin(v),time_factor(v),eltype(v.var))

    return data
end

############################################################
# Convertion to array
############################################################

Base.Array(v::Union{CFVariable{T,N},Variable{T,N}}) where {T,N} = v[ntuple(i -> :, Val(N))...]

Base.show(io::IO,v::CFVariable; indent="") = Base.show(io::IO,v.var; indent=indent)

Base.display(v::Union{Variable,CFVariable}) = show(stdout,v)
