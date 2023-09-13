
# tuple peeling for type-stability
_good_chunk_size(chunk_i) = ()

function _good_chunk_size(chunk_i,sz_i,sz...)
    if chunk_i == 0
        chunk_size_i = 1
    elseif sz_i >= chunk_i
        chunk_size_i = chunk_i
    else
        chunk_size_i = sz_i # take them all
    end

    chunk_i = chunk_i ÷ sz_i

    return (chunk_size_i, _good_chunk_size(chunk_i,sz...)...)
end

"""
    chunk_size = good_chunk_size(sz,chunk_max_length)
    chunk_size = good_chunk_size(array::AbstractArray,chunk_max_length)

Return a tuple of indices representing a subset size (chunk) of an array with size
`sz` (assuming column-major storage order). The number of elements in this chunk is not
larger than `chunk_max_length`.

If the `array` is provided, then `chunk_size` takes the storage order into
account.
"""
good_chunk_size(sz,chunk_max_length) = _good_chunk_size(chunk_max_length,sz...)



function good_chunk_size(array::AbstractArray{T,N},chunk_max_length) where {T,N}
    dim_permute = sortperm(collect(strides(array)))
    dim_inv_permute = invperm(dim_permute)
    good_chunk_size(size(array)[dim_permute],chunk_max_length)[dim_inv_permute] :: NTuple{N,Int}
end



function each_chunk_index(ax::NTuple{N,<:AbstractRange},chunk_size::NTuple{N, <:Integer}) where N
    cindices = CartesianIndices(ax)
    ci_first = first(cindices)
    ci_last = last(cindices)
    ci_chunk_size = CartesianIndex(chunk_size)
    ci_ones = CartesianIndex(ntuple(i->1,Val(N)))

    (ci:min(ci + ci_chunk_size - ci_ones, ci_last)
     for ci = ci_first:ci_chunk_size:ci_last)
end


function each_chunk_index(sz::NTuple{N,<:Integer},chunk_size::NTuple{N, <:Integer}) where N
    each_chunk_index(Base.OneTo.(sz),chunk_size)
end

each_chunk_index(ax::NTuple{N,<:AbstractRange},chunk_max_length::Integer) where N =
    each_chunk_index(ax,good_chunk_size(length.(ax),chunk_max_length))

each_chunk_index(sz::NTuple{N,<:Integer},chunk_max_length::Integer) where N =
    each_chunk_index(sz,good_chunk_size(sz,chunk_max_length))

each_chunk_index(array::AbstractArray,chunk_max_length::Integer) =
    each_chunk_index(axes(array),good_chunk_size(array,chunk_max_length))

each_chunk_index(array::AbstractArray,chunk_size::NTuple) =
    each_chunk_index(axes(array),chunk_size)


"""
    chunk_iterator = each_chunk(array,chunk_max_length::Integer)
    chunk_iterator = each_chunk(array,chunk_size::NTuple)

Return an iterator of non-overlapping subsets (chunks) for the the `array`.
Each element of the iterator is a view into the `array`.
The size of each chunk is equal to to the
tuple `chunk_size` if provided (the last chunk can also be smaller).
Instead of providing the chunk size, one can also provide the
maximum number of elements of a chunk with the parameter `chunk_max_length`.
The `array` parameter of `each_chunk` can also be an `OffsetArrays`.

`chunk_max_length` is typically a large number, but it should not be
so large that a single chunk exceeds the system memory.
If a chunk should not exceed a twentieth of the memory one can for example
use `chunk_max_length` equal to `Sys.free_memory() ÷ (20 * sizeof(eltype(array)))`


Example:

```julia
data = zeros(Int,(10,20,30))

for data_chunk in each_chunk(data,100)
    # check that the chunk has not being processed
    @assert all(data_chunk .== 0)
    # check that the chunk is not larger than 100
    @assert length(data_chunk) <= 100
    # set corresponding elements to one.
    data_chunk .= 1
end

# check that all the data array was processed
@assert all(data .== 1)
```

All `@assert`s statements are true in example above.



See also `parentindices`.
"""
function each_chunk(array,chunk_or_max_length)
    (view(array,ci) for ci in each_chunk_index(array,chunk_or_max_length))
end



# NetCDF chunking

# storage chunks: chunks as they are stored on disk using  e.g. nc_def_var_chunking
# processing chunks: chunks that can be processed in RAM
# processing chunks can be multiple storage chunks if sufficient RAM is available
# processing chunks are aligned with storage chunks
function good_chunk_size(v::CommonDataModel.AbstractVariable{T,N},chunk_max_length) where {T,N}

    storage,storage_chunksizes_ = chunking(v)
    storage_chunksizes = (storage_chunksizes_...,)

    if storage == :chunked
        sz = size(v) .÷ storage_chunksizes
        storage_chunklen = prod(storage_chunksizes)

        if chunk_max_length <= storage_chunklen
            # split storage chunks
            return good_chunk_size(storage_chunksizes,chunk_max_length)
        else
            return good_chunk_size(sz,chunk_max_length ÷ storage_chunklen) .* storage_chunksizes
        end
    else
        return good_chunk_size(size(v),chunk_max_length)
    end
end


#  LocalWords:  sz OffsetArrays Sys sizeof eltype julia parentindices
