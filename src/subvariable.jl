
Base.parent(v::SubVariable) = v.parent
Base.parentindices(v::SubVariable) = v.indices
Base.size(v::SubVariable) = _shape_after_slice(size(v.parent),v.indices...)

dimnames(v::SubVariable) = dimnames(v.parent)
name(v::SubVariable) = name(v.parent)

function SubVariable(A::AbstractVariable,indices...)
    T = eltype(A)
    N = ndims(A)
    SubVariable{T,N,typeof(A),typeof(indices),typeof(A.attrib)}(A,indices,A.attrib)
end

SubVariable(A::AbstractVariable{T,N}) where T where N = SubVariable(A,ntuple(i -> :,N)...)

# recursive calls so that the compiler can infer the types via inline-ing
# and constant propagation
_subsub(indices,i,l) = indices
_subsub(indices,i,l,ip,rest...) = _subsub((indices...,ip[i[l]]),i,l+1,rest...)
_subsub(indices,i,l,ip::Number,rest...) = _subsub((indices...,ip),i,l,rest...)
_subsub(indices,i,l,ip::Colon,rest...) = _subsub((indices...,i[l]),i,l+1,rest...)

"""
    j = subsub(parentindices,indices)

Computed the tuple of indices `j` so that
`A[parentindices...][indices...] = A[j...]` for any array `A` and any tuple of
valid indices `parentindices` and `indices`
"""
subsub(parentindices,indices) = _subsub((),indices,1,parentindices...)

materialize(v::SubVariable) = v.parent[v.indices...]

"""
collect always returns an array.
Even if the result of the indexing is a scalar, it is wrapped
into a zero-dimensional array.
"""
function collect(v::SubVariable{T,N}) where T where N
    if N == 0
        A = Array{T,0}(undef,())
        A[] = v.parent[v.indices...]
        return A
    else
        v.parent[v.indices...]
    end
end

Base.Array(v::SubVariable) = collect(v)

function Base.view(v::SubVariable,indices...)
    sub_indices = subsub(v.indices,indices)
    SubVariable(parent(v),sub_indices...)
end

"""
    sv = view(v::NCDatasets.AbstractVariable,indices...)

Returns a view of the variable `v` where indices are only lazily applied.
No data is actually copied or loaded.
Modifications to a view `sv`, also modifies the underlying array `v`.
All attributes of `v` are also present in `sv`.

# Examples

```julia
using NCDatasets
fname = tempname()
data = zeros(Int,10,11)
ds = NCDataset(fname,"c")
ncdata = defVar(ds,"temp",data,("lon","lat"))
ncdata_view = view(ncdata,2:3,2:4)
size(ncdata_view)
# output (2,3)
ncdata_view[1,1] = 1
ncdata[2,2]
# outputs 1 as ncdata is also modified
close(ds)
```

"""
Base.view(v::AbstractVariable,indices...) = SubVariable(v,indices...)
Base.view(v::SubVariable,indices::CartesianIndex) = view(v,indices.I...)
Base.view(v::SubVariable,indices::CartesianIndices) = view(v,indices.indices...)

Base.getindex(v::SubVariable,indices...) = materialize(view(v,indices...))
Base.getindex(v::SubVariable,indices::CartesianIndex) = getindex(v,indices.I...)
Base.getindex(v::SubVariable,indices::CartesianIndices) =
    getindex(v,indices.indices...)

function Base.setindex!(v::SubVariable,data,indices...)
    sub_indices = subsub(v.indices,indices)
    v.parent[sub_indices...] = data
end

Base.setindex!(v::SubVariable,data,indices::CartesianIndex) =
    setindex!(v,data,indices.I...)
Base.setindex!(v::SubVariable,data,indices::CartesianIndices) =
    setindex!(v,data,indices.indices...)
