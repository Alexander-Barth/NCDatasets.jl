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


## Dimension ordering

The data is stored in the NetCDF file in same order as they are stored in
memory. As julia uses the
[Column-major ordering](https://en.wikipedia.org/wiki/Row-_and_column-major_order)
for arrays, the order of dimensions will appear reversed when the data in loaded
in languages or programms using
[Row-major ordering](https://en.wikipedia.org/wiki/Row-_and_column-major_order)
such as C/C++, Python/NumPy or the tools `ncdump`/`ncgen`
([NetCDF CDL](https://web.archive.org/web/20220513091844/https://docs.unidata.ucar.edu/nug/current/_c_d_l.html)).
NumPy can also use Column-major ordering but Row-major order is the default. For the column-major
interpretation of the dimensions (as in Julia), the
[CF Convention recommends](https://web.archive.org/web/20220328110810/http://cfconventions.org/Data/cf-conventions/cf-conventions-1.7/cf-conventions.html#dimensions) the
order  "longitude" (X), "latitude" (Y), "height or depth" (Z) and
"date or time" (T) (if applicable). All other dimensions should, whenever
possible, be placed to the right of the spatiotemporal dimensions.

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

    If the attributes `_FillValue`, `missing_value`, `add_offset`, `scale_factor`,
    `units` and `calendar` are used, they should be defined when calling `defVar`
    by using the parameter `attrib` as shown in the example above.


"""
function defVar(ds::NCDataset,name,vtype::DataType,dimnames; kwargs...)
    # all keyword arguments as dictionary
    kw = Dict(k => v for (k,v) in kwargs)

    defmode(ds) # make sure that the file is in define mode
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



function _boundsParentVar(ds,varname)
    # iterating using variable ids instead of variable names
    # is more efficient (but not possible for e.g. multi-file datasets)
    eachvariable(ds::NCDataset) = (variable(ds,varid) for varid in nc_inq_varids(ds.ncid))
    eachvariable(ds) = (variable(ds,vname) for vname in keys(ds))


    # get from cache is available
    if length(values(ds._boundsmap)) > 0
        return get(ds._boundsmap,varname,"")
    else
        for v in eachvariable(ds)
            bounds = get(v.attrib,"bounds","")
            if bounds === varname
                return name(v)
            end
        end

        return ""
    end
end


"""
    _getattrib(ds,v,parentname,attribname,default)

Get a NetCDF attribute, looking also at the parent variable name
(linked via the bounds attribute as following the CF conventions).
The default value is returned if the attribute cannot be found.
"""
function _getattrib(ds,v,parentname,attribname,default)
    val = get(v.attrib,attribname,nothing)
    if val !== nothing
        return val
    else
        if (parentname === nothing) || (parentname === "")
            return default
        else
            vp = variable(ds,parentname)
            return get(vp.attrib,attribname,default)
        end
    end
end

"""
    v = cfvariable(ds::NCDataset,varname::AbstractString; <attrib> = <value>)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The keyword argument `<attrib>` are
the NetCDF attributes (`fillvalue`, `missing_value`, `scale_factor`, `add_offset`,
`units` and `calendar`) relevant to the CF conventions.
By specifing the value of these attributes, the one can override the value
specified in the NetCDF file. If the attribute is set to `nothing`, then
the attribute is not loaded and the corresponding transformation is ignored.
This function is similar to `ds[varname]` with the additional flexibility that
some variable attributes can be overridden.


Example:

```julia
NCDataset("foo.nc","c") do ds
  defVar(ds,"data",[10., 11., 12., 13.], ("time",), attrib = Dict(
      "add_offset" => 10.,
      "scale_factor" => 0.2))
end

# The stored (packed) valued are [0., 5., 10., 15.]
# since 0.2 .* [0., 5., 10., 15.] .+ 10 is [10., 11., 12., 13.]

ds = NCDataset("foo.nc");

@show ds["data"].var[:]
# returns [0., 5., 10., 15.]

@show cfvariable(ds,"data")[:]
# returns [10., 11., 12., 13.]

# neither add_offset nor scale_factor are applied
@show cfvariable(ds,"data", add_offset = nothing, scale_factor = nothing)[:]
# returns [0, 5, 10, 15]

# add_offset is applied but not scale_factor
@show cfvariable(ds,"data", scale_factor = nothing)[:]
# returns [10, 15, 20, 25]

# 0 is declared as the fill value (add_offset and scale_factor are applied as usual)
@show cfvariable(ds,"data", fillvalue = 0)[:]
# return [missing, 11., 12., 13.]

# Use the time units: days since 2000-01-01
@show cfvariable(ds,"data", units = "days since 2000-01-01")[:]
# returns [DateTime(2000,1,11), DateTime(2000,1,12), DateTime(2000,1,13), DateTime(2000,1,14)]

close(ds)
```
"""
function cfvariable(ds,
                    varname;
                    _v = variable(ds,varname),
                    # special case for bounds variable who inherit
                    # units and calendar from parent variables
                    _parentname = _boundsParentVar(ds,varname),
                    fillvalue = get(_v.attrib,"_FillValue",nothing),
                    # missing_value can be a vector
                    missing_value = get(_v.attrib,"missing_value",eltype(_v)[]),
                    #valid_min = get(_v.attrib,"valid_min",nothing),
                    #valid_max = get(_v.attrib,"valid_max",nothing),
                    #valid_range = get(_v.attrib,"valid_range",nothing),
                    scale_factor = get(_v.attrib,"scale_factor",nothing),
                    add_offset = get(_v.attrib,"add_offset",nothing),
                    # look also at parent if defined
                    units = _getattrib(ds,_v,_parentname,"units",nothing),
                    calendar = _getattrib(ds,_v,_parentname,"calendar",nothing),
                    )

    v = _v
    T = eltype(v)


    # sanity check
    if (T <: Number) && (
        (eltype(missing_value) <: AbstractChar) ||
            (eltype(missing_value) <: AbstractString))
        @warn "variable '$varname' has a numeric type but the corresponding " *
            "missing_value ($(litteral(missing_value))) is a character or string. " *
            "Comparing, e.g. an integer and a string (1 == \"1\") will always evaluate to false. " *
            "See the function NCDatasets.cfvariable how to manually override the missing_value attribute."
    end

    time_origin = nothing
    time_factor = nothing

    if (units isa String) && occursin(" since ",units)
        if calendar == nothing
            calendar = "standard"
        elseif calendar isa String
            calendar = lowercase(calendar)
        end
        try
            time_origin,time_factor = CFTime.timeunits(units, calendar)
        catch
            # ignore, warning is emited by CFTime.timeunits
        end
    end

    scaledtype = T
    if eltype(v) <: Number
        if scale_factor !== nothing
            scaledtype = promote_type(scaledtype, typeof(scale_factor))
        end

        if add_offset !== nothing
            scaledtype = promote_type(scaledtype, typeof(add_offset))
        end
    end

    storage_attrib = (
        fillvalue = fillvalue,
        missing_values = (missing_value...,),
        scale_factor = scale_factor,
        add_offset = add_offset,
        calendar = calendar,
        time_origin = time_origin,
        time_factor = time_factor,
    )

    rettype = _get_rettype(ds, calendar, fillvalue, missing_value, scaledtype)

    return CFVariable{rettype,ndims(v),typeof(v),typeof(_v.attrib),typeof(storage_attrib)}(
        v,_v.attrib,storage_attrib)

end

export cfvariable

"""
    v = getindex(ds::NCDataset,varname::AbstractString)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The following CF convention are honored when the
variable is indexed:
* `_FillValue` or `missing_value` (which can be a list) will be returned as `missing`. `NCDatasets` does not use implicitely the default NetCDF fill values when reading data.
* `scale_factor` and `add_offset` are applied (output = `scale_factor` * data_in_file +  `add_offset`)
* time variables (recognized by the units attribute and possibly the calendar attribute) are returned usually as
  `DateTime` object. Note that `DateTimeAllLeap`, `DateTimeNoLeap` and
  `DateTime360Day` cannot be converted to the proleptic gregorian calendar used in
  julia and are returned as such. If a calendar is defined but not among the
ones specified in the CF convention, then the data in the NetCDF file is not
converted into a date structure.

A call `getindex(ds,varname)` is usually written as `ds[varname]`.

If variable represents a cell boundary, the attributes `calendar` and `units` of the related NetCDF variables are used, if they are not specified. For example:

```
dimensions:
  time = UNLIMITED; // (5 currently)
  nv = 2;
variables:
  double time(time);
    time:long_name = "time";
    time:units = "hours since 1998-04-019 06:00:00";
    time:bounds = "time_bnds";
  double time_bnds(time,nv);
```

In this case, the variable `time_bnds` uses the units and calendar of `time`
because both variables are related thought the bounds attribute following the CF conventions.

See also cfvariable
"""
function Base.getindex(ds::AbstractDataset,varname::SymbolOrString)
    return cfvariable(ds, varname)
end


function _get_rettype(ds, calendar, fillvalue, missing_value, rettype)
    # rettype can be a date if calendar is different from nothing
    if calendar !== nothing
        DT = nothing
        try
            DT = CFTime.timetype(calendar)
            # this is the only supported option for NCDatasets
            prefer_datetime = true

            if prefer_datetime &&
                (DT in (DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian))
                rettype = DateTime
            else
                rettype = DT
            end
        catch
            @warn("unsupported calendar `$calendar`. Time units are ignored.")
        end
    end

    if (fillvalue !== nothing) || (!isempty(missing_value))
        rettype = Union{Missing,rettype}
    end
    return rettype
end


"""
    dimnames(v::CFVariable)

Return a tuple of strings with the dimension names of the variable `v`.
"""
dimnames(v::Union{CFVariable,MFCFVariable})  = dimnames(v.var)


"""
    dimsize(v::CFVariable)
Get the size of a `CFVariable` as a named tuple of dimension → length.
"""
function dimsize(v::Union{CFVariable,MFCFVariable})
    s = size(v)
    names = Symbol.(dimnames(v))
    return NamedTuple{names}(s)
end
export dimsize


name(v::Union{CFVariable,MFCFVariable}) = name(v.var)
chunking(v::CFVariable,storage,chunksize) = chunking(v.var,storage,chunksize)
chunking(v::CFVariable) = chunking(v.var)

deflate(v::CFVariable,shuffle,dodeflate,deflate_level) = deflate(v.var,shuffle,dodeflate,deflate_level)
deflate(v::CFVariable) = deflate(v.var)

checksum(v::CFVariable,checksummethod) = checksum(v.var,checksummethod)
checksum(v::CFVariable) = checksum(v.var)


fillmode(v::CFVariable) = fillmode(v.var)

fillvalue(v::CFVariable) = v._storage_attrib.fillvalue
missing_values(v::CFVariable) = v._storage_attrib.missing_values

# collect all possible fill values
function fill_and_missing_values(v::CFVariable)
    T = eltype(v.var)
    fv = ()
    if !isnothing(fillvalue(v))
        fv = (fillvalue(v),)
    end

    mv = missing_values(v)
    (fv...,mv...)
end

scale_factor(v::CFVariable) = v._storage_attrib.scale_factor
add_offset(v::CFVariable) = v._storage_attrib.add_offset
time_origin(v::CFVariable) = v._storage_attrib.time_origin
calendar(v::CFVariable) = v._storage_attrib.calendar
""""
    tf = time_factor(v::CFVariable)

The time unit in milliseconds. E.g. seconds would be 1000., days would be 86400000.
The result can also be `nothing` if the variable has no time units.
"""
time_factor(v::CFVariable) = v._storage_attrib[:time_factor]


############################################################
# CFVariable
############################################################



# fillvalue can be NaN (unfortunately)
@inline isfillvalue(data,fillvalue) = data == fillvalue
@inline isfillvalue(data,fillvalue::AbstractFloat) = (isnan(fillvalue) ? isnan(data) : data == fillvalue)

# tuple peeling
@inline function CFtransform_missing(data,fv::Tuple)
    if isfillvalue(data,first(fv))
        missing
    else
        CFtransform_missing(data,Base.tail(fv))
    end
end

@inline CFtransform_missing(data,fv::Tuple{}) = data

@inline CFtransform_replace_missing(data,fv) = (ismissing(data) ? first(fv) : data)
@inline CFtransform_replace_missing(data,fv::Tuple{}) = data

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


@inline fromdate(data::TimeType,time_origin,inv_time_factor) =
    Dates.value(data - time_origin) * inv_time_factor
@inline fromdate(data,time_origin,time_factor) = data

@inline function CFtransform(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)
    return asdate(
        CFtransform_offset(
            CFtransform_scale(
                CFtransform_missing(data,fv),
                scale_factor),
            add_offset),
        time_origin,time_factor,DTcast)
end

# round float to integers
_approximate(::Type{T},data) where T <: Integer = round(T,data)
_approximate(::Type,data) = data


@inline function CFinvtransform(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
    return _approximate(
        DT,
        CFtransform_replace_missing(
            CFtransform_scale(
                CFtransform_offset(
                    fromdate(data,time_origin,inv_time_factor),
                    minus_offset),
                inv_scale_factor),
            fv))
end


# this is really slow
# https://github.com/JuliaLang/julia/issues/28126
#@inline CFtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) =
#    # in boardcasting we trust..., or not
#    CFtransform.(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)

# for scalars
@inline CFtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) =
    CFtransform(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)

# in-place version
@inline function CFtransformdata!(out,data::AbstractArray{T,N},fv,scale_factor,add_offset,time_origin,time_factor) where {T,N}
    DTcast = eltype(out)
    @inbounds @simd for i in eachindex(data)
        out[i] = CFtransform(data[i],fv,scale_factor,add_offset,time_origin,time_factor,DTcast)
    end
    return out
end

# for arrays
@inline function CFtransformdata(data::AbstractArray{T,N},fv,scale_factor,add_offset,time_origin,time_factor,DTcast) where {T,N}
    out = Array{DTcast,N}(undef,size(data))
    return CFtransformdata!(out,data::AbstractArray{T,N},fv,scale_factor,add_offset,time_origin,time_factor)
end

@inline function CFtransformdata(
    data::AbstractArray{T,N},fv::Tuple{},scale_factor::Nothing,
    add_offset::Nothing,time_origin::Nothing,time_factor::Nothing,::Type{T}) where {T,N}
    # no transformation necessary (avoid allocation)
    return data
end

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

@inline function CFinvtransformdata(
    data::AbstractArray{T,N},fv::Tuple{},scale_factor::Nothing,
    add_offset::Nothing,time_origin::Nothing,time_factor::Nothing,::Type{T}) where {T,N}
    # no transformation necessary (avoid allocation)
    return data
end

# for scalar
@inline function CFinvtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DT)
    inv_scale_factor = _inv(scale_factor)
    minus_offset = _minus(add_offset)
    inv_time_factor = _inv(time_factor)

    return CFinvtransform(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DT)
end



# this function is necessary to avoid "iterating" over a single character in Julia 1.0 (fixed Julia 1.3)
# https://discourse.julialang.org/t/broadcasting-and-single-characters/16836
@inline CFtransformdata(data::Char,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) = CFtransform_missing(data,fv)
@inline CFinvtransformdata(data::Char,fv,scale_factor,add_offset,time_origin,time_factor,DT) = CFtransform_replace_missing(data,fv)


function Base.getindex(v::CFVariable,
                       indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    data = v.var[indexes...]
    return CFtransformdata(data,fill_and_missing_values(v),scale_factor(v),add_offset(v),
                           time_origin(v),time_factor(v),eltype(v))
end

function Base.setindex!(v::CFVariable,data::Array{Missing,N},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N
    v.var[indexes...] = fill(fillvalue(v),size(data))
end

function Base.setindex!(v::CFVariable,data::Missing,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    v.var[indexes...] = fillvalue(v)
end

function Base.setindex!(v::CFVariable,data::Union{T,Array{T,N}},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N where T <: Union{AbstractCFDateTime,DateTime,Union{Missing,DateTime,AbstractCFDateTime}}

    if calendar(v) !== nothing
        # can throw an convertion error if calendar attribute already exists and
        # is incompatible with the provided data
        v.var[indexes...] = CFinvtransformdata(
            data,fill_and_missing_values(v),scale_factor(v),add_offset(v),
            time_origin(v),time_factor(v),eltype(v.var))
        return data
    end

    throw(NetCDFError(-1, "Time units and calendar must be defined during defVar and cannot change"))
end


function Base.setindex!(v::CFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    v.var[indexes...] = CFinvtransformdata(
        data,fill_and_missing_values(v),
        scale_factor(v),add_offset(v),
        time_origin(v),time_factor(v),eltype(v.var))

    return data
end

############################################################
# Convertion to array
############################################################

Base.Array(v::Union{CFVariable{T,N},Variable{T,N}}) where {T,N} = v[ntuple(i -> :, Val(N))...]

Base.show(io::IO,v::CFVariable; indent="") = Base.show(io::IO,v.var; indent=indent)

# necessary for IJulia if showing a variable from a closed file
Base.show(io::IO,::MIME"text/plain",v::Union{Variable,CFVariable,MFCFVariable}) = show(io,v)

Base.display(v::Union{Variable,CFVariable,MFCFVariable}) = show(stdout,v)



"""
    NCDatasets.load!(ncvar::CFVariable, data, buffer, indices)

Loads a NetCDF variables `ncvar` in-place and puts the result in `data` (an
array of `eltype(ncvar)`) along the specified `indices`. `buffer` is a temporary
 array of the same size as data but the type should be `eltype(ncv.var)`, i.e.
the corresponding type in the NetCDF files (before applying `scale_factor`,
`add_offset` and masking fill values). Scaling and masking will be applied to
the array `data`.

`data` and `buffer` can be the same array if `eltype(ncvar) == eltype(ncvar.var)`.

## Example:

```julia
# create some test array
Dataset("file.nc","c") do ds
    defDim(ds,"time",3)
    ncvar = defVar(ds,"vgos",Int16,("time",),attrib = ["scale_factor" => 0.1])
    ncvar[:] = [1.1, 1.2, 1.3]
    # store 11, 12 and 13 as scale_factor is 0.1
end


ds = Dataset("file.nc")
ncv = ds["vgos"];
# data and buffer must have the right shape and type
data = zeros(eltype(ncv),size(ncv)); # here Vector{Float64}
buffer = zeros(eltype(ncv.var),size(ncv)); # here Vector{Int16}
NCDatasets.load!(ncv,data,buffer,:,:,:)
close(ds)
```
"""
@inline function load!(v::Union{CFVariable{T,N},MFCFVariable{T,N}}, data, buffer, indices::Union{Integer, UnitRange, StepRange, Colon}...) where {T,N}

    load!(v.var,buffer,indices...)
    fmv = fill_and_missing_values(v)
    return CFtransformdata!(data,buffer,fmv,scale_factor(v),add_offset(v),
                           time_origin(v),time_factor(v))

end
