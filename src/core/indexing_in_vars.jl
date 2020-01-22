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
fillvalue(v::CFVariable) = fillvalue(v.var)
scale_factor(v::CFVariable) = v.scale_factor
add_offset(v::CFVariable) = v.add_offset

# fv can be NaN
@inline function CFtransform_missing(data::AbstractFloat,fv::AbstractFloat)
    if !isnan(fv)
        return (data == fv ? missing : data)
    else
        return (isnan(data) ? missing : data)
    end
end
@inline CFtransform_missing(data,fv) = (data == fv ? missing : data)
@inline CFtransform_missing(data,fv::Nothing) = data

@inline CFtransform_scale(data,scale_factor) = data*scale_factor
@inline CFtransform_scale(data,scale_factor::Nothing) = data
@inline CFtransform_scale(data::T,scale_factor) where T <: Union{Char,String} = data
@inline CFtransform_scale(data::T,scale_factor::Nothing) where T <: Union{Char,String} = data

@inline CFtransform_offset(data,add_offset) = data + add_offset
@inline CFtransform_offset(data,add_offset::Nothing) = data
@inline CFtransform_offset(data::T,add_factor) where T <: Union{Char,String} = data
@inline CFtransform_offset(data::T,add_factor::Nothing) where T <: Union{Char,String} = data


@inline asdate(data::Missing,time_origin,plength,DTcast) = data
@inline asdate(data,time_origin::Nothing,plength,DTcast) = data
@inline asdate(data::Missing,time_origin::Nothing,plength,DTcast) = data
@inline asdate(data,time_origin,plength,DTcast) =
    convert(DTcast,time_origin + Dates.Millisecond(round(Int64,plength * data)))

@inline function CFtransform(data,fv,scale_factor,add_offset,time_origin,plength,DTcast)
    return asdate(CFtransform_offset(CFtransform_scale(CFtransform_missing(data,fv),scale_factor),add_offset),time_origin,plength,DTcast)
    #return CFtransform_offset(CFtransform_scale(CFtransform_missing(data,fv),scale_factor),add_offset)
end

function Base.getindex(v::CFVariable,
                       indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    attnames = keys(v.attrib)

    data = v.var[indexes...]
#    @show data
#    @show CFtransform_missing.(data,v.fillvalue)
    time_origin,plength = v.time_units
    DTcast = eltype(v)
    return CFtransform.(data,v.fillvalue,v.scale_factor,v.add_offset,time_origin,plength,DTcast)
#=
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
        mask = isfillvalue(data,fillvalue)
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
            calendar = lowercase(get(v.attrib,"calendar","standard"))
            # time decode only valid dates
            tmp = timedecode(data[.!mask],units,calendar)
            data = similar(tmp,size(data))
            data[.!mask] = tmp
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
=#
end

function Base.setindex!(v::CFVariable,data::Array{Missing,N},indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) where N
    v.var[indexes...] = fill(v.attrib["_FillValue"],size(data))
end

function Base.setindex!(v::CFVariable,data::Missing,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    v.var[indexes...] = v.attrib["_FillValue"]
end


isfillvalue(data,fillvalue) = data .== fillvalue
isfillvalue(data,fillvalue::Number) = (isnan(fillvalue) ? isnan.(data) : data .== fillvalue)

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

############################################################
# Convertion to array
############################################################
Base.Array(v::Union{CFVariable,Variable}) = v[:]
