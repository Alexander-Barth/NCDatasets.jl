module CatArrays
using Base
import NCDatasets

mutable struct CatArray{T,N,M,TA} <: AbstractArray{T,N} where TA <: AbstractArray
    # dimension over which the sub-arrays are concatenated
    dim::Int
    # tuple of all sub-arrays
    arrays::NTuple{M,TA}
    # offset indices of every subarrays in the combined array
    # (0-based, i.e. 0 = no offset)
    offset::NTuple{M,NTuple{N,Int}}
    # size of the combined array
    sz::NTuple{N,Int}
end

"""
C = CatArray(dim,array1,array2,...)

Create a concatenated array view from a list of arrays. Individual
elements can be accessed by subscribs
"""
function CatArray(dim::Int,arrays...)
    na = length(arrays)

    # number of dimensions
    nd = ndims(arrays[1])
    if dim > nd
        nd = dim
    end

    asize = ones(Int,na,nd)
    start = ones(Int,na,nd)

    # get size of all arrays
    for i=1:na
        tmp = size(arrays[i])
        asize[i,1:length(tmp)] = [tmp...]
    end

    # check if dimensions are consistent
    ncd = 1:nd .!= dim

    for i=2:na
        if any(asize[i,ncd] .!= asize[1,ncd])
            error("Array number $i has inconsistent size")
        end
    end

    # start index of each sub-array

    for i=2:na
        start[i,:] = start[i-1,:]
        start[i,dim] = start[i,dim] + asize[i-1,dim]
    end

    offset = ntuple(i -> (start[i,:]...,) .- 1,na)

    sz = asize[1,:]
    sz[dim] = sum(asize[:,dim])

    TA = typeof(arrays[1])
    T = eltype(arrays[1])
    for i = 2:length(arrays)
        T = promote_type(T,eltype(arrays[i]))
        TA = promote_type(TA,typeof(arrays[i]))
    end

    return CatArray{T,nd,na,TA}(
                    dim,
                    arrays,
                    offset,
                    (sz...,))

end


function Base.getindex(CA::CatArray{T,N},idx...) where {T,N}
    checkbounds(CA,idx...)

    sz = NCDatasets._shape_after_slice(size(CA),idx...)
    idx_global_local = index_global_local(CA,idx)
    B = Array{T,length(sz)}(undef,sz...)

    for (array,(idx_global,idx_local)) in zip(CA.arrays,idx_global_local)
        if valid_local_idx(idx_local...)
            # get subset from j-th array
            subset = array[idx_local...]
            B[idx_global...] = subset
        end
    end

    if sz == ()
        # scalar
        return B[]
    else
        return B
    end
end

Base.size(CA::CatArray) = CA.sz


function valid_local_idx(local_idx::Integer,local_idx_rest...)
    return (local_idx > 0) && valid_local_idx(local_idx_rest...)
end

function valid_local_idx(local_idx::AbstractRange,local_idx_rest...)
    return (length(local_idx) > 0) && valid_local_idx(local_idx_rest...)
end

# stop condition
valid_local_idx() = true

function gli(offset,subarray,idx)
    idx_global_tmp,idx_local_tmp = _gli(offset,subarray,1,(),(),idx...)
    return idx_global_tmp,idx_local_tmp
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::Integer,idx_rest...)
    # rebase subscribt
    tmp = idx - offset[i]
    # only indeces within bounds of the j-th array
    if  !(1 <= tmp <= size(subarray,i))
        tmp = -1
    end

    # scalar indices are not part of idx_global
    return _gli(offset,subarray,i+1,idx_global,(idx_local...,tmp),idx_rest...)
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::Colon,idx_rest...)
    idx_global_tmp = offset[i] .+ (1:size(subarray,i))
    idx_local_tmp = 1:size(subarray,i)

    return _gli(offset,subarray,i+1,
                (idx_global...,idx_global_tmp),
                (idx_local..., idx_local_tmp),idx_rest...)
end


function _gli(offset,subarray,i,idx_global,idx_local,idx::AbstractRange,idx_rest...)
    # rebase subscribt
    tmp = idx .- offset[i]

    # only indeces within bounds of the j-th array
    sel = (1 .<= tmp) .& (tmp .<= size(subarray,i))

    if sum(sel) == 0
        idx_local_tmp = 1:0
        idx_global_tmp = 1:0
    else
        # index for getting the data from the local array
        idx_local_tmp = tmp[findfirst(sel):findlast(sel)]
        idx_global_tmp = (1:sum(sel)) .+ (findfirst(sel) - 1)
    end

    return _gli(offset,subarray,i+1,
                (idx_global...,idx_global_tmp),
                (idx_local..., idx_local_tmp),idx_rest...)
end


# stop condition
# all indices have been processed
_gli(offset,subarray,i,idx_global,idx_local) = (idx_global,idx_local)

function index_global_local(CA::CatArray{T,N,M,TA},idx) where {T,N,M,TA}
    # number of indices must be equal to dimension
    @assert(length(idx) == N)

    idx_global_local = ntuple(j -> gli(CA.offset[j],CA.arrays[j],idx),Val(M))

    return idx_global_local
end

function Base.setindex!(CA::CatArray{T,N},data,idx...) where {T,N}
    idx_global_local = index_global_local(CA,idx)
    @debug ind,idx_global,idx_local,sz

    for (array,(idx_global,idx_local)) in zip(CA.arrays,idx_global_local)
        if valid_local_idx(idx_local...)
            subset = @view data[idx_global...]
            @debug idx_local
            # set subset in j-th array
            array[idx_local...] = subset;
        end
    end

    return data
end

# load all the data at once
Base.Array(CA::CatArray{T,N}) where {T,N}  = CA[ntuple(i -> :, Val(N))...]

export CatArray
end
