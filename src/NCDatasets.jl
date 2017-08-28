module NCDatasets
using Base
using Base.Test
#using NullableArrays
using DataArrays

# NetCDFError, error check and netcdf_c.jl from NetCDF.jl (https://github.com/JuliaGeo/NetCDF.jl)
# Copyright (c) 2012-2013: Fabian Gans, Max-Planck-Institut fuer Biogeochemie, Jena, Germany
# MIT

"Exception type for error thrown by the NetCDF library"
type NetCDFError <: Exception
    code::Cint
    msg::String
end

"Construct a NetCDFError from the error code"
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
function listVar(ncid)
    varids = nc_inq_varids(ncid)
    names = Vector{String}(length(varids))

    for i = 1:length(varids)
        names[i] = nc_inq_varname(ncid,varids[i])
    end

    return names
end

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

"Parse time units and returns the start time and the scaling factor relative to milliseconds"
function timeunits(units)
    tunit,starttime = strip.(split(units," since "))
    tunit = lowercase(tunit)

    t0 = DateTime(starttime,"y-m-d H:M:S")

    plength = if (tunit == "days") || (tunit == "day")
        24*60*60*1000
    elseif (tunit == "hours") || (tunit == "hour")
        60*60*1000
    elseif (tunit == "minutes") || (tunit == "minute")
        60*1000
    elseif (tunit == "seconds") || (tunit == "second")
        1000
    end

    return t0,plength
end

function timedecode(data,units)
    t0,plength = timeunits(units)
    return [t0 + Dates.Millisecond(round(Int,plength * data[n])) for n = 1:length(data)]
end

function timeencode(data,units)
    t0,plength = timeunits(units)
    #@show data
    return [Dates.value(dt - t0) / plength for dt in data ]
end

# -----------------------------------------------------
# base type of attribytes list
# concrete types are Attributes (single NetCDF file) and MFAttributes (multiple NetCDF files)

abstract type BaseAttributes
end

function Base.show(io::IO,a::BaseAttributes; indent = "  ")
    # use the same order of attributes than in the NetCDF file

    for (attname,attval) in a
        print(io,indent,@sprintf("%-20s = ",attname))
        print_with_color(:blue, io, @sprintf("%s",attval))
        print(io,"\n")
    end
end

Base.in(name::AbstractString,a::BaseAttributes) = name in keys(a)
# for iteration as a Dict
Base.start(a::BaseAttributes) = keys(a)
Base.done(a::BaseAttributes,state) = length(state) == 0
Base.next(a::BaseAttributes,state) = (state[1] => a[shift!(state)], state)


# -----------------------------------------------------
# List of attributes (for a single NetCDF file)
# all ids should be Cint

type Attributes <: BaseAttributes
    ncid::Cint
    varid::Cint
    isdefmode::Vector{Bool}
end

function Base.getindex(a::Attributes,name::AbstractString)
    return nc_get_att(a.ncid,a.varid,name)
end

function Base.setindex!(a::Attributes,data,name::AbstractString)
    defmode(a.ncid,a.isdefmode) # make sure that the file is in define mode
    return nc_put_att(a.ncid,a.varid,name,data)
end

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

# -----------------------------------------------------
# Dataset

type Dataset
    filename::String
    ncid::Cint
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be an array, so that it is copied by reference
    isdefmode::Vector{Bool}
    attrib::Attributes
end

"""
Create (mode = "c") or open in read-only (mode = "r") a NetCDF file (or an OPeNDAP URL).
"""

function Dataset(filename::AbstractString,mode::AbstractString = "r", format::AbstractString = "netcdf4")
    ncid = -1

    if mode == "r"
        mode = NC_NOWRITE
        ncid = nc_open(filename,mode)
    elseif mode == "c"
        mode  = NC_CLOBBER

        if format == "64bit"
            mode = mode | NC_64BIT_OFFSET
        elseif format == "netcdf4_classic"
            mode = mode | NC_NETCDF4 | NC_CLASSIC_MODEL
        elseif  format == "netcdf4"
            mode = mode | NC_NETCDF4
        end

        ncid = nc_create(filename,mode)
    end
    isdefmode = [true]

    attrib = Attributes(ncid,NC_GLOBAL,isdefmode)
    return Dataset(filename,ncid,isdefmode,attrib)
end

function Dataset(f::Function,args...)
    ds = Dataset(args...)
    f(ds)
    close(ds)
end

defDim(ds::Dataset,name,len) = nc_def_dim(ds.ncid,name,len)

"""
Defines a variable with the name `name` in the dataset `ds`.  `vtype` can be
Julia types in the table below (with the corresponding NetCDF type).  The parameter `dimnames` is a tuple with the
names of the dimension.  For scalar this parameter is the empty tuple ().  The variable is returned.

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
"""

function defVar(ds::Dataset,name,vtype,dimnames)
    defmode(ds.ncid,ds.isdefmode) # make sure that the file is in define mode
    dimids = Cint[nc_inq_dimid(ds.ncid,dimname) for dimname in dimnames[end:-1:1]]
    varid = nc_def_var(ds.ncid,name,ncType[vtype],dimids)
    return ds[name]
end



Base.keys(ds::Dataset) = listVar(ds.ncid)
# for iteration as a Dict
Base.start(ds::Dataset) = listVar(ds.ncid)
Base.done(ds::Dataset,state) = length(state) == 0
Base.next(ds::Dataset,state) = (state[1] => ds[shift!(state)], state)


sync(ds::Dataset) = nc_sync(ds.ncid)
Base.close(ds::Dataset) = nc_close(ds.ncid)

function variable(ds::Dataset,varname::String)
    varid = nc_inq_varid(ds.ncid,varname)
    name,nctype,dimids,nattr = nc_inq_var(ds.ncid,varid)
    ndims = length(dimids)
    #@show ndims
    shape = zeros(Int,ndims)

    for i = 1:ndims
        shape[ndims-i+1] = nc_inq_dimlen(ds.ncid,dimids[i])
    end

    attrib = Attributes(ds.ncid,varid,ds.isdefmode)

    return Variable{nctype,ndims}(ds.ncid,varid,(shape...),attrib,ds.isdefmode)
end

function Base.show(io::IO,ds::Dataset)
    print_with_color(:red, io, "Dataset: ",ds.filename,"\n")
    print(io,"\n")
    print_with_color(:red, io, "Variables\n")

    for name in keys(ds)
        show(io,variable(ds,name))
        print(io,"\n")
    end

    print_with_color(:red, io, "Global attributes\n")
    show(io,ds.attrib; indent = "  ")
end

function Base.getindex(ds::Dataset,varname::String)
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

    if eltype(v) == Char
        rettype = Char
    else
        rettype = Float64
    end

    # return CFVariable{eltype(v),rettype,ndims(v)}(v,attrib,has_fillvalue,has_add_offset,
    #                                               has_scale_factor,fillvalue,
    #                                               add_offset,scale_factor)

    return CFVariable{eltype(v),rettype,ndims(v)}(v,attrib)
end



# -----------------------------------------------------
# Variable (as stored in NetCDF file)

type Variable{NetCDFType,N}  <: AbstractArray{NetCDFType, N}
    ncid::Cint
    varid::Cint
    shape::NTuple{N,Int64}
    attrib::Attributes
    isdefmode::Vector{Bool}
end

Base.size(v::Variable) = v.shape

"""
dimnames(v::Variable)
Return a tuple of the dimension names of the variable `v`.
"""
function dimnames(v::Variable)
    dimids = nc_inq_vardimid(v.ncid,v.varid)
    return ([nc_inq_dimname(v.ncid,dimid) for dimid in dimids[end:-1:1]]...)
end

name(v::Variable) = nc_inq_varname(v.ncid,v.varid)
    


function Base.getindex(v::Variable,indexes::Int...)
    #    @show "ind",indexes

    data = Vector{eltype(v)}(1)
    # use zero-based indexes
    nc_get_var1(v.ncid,v.varid,[i-1 for i in indexes[end:-1:1]],data)
    return data[1]
end

function Base.setindex!(v::Variable,data,indexes::Int...)
    datamode(v.ncid,v.isdefmode)
    # use zero-based indexes and reversed order
    nc_put_var1(v.ncid,v.varid,[i-1 for i in indexes[end:-1:1]],[data])
    return data
end

function Base.getindex{T,N}(v::Variable{T,N},indexes::Colon...)
    # special case for scalar NetCDF variable
    if N == 0
        data = Vector{T}(1)
        nc_get_var(v.ncid,v.varid,data)
        return data[1]
    else
        data = Array{T,N}(v.shape)
        nc_get_var(v.ncid,v.varid,data)
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
    nc_put_var(v.ncid,v.varid,data)
    return data
end

function Base.setindex!{T,T2,N}(v::Variable{T,N},data::Array{T2,N},indexes::Colon...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode

    tmp = convert(Array{T,N},data)
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
    start,count,stride,jlshape = ncsub(indexes)
    data = Array{T,N}(jlshape)
    nc_get_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::T,indexes::StepRange{Int,Int}...)
    #    @show "sr",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes)
    tmp = fill(data,jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Number,indexes::StepRange{Int,Int}...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes)
    tmp = fill(convert(T,data),jlshape)
    nc_put_vars(v.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Array{T,N},indexes::StepRange{Int,Int}...)
    #    @show "sr",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes)
    nc_put_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data::Array,indexes::StepRange{Int,Int}...)
    #@show "sr2",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes)

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

function Base.getindex(v::CFVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    attnames = keys(v.attrib)

    data = v.var[indexes...]
    isscalar = ndims(data) == 0
    if isscalar
        data = [data]
    end

    if "_FillValue" in attnames
        mask = data .== v.attrib["_FillValue"]
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
            data = timedecode(data,units)
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

    x = Array{eltype(data),ndims(data)}(size(data))
    #@show typeof(data)
    #@show eltype(v.var)

    attnames = keys(v.attrib)

    #@show "here",ndims(x),ndims(data)

    if isa(data,DataArray)
        mask = isna.(data)
        x[.!mask] = data[.!mask]
    else
        if ndims(data) == 0
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
            x = timeencode(x,units)
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

    if ndims(data) == 0
        v.var[indexes...] = x[1]
    else
        v.var[indexes...] = x
    end

    return data
end



function Base.show(io::IO,v::Union{Variable,CFVariable})
    delim = " × "
    sz = size(v)
    
    print_with_color(:green, io, name(v))
    if length(sz) > 0
        print(io,"  (",join(sz,delim),")\n")
        print(io,"  Datatype:    ",eltype(v),"\n")
        print(io,"  Dimensions:  ",join(dimnames(v),delim),"\n")
    else
        print(io,"\n")
    end
    print(io,"  Attributes:\n")

    show(io,v.attrib; indent = "     ")
end

Base.display(v::Union{Variable,CFVariable}) = show(STDOUT,v)

export defVar, defDim, Dataset, close, sync, variable, dimnames, name

end # module
