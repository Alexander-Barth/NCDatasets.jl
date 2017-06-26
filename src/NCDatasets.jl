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
NetCDFError(code::Cint) = NetCDFError(code, unsafe_string(nc_strerror(code)))

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
                    NC_INT    => Int32,
                    NC_INT64  => Int64,
                    NC_FLOAT  => Float32,
                    NC_DOUBLE => Float64,
                    NC_CHAR   => Char,
                    NC_STRING => String)

# Inverse mapping
const ncType = Dict(value => key for (key, value) in jlType)


"""
Define the dimension with the name NAME and the length LEN in the
dataset NCID.  The id of the dimension is returned
"""

function defDim(ncid,name,len)
    dimidp = Vector{Cint}(1)
    nc_def_dim(ncid,name,len,dimidp)
    return dimidp[1]
end


function inqDim(ncid,dimid)
    cname = zeros(UInt8,NC_MAX_NAME+1)
    nc_inq_dimname(ncid,dimid,cname)
    name = unsafe_string(pointer(cname))
    
    return name
end

"""Return the id of a NetCDF dimension."""
function inqDimID(ncid,dimname)
    dimidp = Vector{Cint}(1)
    nc_inq_dimid(ncid,dimname,dimidp)
    return dimidp[1]
end



function defVar(ncid::Cint,name::String,vtype,dimids::Vector{Cint})
    varidp = Vector{Cint}(1)
    nc_def_var(ncid,name,ncType[vtype],length(dimids),dimids,varidp)
    return varidp[1]    
end

function inqVarIDs(ncid)
    # first get number of variables
    nvarsp = zeros(Int,1)    
    nc_inq_varids(ncid,nvarsp,C_NULL)
    nvars = nvarsp[1]

    varids = zeros(Cint,nvars)
    nc_inq_varids(ncid,nvarsp,varids)
    return varids    
end

function inqVar(ncid,varid)
    cname = zeros(UInt8,NC_MAX_NAME+1)
    nc_inq_varname(ncid,varid,cname)
    name = unsafe_string(pointer(cname))

    ndimsp = zeros(Int,1)
    nc_inq_varndims(ncid,varid,ndimsp)
    ndims = ndimsp[1]

    dimids = zeros(Cint,ndims)
    nc_inq_vardimid(ncid,varid,dimids)

    xtypep = zeros(nc_type,1)
    nc_inq_vartype(ncid,varid,xtypep)
    nctype = jlType[xtypep[1]]

    nattsp = Vector{Cint}(1)
    nc_inq_varnatts(ncid,varid,nattsp)
    nattr = nattsp[1]

    return name,nctype,dimids,nattr
end

function listVar(ncid)
    varids = inqVarIDs(ncid)
    names = Vector{String}(length(varids))

    for i = 1:length(varids)
        names[i],nctype,dimids,nattr = inqVar(ncid,varids[i])
    end
    return names
end

function listAtt(ncid,varid)
    nattsp = Vector{Cint}(1)
    nc_inq_varnatts(ncid,varid,nattsp)
    natts = nattsp[1]

    cname = zeros(UInt8,NC_MAX_NAME+1)
    names = Vector{String}(natts)
    
    for attnum = 0:natts-1
        nc_inq_attname(ncid,varid,attnum,cname)
        cname[end]=0
        names[attnum+1] = unsafe_string(pointer(cname))
    end

    return names
end


function getAtt(ncid,varid,name)
    xtypep = zeros(nc_type,1)
    lenp = zeros(Csize_t,1)

    nc_inq_att(ncid,varid,name,xtypep,lenp)
    xtype = xtypep[1]
    len = lenp[1]

    if xtype == NC_CHAR
        val = Vector{UInt8}(len)
        nc_get_att(ncid,varid,name,val)
        return unsafe_string(pointer(val))
    else
        val = Vector{jlType[xtype]}(len)
        nc_get_att(ncid,varid,name,val)

        if len == 1
            return val[1]
        else
            return val
        end
    end
end    

function putAtt!(ncid,varid,name,data)
    # NetCDF does not support 64 bit attributes
    if eltype(data) == Int64
        if ndims(data) == 0
            data = Int32(data)
        else
            data = [Int32(elem) for elem in data]
        end
    end

    if isa(data,String)
        cstr = Vector{UInt8}(data)
        nc_put_att(ncid,varid,name,ncType[eltype(data)],length(cstr),cstr)
    elseif ndims(data) == 0
        nctype = ncType[typeof(data)]
        nc_put_att(ncid,varid,name,ncType[typeof(data)],1,[data])
    elseif ndims(data) == 1
        nc_put_att(ncid,varid,name,ncType[eltype(data)],length(data),data)
    else
        error("attributes can only be scalars or vectors")
    end
end

function datamode(ncid,isdefmode::Vector{Bool})
    if isdefmode[1]
        nc_enddef(ncid)
        isdefmode[1] = false
    end
end

function defmode(ncid,isdefmode::Vector{Bool})
    if !isdefmode[1]
        nc_redef(ncid)
        isdefmode[1] = true
    end
end

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
    @show data
    return [Dates.value(dt - t0) / plength for dt in data ]
end

# -----------------------------------------------------
# List of attributes
# all ids should be Cint


type Attributes
    ncid::Cint
    varid::Cint
    isdefmode::Vector{Bool}
end

function Base.display(a::Attributes; indent = "  ")
    # use the same order of attributes than in the NetCDF file

    for (attname,attval) in a
        print(indent,@sprintf("%-20s = ",attname))
        print_with_color(:blue, @sprintf("%s",attval))
        print("\n")
    end
end

function Base.getindex(a::Attributes,name::AbstractString)
    return getAtt(a.ncid,a.varid,name)
end

function Base.setindex!(a::Attributes,data,name::AbstractString)
    defmode(a.ncid,a.isdefmode) # make sure that the file is in define mode
    return putAtt!(a.ncid,a.varid,name,data)
end

Base.in(name::AbstractString,a::Attributes) = name in listAtt(a.ncid,a.varid)
Base.keys(a::Attributes) = listAtt(a.ncid,a.varid)
# for iteration as a Dict
Base.start(a::Attributes) = listAtt(a.ncid,a.varid)
Base.done(a::Attributes,state) = length(state) == 0
Base.next(a::Attributes,state) = (state[1] => a[shift!(state)], state)

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

function Dataset(filename::AbstractString,mode::AbstractString = "r")
    ncidp = Vector{Cint}(1)

    if mode == "r"
        mode = NC_NOWRITE
        status = nc_open(filename,mode,ncidp)
    elseif mode == "c"
        mode  = NC_CLOBBER
        nc_create(filename,mode,ncidp)       
    end
    ncid = ncidp[1]
    isdefmode = [true]

    attrib = Attributes(ncid,NC_GLOBAL,isdefmode)
    return Dataset(filename,ncid,isdefmode,attrib)
end

function Dataset(f::Function,args...)
    ds = Dataset(args...)
    f(ds)
    close(ds)
end

defDim(ds::Dataset,name,len) = defDim(ds.ncid,name,len)

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
    dimids = Cint[inqDimID(ds.ncid,dimname) for dimname in dimnames[end:-1:1]]
    varid = defVar(ds.ncid,name,vtype,dimids)
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
    varidp = zeros(Cint,1)
    nc_inq_varid(ds.ncid,varname,varidp)
    varid = varidp[1]
    
    name,nctype,dimids,nattr = inqVar(ds.ncid,varid)

    ndims = length(dimids)
    #@show ndims
    lengthp = zeros(Csize_t,1)
    shape = zeros(Int,ndims)
    
    for i = 1:ndims
        nc_inq_dimlen(ds.ncid,dimids[i],lengthp)
        shape[ndims-i+1] = lengthp[1]
    end

    attrib = Attributes(ds.ncid,varid,ds.isdefmode)
    
    return Variable{nctype,ndims}(ds.ncid,varid,(shape...),attrib,ds.isdefmode)
end

function Base.display(ds::Dataset)
    print_with_color(:red, "Dataset: ",ds.filename,"\n")
    print("\n")
    print_with_color(:red, "Global attributes\n")

    for name in keys(ds)
        display(variable(ds,name))
        print("\n")
    end

    print_with_color(:red, "Variables\n")
    display(ds.attrib; indent = "  ")
end

function Base.getindex(ds::Dataset,varname::String)
    v = variable(ds,varname)
    fillvalue = zero(eltype(v))
    add_offset = 0
    scale_factor = 1

    attrib = Attributes(v.ncid,v.varid,ds.isdefmode)
    attnames = keys(attrib)

    has_fillvalue = "_FillValue" in attnames
    if has_fillvalue        
        fillvalue = attrib["_FillValue"]
    end

    has_add_offset = "add_offset" in attnames
    if has_add_offset        
        add_offset = attrib["add_offset"]
    end

    has_scale_factor = "scale_factor" in attnames
    if has_scale_factor        
        scale_factor = attrib["scale_factor"]
    end

    # return element type of any index operation
    
    if eltype(v) == Char
        rettype = Char
    else        
        rettype = Float64
    end

    return CFVariable{eltype(v),rettype,ndims(v)}(v,attrib,has_fillvalue,has_add_offset,
                                                  has_scale_factor,fillvalue,
                                                  add_offset,scale_factor)
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

function Base.display(v::Variable)
    name,nctype,dimids,nattr = inqVar(v.ncid,v.varid)
    delim = " × "

    print_with_color(:green, name)
    if length(v.shape) > 0
        print("  (",join(v.shape,delim),")\n")
        print("  Datatype:    ",eltype(v),"\n")
        dimnames = [inqDim(v.ncid,dimid) for dimid in dimids[end:-1:1]]
        print("  Dimensions:  ",join(dimnames,delim),"\n")
    else
        print("\n")
    end
    print("  Attributes:\n")

    display(v.attrib; indent = "     ")
end



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

function Base.setindex!{T,N}(v::Variable{T,N},data,indexes::Colon...)
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    nc_put_var(v.ncid,v.varid,data)
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
    #    @show "sr",indexes
    start,count,stride,jlshape = ncsub(indexes)    
    data = Array{T,N}(jlshape)
    nc_get_vars(v.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!{T,N}(v::Variable{T,N},data,indexes::StepRange{Int,Int}...)
    #    @show "sr",indexes
    datamode(v.ncid,v.isdefmode) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes)    
    nc_put_vars(v.ncid,v.varid,start,count,stride,data)
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
            @show indT
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
    #    @show "any",indexes
    ind,squeezedim = normalizeindexes(size(v),indexes)

    # return data
    return v[ind...] = data
end


# -----------------------------------------------------
# Variable (with applied transformation following the CF convention)


type CFVariable{NetCDFType,T,N}  <: AbstractArray{Float64, N}
    var::Variable{NetCDFType,N}
    attrib::Attributes
    has_fillvalue::Bool
    has_add_offset::Bool
    has_scale_factor::Bool

    fillvalue::NetCDFType
    add_offset
    scale_factor
end

Base.size(v::CFVariable) = size(v.var)

function Base.getindex(v::CFVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    data = v.var[indexes...]
    isscalar = ndims(data) == 0
    if isscalar
        data = [data]
    end

    if v.has_fillvalue
        mask = data .== v.fillvalue
    else
        mask = falses(data)
    end

    # do not scale characters and strings
    if eltype(v.var) != Char
        if v.has_scale_factor
            data = v.scale_factor * data
        end

        if v.has_add_offset
            data = data + v.add_offset
        end
    end

    if "units" in v.attrib
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

    # update fillvalue, add_offset, scale_factor,...

    #x = Array{eltype(data),ndims(data)}(size(data))
    x = zeros(eltype(v.var),size(data))
    @show typeof(data)
    @show eltype(v.var)

    if isa(data,DataArray)
        x[.!isna.(data)] = data[.!isna.(data)]
        mask = isna.(data)
    else
        if ndims(x) == 0
            # for scalars
            x = [data]
            mask = [false]
        else
            x = copy(data)
            mask = falses(data)
        end
    end

    if "units" in v.attrib
        units = v.attrib["units"]
        if contains(units," since ")
            x = timeencode(x,units)
        end
    end

    if v.has_fillvalue
        x[mask] = v.fillvalue
    else        
        # should we issue a warning?
    end

    # do not scale characters and strings
    if eltype(v.var) != Char
        if v.has_add_offset
            x[!mask] = x[!mask] - v.add_offset
        end

        if v.has_scale_factor
            x[!mask] = x[!mask] / v.scale_factor
        end

    end


    v.var[indexes...] = x
    return data
end


function Base.display(v::CFVariable)
    display(v.var)
end


export defVar, defDim, Dataset, close, sync

end # module
