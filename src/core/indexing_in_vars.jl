#=
this file defines the getindex and setindex! functions for
`Variable` and `CFVariable` as well as convertions to Julia Arrays.
=#


############################################################
# Variable
############################################################

function Base.getindex(v::Variable,indexes::Int...)
    #    @show "ind",indexes
    return nc_get_var1(eltype(v),v.ncid,v.varid,[i-1 for i in indexes[ndims(v):-1:1]])
end

function Base.setindex!(v::Variable{T,N},data,indexes::Int...) where N where T
    @debug "$(@__LINE__)"
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
    @debug "setindex! colon $data"
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    tmp = fill(data,size(v))
    #@show "here number",indexes,size(v),fill(data,size(v))
    nc_put_var(v.ncid,v.varid,tmp)
    return data
end

# call to v .= 123
function Base.setindex!(v::Variable{T,N},data::Number) where {T,N}
    @debug "setindex! $data"
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

function ncsub(indexes::NTuple{N,T}) where N where T
    rindexes = reverse(indexes)
    count  = Int[length(i)  for i in rindexes]
    start  = Int[first(i)-1 for i in rindexes]     # use zero-based indexes
    stride = Int[step(i)    for i in rindexes]
    jlshape = length.(indexes)::NTuple{N,Int}
    return start,count,stride,jlshape
end

function Base.getindex(v::Variable{T,N},indexes::TR...) where {T,N} where TR <: Union{StepRange{Int,Int},UnitRange{Int}}
    start,count,stride,jlshape = ncsub(indexes[1:N])

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


_normalizeindex(n,ind::Colon) = 1:1:n
_normalizeindex(n,ind::Int) = ind:1:ind
_normalizeindex(n,ind::UnitRange) = StepRange(ind)
_normalizeindex(n,ind::StepRange) = ind
_normalizeindex(n,ind) = error("unsupported index")

_dropindex(ind::Int) = 1
_dropindex(ind) = Colon()

# indexes can be longer than sz
function normalizeindexes(sz,indexes)
    return ntuple(i -> _normalizeindex(sz[i],indexes[i]), length(sz))
end

function Base.getindex(v::Variable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    #    @show "any",indexes
    ind = normalizeindexes(size(v),indexes)
    drop_index = _dropindex.(indexes)
    # drop any dimension which was indexed with a scalar
    # TODO: avoid copy
    data = v[ind...][drop_index...]
    return data
end


function Base.setindex!(v::Variable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    #@show "any",indexes
    ind = normalizeindexes(size(v),indexes)

    # make arrays out of scalars
    if ndims(data) == 0
        data = fill(data,length.(ind))
    end

    if ndims(data) == 1 && size(data,1) == 1
        data = fill(data[1],length.(i))
    end

    # return data
    return v[ind...] = data
end

############################################################
# CFVariable
############################################################

fillmode(v::CFVariable) = fillmode(v.var)

fillvalue(v::CFVariable) = v._storage_attrib.fillvalue
scale_factor(v::CFVariable) = v._storage_attrib.scale_factor
add_offset(v::CFVariable) = v._storage_attrib.add_offset
time_origin(v::CFVariable) = v._storage_attrib.time_origin
""""
    tf = time_factor(v::CFVariable)

Time unit in milliseconds. E.g. seconds would be 1000., days would be 86400000.
"""
time_factor(v::CFVariable) = v._storage_attrib.time_factor


# fillvaue can be NaN (unfortunately)
@inline isfillvalue(data,fillvalue) = data .== fillvalue
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


@inline function CFinvtransform(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DTcast)
    #    return asdate(CFtransform_offset(CFtransform_scale(CFtransform_missing(data,fv),scale_factor),add_offset),time_origin,time_factor,DTcast)
    return CFtransform_replace_missing(CFtransform_scale(CFtransform_offset(data,minus_offset),inv_scale_factor),fv)
end


@inline CFtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) =
    # in boardcasting we trust...
    CFtransform.(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)

# this function is necessary to avoid "iterating" over a single character in Julia 1.0 (fixed Julia 1.3)
# https://discourse.julialang.org/t/broadcasting-and-single-characters/16836
@inline CFtransformdata(data::Char,fv,scale_factor,add_offset,time_origin,time_factor,DTcast) = data


@inline _inv(x::Nothing) = nothing
@inline _inv(x) = 1/x
@inline _minus(x::Nothing) = nothing
@inline _minus(x) = -x

@inline function CFinvtransformdata(data,fv,scale_factor,add_offset,time_origin,time_factor,DTcast)
    inv_scale_factor = _inv(scale_factor)
    minus_offset = _minus(add_offset)
    inv_time_factor = _inv(time_factor)
    return CFinvtransform.(data,fv,inv_scale_factor,minus_offset,time_origin,inv_time_factor,DTcast)
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
        if !("calendar" in attnames)
            # these dates cannot be converted to the standard calendar
            if T <: Union{DateTime360Day,Missing}
                v.attrib["calendar"] = "360_day"
            elseif T <: Union{DateTimeNoLeap,Missing}
                v.attrib["calendar"] = "365_day"
            elseif T <: Union{DateTimeAllLeap,Missing}
                v.attrib["calendar"] = "366_day"
            end
        end
        calendar = lowercase(get(v.attrib,"calendar","standard"))
        # can throw an convertion error if calendar attribute already exists and
        # is incompatible with the provided data
        v[indexes...] = timeencode(data,units,calendar)
        return data
    end

    throw(NetCDFError(-1, "time unit ('$units') of the variable $(name(v)) does not include the word ' since '"))
end


function Base.setindex!(v::CFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    tmp = CFinvtransformdata(
        data,fillvalue(v),scale_factor(v),add_offset(v),
        time_origin(v),time_factor(v),eltype(v))

    v.var[indexes...] = tmp
    return data
end

############################################################
# Convertion to array
############################################################
Base.Array(v::Union{CFVariable,Variable}) = v[:]
