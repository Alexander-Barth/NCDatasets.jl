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
    M = length(arrays)

    # number of dimensions
    N = ndims(arrays[1])
    if dim > N
        N = dim
    end

    # check if dimensions are consistent
    for i = 2:M
        for j = 1:N
            if j !== dim
                if size(arrays[i],j) !== size(arrays[1],j)
                    error("Array number $i has inconsistent size $(size(arrays[i]))")
                end
            end
        end
    end

    # offset of each sub-array
    countdim = 0
    offset = ntuple(M) do i
        off = ntuple(j -> (j == dim ? countdim : 0), N)
        countdim += size(arrays[i],dim)
        off
    end

    # size of concatenated array
    sz = ntuple(j -> (j == dim ? countdim : size(arrays[1],j)), N)

    TA = typeof(arrays[begin])
    T = eltype(arrays[begin])
    for i = (firstindex(arrays)+1):lastindex(arrays)
        T = promote_type(T,eltype(arrays[i]))
        TA = promote_type(TA,typeof(arrays[i]))
    end

    return CatArray{T,N,M,TA}(
        dim,
        arrays,
        offset,
        sz)
end


function Base.getindex(CA::CatArray{T,N},idx...) where {T,N}
    checkbounds(CA,idx...)

    sz = NCDatasets._shape_after_slice(size(CA),idx...)
    idx_global_local = index_global_local(CA,idx)
    B = Array{T,length(sz)}(undef,sz...)

    for (array,(idx_global,idx_local)) in zip(CA.arrays,idx_global_local)
        if valid_local_idx(idx_local...)
            # get subset from subarray
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

function valid_local_idx(local_idx::AbstractVector,local_idx_rest...)
    return (length(local_idx) > 0) && valid_local_idx(local_idx_rest...)
end

# stop condition
valid_local_idx() = true

# iterate thought all indices by peeling the first value of a tuple off
# which results in better type stability
function gli(offset,subarray,idx)
    idx_global_tmp,idx_local_tmp = _gli(offset,subarray,1,(),(),idx...)
    return idx_global_tmp,idx_local_tmp
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::Integer,idx_rest...)
    # rebase subscribt
    idx_offset = idx - offset[i]
    # only indeces within bounds of the subarray
    if  !(1 <= idx_offset <= size(subarray,i))
        idx_offset = -1
    end

    # scalar indices are not part of idx_global (as they are dropped)
    return _gli(offset,subarray,i+1,idx_global,(idx_local...,idx_offset),idx_rest...)
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::Colon,idx_rest...)
    idx_global_tmp = offset[i] .+ (1:size(subarray,i))
    idx_local_tmp = 1:size(subarray,i)

    return _gli(offset,subarray,i+1,
                (idx_global...,idx_global_tmp),
                (idx_local..., idx_local_tmp),idx_rest...)
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::AbstractRange,idx_rest...)
    # within bounds of the subarray
    within(j) = 1 <= j <= size(subarray,i)

    # rebase subscript
    idx_offset = idx .- offset[i]

    n_within = count(within,idx_offset)

    if n_within == 0
        idx_local_tmp = 1:0
        idx_global_tmp = 1:0
    else
        # index for getting the data from the local array
        idx_local_tmp = idx_offset[findfirst(within,idx_offset):findlast(within,idx_offset)]
        idx_global_tmp = (1:n_within) .+ (findfirst(within,idx_offset) - 1)
    end

    return _gli(offset,subarray,i+1,
                (idx_global...,idx_global_tmp),
                (idx_local..., idx_local_tmp),idx_rest...)
end

function _gli(offset,subarray,i,idx_global,idx_local,idx::Vector{T},idx_rest...) where T <: Integer
    # within bounds of the subarray
    within(j) = 1 <= j <= size(subarray,i)

    # rebase subscribt
    idx_offset = idx .- offset[i]

    # index for getting the data from the local array
    idx_local_tmp = filter(within,idx_offset)
    idx_global_tmp = filter(i -> within(idx_offset[i]),1:length(idx))

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
            # set subset in array
            array[idx_local...] = subset
        end
    end

    return data
end

# load all the data at once
Base.Array(CA::CatArray{T,N}) where {T,N}  = CA[ntuple(i -> :, Val(N))...]

export CatArray
end
