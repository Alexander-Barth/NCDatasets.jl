module CatArrays

if VERSION >= v"0.7"
else
    using Compat
    using Compat: dropdims, findall, @debug
end
using Base

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

    return CatArray{eltype(arrays[1]),nd,na,typeof(arrays[1])}(
                    dim,
                    arrays,
                    asize,
                    start,
                    (sz...,))

end


function normalizeindexes(sz,indexes)
    ndims = length(sz)
    ind = Vector{StepRange}(undef,ndims)
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
            error("$indT: unsupported index")
        end
    end

    return (ind...,),squeezedim
end

#function Base.getindex(CA::CatArray{T,N},idx::Numbers...) where {T,N}


function Base.getindex(CA::CatArray{T,N},idx...) where {T,N}
    checkbounds(CA,idx...)

    ind,squeezedim = normalizeindexes(size(CA),idx)

    idx_global,idx_local,sz = idx_global_local_(CA,ind)

    B = Array{T,length(sz)}(undef,sz...)

    for j=1:length(CA.arrays)
        if prod(length.(idx_local[j])) > 0
            # get subset from j-th array
            subset = CA.arrays[j][idx_local[j]...]

            B[idx_global[j]...] = subset
        end
    end


    if all(squeezedim)
        # return just a scalar
        return B[1]
    elseif any(squeezedim)
        return dropdims(B,dims = (findall(squeezedim)...,))
    else
        return B
    end
end

Base.size(CA::CatArray) = CA.sz

function idx_global_local_(CA::CatArray,idx::NTuple{N}) where N

    n = length(size(CA))

    # number of indices must be equal to dimension
    @assert(length(idx) == n)

    lb = ones(Int,1,n) # lower bound
    ub = ones(Int,1,n) # upper bound

    # transform all colons to index range
    for i=1:n
        if (idx[i] == :)
            idx[i] = 1:CA.sz[i]
        end

        lb[i] = minimum(idx[i])
        ub[i] = maximum(idx[i])
    end

    sz = ntuple(i -> length(idx[i]),Val(N))

    idx_local  = Vector{NTuple{N,StepRange{Int,Int}}}(undef,length(CA.arrays))
    idx_global = Vector{NTuple{N,StepRange{Int,Int}}}(undef,length(CA.arrays))

    # loop over all arrays
    for j = 1:length(CA.arrays)
        idx_local_tmp = Vector{StepRange{Int,Int}}(undef,n)
        idx_global_tmp = Vector{StepRange{Int,Int}}(undef,n)

        # loop over all dimensions
        for i=1:n
            # rebase subscribt at CA.start[j,i]
            tmp =
                @static if VERSION >= v"0.7"
                    idx[i] .- (CA.start[j,i] - 1)
                else
                    idx[i] - (CA.start[j,i] - 1)
                end

            # only indeces within bounds of the j-th array
            sel = (1 .<= tmp) .& (tmp .<= CA.asize[j,i])

            if sum(sel) == 0
                idx_local_tmp[i] = 1:0
                idx_global_tmp[i] = 1:0
            else
                # index for getting the data from the local j-th array
                idx_local_tmp[i] = tmp[findfirst(sel):findlast(sel)]
                idx_global_tmp[i] =
                    @static if VERSION >= v"0.7"
                        (1:sum(sel)) .+ (findfirst(sel) - 1)
                    else
                        (1:sum(sel)) + (findfirst(sel) - 1)
                    end
            end
        end

        idx_local[j] = (idx_local_tmp...,)
        idx_global[j] = (idx_global_tmp...,)
    end

    return idx_global,idx_local,sz

end


function Base.setindex!(CA::CatArray{T,N},data,idx...) where {T,N}
    ind,squeezedim = normalizeindexes(size(CA),idx)
    idx_global,idx_local,sz = idx_global_local_(CA,ind);
    @debug ind,idx_global,idx_local,sz

    data2 = reshape(data,sz)
    for j = 1:length(CA.arrays)
        # get subset from global array x
        subset = @view data2[idx_global[j]...]

        @debug idx_local[j]

        # set subset in j-th array
        CA.arrays[j][idx_local[j]...] = subset;
    end

    return data
end

export CatArray
end
