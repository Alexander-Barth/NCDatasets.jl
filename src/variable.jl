#=
Functionality and definitions
related with the `Variables` types/subtypes
=#

############################################################
# Types and subtypes
############################################################

abstract type AbstractVariable{T,N} <: AbstractDiskArray{T,N} end

# Variable (as stored in NetCDF file, without using
# add_offset, scale_factor and _FillValue)
mutable struct Variable{NetCDFType,N,TDS<:AbstractDataset} <: AbstractVariable{NetCDFType, N}
    ds::TDS
    varid::Cint
    dimids::NTuple{N,Cint}
    attrib::Attributes
end


############################################################
# Helper functions (internal)
############################################################
"Return all variable names"
listVar(ncid) = String[nc_inq_varname(ncid,varid)
                       for varid in nc_inq_varids(ncid)]


"""
    ds = NCDataset(var::CFVariable)
    ds = NCDataset(var::Variable)

Return the `NCDataset` containing the variable `var`.
"""
NCDataset(var::Variable) = var.ds

"""
    sz = size(var::Variable)

Return a tuple of integers with the size of the variable `var`.

!!! note

    Note that the size of a variable can change, i.e. for a variable with an
    unlimited dimension.
"""
Base.size(v::Variable{T,N}) where {T,N} = ntuple(i -> nc_inq_dimlen(v.ds.ncid,v.dimids[i]),Val(N))



function isresizable(v::Variable{T,N}) where {T,N}
    unlimdims = nc_inq_unlimdims(v.ds.ncid)
    return ntuple(l -> v.dimids[l] in unlimdims,Val(N))
end

"""
    renameVar(ds::NCDataset,oldname,newname)

Rename the variable called `oldname` to `newname`.
"""
function renameVar(ds::NCDataset,oldname::AbstractString,newname::AbstractString)
    # make sure that the file is in define mode
    defmode(ds)
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
function variable(ds::NCDataset,varname::SymbolOrString)
    varid = nc_inq_varid(ds.ncid,varname)
    name,nctype,dimids,nattr = nc_inq_var(ds.ncid,varid)
    ndims = length(dimids)
    shape = zeros(Int,ndims)

    for i = 1:ndims
        shape[ndims-i+1] = nc_inq_dimlen(ds.ncid,dimids[i])
    end

    attrib = Attributes(ds,varid)

    # reverse dimids to have the dimension order in Fortran style
    return Variable{nctype,ndims,NCDataset}(ds,varid,
                                  (reverse(dimids)...,),
                                  attrib)
end

export variable


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
    sizes =  size(ncvar)   
    normalizedindices = normalizeindexes(sizes, indices)
    ind = to_indices(ncvar,normalizedindices)
    
    start,count,stride,jlshape = ncsub(ind)
    nc_get_vars!(ncvar.ds.ncid,ncvar.varid,start,count,stride,data)
end

@inline function load!(ncvar::NCDatasets.Variable{T,2}, data, i::Colon,j::UnitRange) where T
    # reversed and 0-based
    start = [first(j)-1,0]
    count = [length(j),size(ncvar,1)]
    nc_get_vara!(ncvar.ds.ncid,ncvar.varid,start,count,data)
end


"""
     data = loadragged(ncvar,index::Colon)

Load data from `ncvar` in the [contiguous ragged array representation](https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_contiguous_ragged_array_representation) as a
vector of vectors. It is typically used to load a list of profiles
or time series of different length each.

The [indexed ragged array representation](https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#_indexed_ragged_array_representation) is currently not supported.
"""
function loadragged(ncvar,index::Colon)
    ds = NCDataset(ncvar)

    dimensionnames = dimnames(ncvar)
    if length(dimensionnames) !== 1
        throw(NetCDFError(-1, "NetCDF variable $(name(ncvar)) should have only one dimensions"))
    end
    dimname = dimensionnames[1]

    ncvarsizes = varbyattrib(ds,sample_dimension = dimname)
    if length(ncvarsizes) !== 1
        throw(NetCDFError(-1, "There should be exactly one NetCDF variable with the attribute 'sample_dimension' equal to '$(dimname)'"))
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
export loadragged



############################################################
# User API regarding Variables
############################################################
"""
    dimnames(v::Variable)

Return a tuple of strings with the dimension names of the variable `v`.
"""
function dimnames(v::Variable{T,N}) where {T,N}
    return ntuple(i -> nc_inq_dimname(v.ds.ncid,v.dimids[i]),Val(N))
end
export dimnames

"""
    name(v::Variable)

Return the name of the NetCDF variable `v`.
"""
name(v::Variable) = nc_inq_varname(v.ds.ncid,v.varid)
export name

chunking(v::Variable,storage,chunksizes) = nc_def_var_chunking(v.ds.ncid,v.varid,storage,reverse(chunksizes))

"""
    storage,chunksizes = chunking(v::Variable)

Return the storage type (`:contiguous` or `:chunked`) and the chunk sizes
of the varable `v`.
"""
function chunking(v::Variable)
    storage,chunksizes = nc_inq_var_chunking(v.ds.ncid,v.varid)
    return storage,reverse(chunksizes)
end
export chunking

"""
    isshuffled,isdeflated,deflate_level = deflate(v::Variable)

Return compression information of the variable `v`. If shuffle
is `true`, then shuffling (byte interlacing) is activated. If
deflate is `true`, then the data chunks (see `chunking`) are
compressed using the compression level `deflate_level`
(0 means no compression and 9 means maximum compression).
"""
deflate(v::Variable,shuffle,deflate,deflate_level) = nc_def_var_deflate(v.ds.ncid,v.varid,shuffle,deflate,deflate_level)
deflate(v::Variable) = nc_inq_var_deflate(v.ds.ncid,v.varid)
export deflate

checksum(v::Variable,checksummethod) = nc_def_var_fletcher32(v.ds.ncid,v.varid,checksummethod)

"""
   checksummethod = checksum(v::Variable)

Return the checksum method of the variable `v` which can be either
be `:fletcher32` or `:nochecksum`.
"""
checksum(v::Variable) = nc_inq_var_fletcher32(v.ds.ncid,v.varid)
export checksum

function fillmode(v::Variable)
    no_fill,fv = nc_inq_var_fill(v.ds.ncid, v.varid)
    return no_fill,fv
end
export fillmode

"""
    fv = fillvalue(v::Variable)
    fv = fillvalue(v::CFVariable)

Return the fill-value of the variable `v`.
"""
function fillvalue(v::Variable{NetCDFType,N}) where {NetCDFType,N}
    no_fill,fv = nc_inq_var_fill(v.ds.ncid, v.varid)
    return fv::NetCDFType
end
export fillvalue


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
export nomissing


# Implement the DiskArrays interface

function resizable_indices(v::Variable{T,N}) where {T,N}
    unlimdims = nc_inq_unlimdims(v.ds.ncid)
    return filter(l -> v.dimids[l] in unlimdims,ntuple(identity,Val(N)))
end


function readblock!(v::Variable, data, r::AbstractUnitRange...)
#    @show "read "
    start = [first(i)-1 for i in reverse(r)]
    count = [length(i) for i in reverse(r)]
    datamode(v.ds)
    nc_get_vara!(v.ds.ncid,v.varid,start,count,data)
end

function readblock!(v::Variable, data, r::StepRange...)
#    @show "read strided"
    start = [first(i)-1 for i in reverse(r)]
    stride = [step(i) for i in reverse(r)]
    count = [length(i) for i in reverse(r)]
    datamode(v.ds)
    nc_get_vars!(v.ds.ncid,v.varid,start,count,stride,data)
end

# for scalars
function readblock!(v::Variable, data)
    @show typeof(data)
    @show "read no index",size(data),data
    datamode(v.ds)
    nc_get_var!(v.ds.ncid,v.varid,data)
    @show typeof(data)
end

function writeblock!(v::Variable{T,N}, a, r::AbstractUnitRange...) where {T,N}
#    @show "write ",r,size(a),a
    start = [first(i)-1 for i in reverse(r)]
    count = [length(i) for i in reverse(r)]
    datamode(v.ds)
#    nc_put_vara(v.ds.ncid,v.varid,start,count,a)
    nc_put_vara(v.ds.ncid,v.varid,start,count,convert(Array{T,N},a))
end

function writeblock!(v::Variable{T,N}, a, r::StepRange...) where {T,N}
#    @show "write strided",r
    start = [first(i)-1 for i in reverse(r)]
    stride = [step(i) for i in reverse(r)]
    count = [length(i) for i in reverse(r)]
    datamode(v.ds)
#    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,a)
    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,convert(Array{T,N},a))
end

# for scalars
function writeblock!(v::Variable{T,N}, a) where {T,N}
#    @show "write ",size(a),a
    datamode(v.ds)
#    nc_put_var(v.ds.ncid,v.varid,a)
    nc_put_var(v.ds.ncid,v.varid,convert(Array{T,N},a))
end

getchunksize(v::Variable) = getchunksize(haschunks(v),v)
getchunksize(::DiskArrays.Chunked, v::Variable) = chunking(v)[2]
getchunksize(::DiskArrays.Unchunked, v::Variable) = estimate_chunksize(v)
eachchunk(v::Variable) = GridChunks(v, getchunksize(v))
haschunks(v::Variable) = (chunking(v)[1] == :contiguous ? DiskArrays.Unchunked() : DiskArrays.Chunked())


function read(v::Variable)
    data = Array{eltype(v)}(undef, size(v))
    readblock!(v, data)
    return data
end

#=

function Base.getindex(v::Variable,indexes::Int...)
    datamode(v.ds)
    return nc_get_var1(eltype(v),v.ds.ncid,v.varid,[i-1 for i in indexes[ndims(v):-1:1]])
end

function Base.setindex!(v::Variable{T,N},data,indexes::Int...) where N where T
    @debug "$(@__LINE__)"
    datamode(v.ds)
    # use zero-based indexes and reversed order
    nc_put_var1(v.ds.ncid,v.varid,[i-1 for i in indexes[ndims(v):-1:1]],T(data))
    return data
end

function Base.getindex(v::Variable{T,N},indexes::Colon...) where {T,N}
    datamode(v.ds)
    # special case for scalar NetCDF variable
    if N == 0
        data = Ref(zero(T))
        nc_get_var!(v.ds.ncid,v.varid,data)
        return data[]
    else
        data = Array{T,N}(undef,size(v))
        nc_get_var!(v.ds.ncid,v.varid,data)
        return data
    end
end

function Base.setindex!(v::Variable{T,N},data::T,indexes::Colon...) where {T,N}
    @debug "setindex! colon $data"
    datamode(v.ds) # make sure that the file is in data mode
    tmp = fill(data,size(v))

    nc_put_var(v.ds.ncid,v.varid,tmp)
    return data
end

# call to v .= 123
function Base.setindex!(v::Variable{T,N},data::Number) where {T,N}
    @debug "setindex! $data"
    datamode(v.ds) # make sure that the file is in data mode
    tmp = fill(convert(T,data),size(v))

    nc_put_var(v.ds.ncid,v.varid,tmp)
    return data
end

Base.setindex!(v::Variable,data::Number,indexes::Colon...) = setindex!(v::Variable,data)

function Base.setindex!(v::Variable{T,N},data::AbstractArray{T,N},indexes::Colon...) where {T,N}
    datamode(v.ds) # make sure that the file is in data mode

    nc_put_var(v.ds.ncid,v.varid,data)
    return data
end

function Base.setindex!(v::Variable{T,N},data::AbstractArray{T2,N},indexes::Colon...) where {T,T2,N}
    datamode(v.ds) # make sure that the file is in data mode
    tmp =
        if T <: Integer
            round.(T,data)
        else
            convert(Array{T,N},data)
        end

    nc_put_var(v.ds.ncid,v.varid,tmp)
    return data
end
=#

function ncsub(indexes::NTuple{N,T}) where N where T
    rindexes = reverse(indexes)
    count  = Int[length(i)  for i in rindexes]
    start  = Int[first(i)-1 for i in rindexes]     # use zero-based indexes
    stride = Int[step(i)    for i in rindexes]
    jlshape = length.(indexes)::NTuple{N,Int}
    return start,count,stride,jlshape
end

#=
function Base.getindex(v::Variable{T,N},indexes::TR...) where {T,N} where TR <: Union{StepRange{Int,Int},UnitRange{Int}}
    start,count,stride,jlshape = ncsub(indexes[1:N])
    data = Array{T,N}(undef,jlshape)

    datamode(v.ds)
    nc_get_vars!(v.ds.ncid,v.varid,start,count,stride,data)
    return data
end

function Base.setindex!(v::Variable{T,N},data::T,indexes::StepRange{Int,Int}...) where {T,N}
    datamode(v.ds) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(data,jlshape)
    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!(v::Variable{T,N},data::Number,indexes::StepRange{Int,Int}...) where {T,N}
    datamode(v.ds) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    tmp = fill(convert(T,data),jlshape)
    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,tmp)
    return data
end

function Base.setindex!(v::Variable{T,N},data::Array{T,N},indexes::StepRange{Int,Int}...) where {T,N}
    datamode(v.ds) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])
    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,data)
    return data
end

# data can be Array{T2,N} or BitArray{N}
function Base.setindex!(v::Variable{T,N},data::AbstractArray,indexes::StepRange{Int,Int}...) where {T,N}
    datamode(v.ds) # make sure that the file is in data mode
    start,count,stride,jlshape = ncsub(indexes[1:ndims(v)])

    tmp = convert(Array{T,ndims(data)},data)
    nc_put_vars(v.ds.ncid,v.varid,start,count,stride,tmp)

    return data
end
=#

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

#=
function Base.getindex(v::Variable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    ind = normalizeindexes(size(v),indexes)
    drop_index = _dropindex.(indexes)
    # drop any dimension which was indexed with a scalar
    # TODO: avoid copy
    data = v[ind...][drop_index...]
    return data
end

# NetCDF scalars indexed as []
Base.getindex(v::Variable{T, 0}) where T = v[1]



function Base.setindex!(v::Variable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    ind = normalizeindexes(size(v),indexes)

    # make arrays out of scalars
    if ndims(data) == 0
        data = fill(data,length.(ind))
    end

    return v[ind...] = data
end
=#

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
            rethrow()
        end
    sz = size(v)

    printstyled(io, indent, name(v),color=variable_color())
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
