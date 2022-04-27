module CatArrays
using Base
import NCDatasets

mutable struct CatArray{T,N,M,TA} <: AbstractArray{T,N} where TA <: AbstractArray
    # dimension over which the sub-arrays are concatenated
    dim::Int
    # tuple of all sub-arrays
    arrays::NTuple{M,TA}
    # size of all subarrays
    asize::Array{Int,2}
    # start indices of every subarrays in the combined array
    start::Array{Int,2}
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
                    asize,
                    start,
                    (sz...,))

end


function Base.getindex(CA::CatArray{T,N},idx...) where {T,N}
    checkbounds(CA,idx...)

    idx_global,idx_local,sz = idx_global_local_(CA,idx)
    B = Array{T,length(sz)}(undef,sz...)

    for j=1:length(CA.arrays)
        if prod(length.(idx_local[j])) > 0
            # get subset from j-th array
            subset = CA.arrays[j][idx_local[j]...]

            B[idx_global[j]...] = subset
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


function global_local_index(start,len,idx::Colon)
    idx_global_tmp = start:(start+len-1)
    idx_local_tmp = 1:len

#    @show idx_global_tmp,idx_local_tmp
    return idx_global_tmp,idx_local_tmp
end


function global_local_index(start,len,idx::AbstractRange)
    # rebase subscribt
    tmp = idx .- (start - 1)

    # only indeces within bounds of the j-th array
    sel = (1 .<= tmp) .& (tmp .<= len)

    if sum(sel) == 0
        idx_local_tmp = 1:0
        idx_global_tmp = 1:0
    else
        # index for getting the data from the local array
        idx_local_tmp = tmp[findfirst(sel):findlast(sel)]
        idx_global_tmp = (1:sum(sel)) .+ (findfirst(sel) - 1)
    end

    return idx_global_tmp,idx_local_tmp
end


function global_local_index(start,len,idx::Integer)
    # rebase subscribt
    tmp = idx - (start - 1)

    # only indeces within bounds of the j-th array
    if  (1 <= tmp <= len)
        idx_local_tmp = tmp
        idx_global_tmp = nothing
    else
        idx_local_tmp = 1:0
        idx_global_tmp = 1:0
    end
    #@show idx_global_tmp,idx_local_tmp

    return idx_global_tmp,idx_local_tmp
end

function gli(start,sz,idx)
    n = length(sz)

    idx_local_tmp = Vector{Any}(undef,n)
    idx_global_tmp = Vector{Any}(undef,n)

        # loop over all dimensions
        for i=1:n

            idx_global_tmp[i],idx_local_tmp[i] = global_local_index(
                start[i],
                sz[i],
                idx[i])
        end

    return filter(!isnothing,(idx_global_tmp...,)),(idx_local_tmp...,)
end



function idx_global_local_(CA::CatArray,idx)
    N = ndims(CA)
    n = ndims(CA)

    # number of indices must be equal to dimension
    @assert(length(idx) == n)


    #sz = ntuple(i -> length(idx[i]),Val(N))
    sz = NCDatasets._shape_after_slice(size(CA),idx...)

    #idx_local  = Vector{NTuple{N,StepRange{Int,Int}}}(undef,length(CA.arrays))
    #idx_global = Vector{NTuple{N,StepRange{Int,Int}}}(undef,length(CA.arrays))
    idx_local  = Vector{Any}(undef,length(CA.arrays))
    idx_global = Vector{Any}(undef,length(CA.arrays))

    # loop over all arrays
    for j = 1:length(CA.arrays)
        idx_global[j],idx_local[j] = gli((CA.start[j,:]...,),
                                         (CA.asize[j,:]...,),idx)
    end

    #@show idx_global,idx_local,sz
    return idx_global,idx_local,sz

end

function Base.setindex!(CA::CatArray{T,N},data,idx...) where {T,N}
    idx_global,idx_local,sz = idx_global_local_(CA,idx);
    @debug ind,idx_global,idx_local,sz

    for j = 1:length(CA.arrays)
        # get subset from global array x
        subset = @view data[idx_global[j]...]

        @debug idx_local[j]

        # set subset in j-th array
        CA.arrays[j][idx_local[j]...] = subset;
    end

    return data
end

# load all the data at once
Base.Array(CA::CatArray{T,N}) where {T,N}  = CA[ntuple(i -> :, Val(N))...]

export CatArray
end
