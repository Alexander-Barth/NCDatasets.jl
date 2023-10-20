
Base.parent(v::SubVariable) = v.parent
Base.parentindices(v::SubVariable) = v.indices
Base.size(v::SubVariable) = _shape_after_slice(size(v.parent),v.indices...)

function dimnames(v::SubVariable)
    dimension_names = dimnames(v.parent)
    return dimension_names[map(i -> !(i isa Integer),collect(v.indices))]
end

name(v::SubVariable) = name(v.parent)

function SubVariable(A::AbstractVariable,indices...)
    var = nothing
    if hasproperty(A,:var)
        if hasproperty(A.var,:attrib)
            var = SubVariable(A.var,indices...)
        end
    end
    T = eltype(A)
    N = ndims(A)
    return SubVariable{T,N,typeof(A),typeof(indices),typeof(A.attrib),typeof(var)}(
        A,indices,A.attrib,var)
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
        return v.parent[v.indices...]
    end
end

Base.Array(v::SubVariable) = collect(v)

function Base.view(v::SubVariable,indices::Union{Int,Colon,AbstractVector{Int}}...)
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
Base.view(v::Union{CFVariable, DeferVariable, MFCFVariable, MFVariable},indices::Union{Int,Colon,AbstractVector{Int}}...) = SubVariable(v,indices...)
Base.view(v::Variable,indices::Union{Int,Colon,AbstractVector{Int}}...) = SubVariable(v,indices...)
Base.view(v::SubVariable,indices::CartesianIndex) = view(v,indices.I...)
Base.view(v::SubVariable,indices::CartesianIndices) = view(v,indices.indices...)

Base.getindex(v::SubVariable,indices::Union{Int,Colon,AbstractRange{<:Integer}}...) = materialize(view(v,indices...))

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






Base.keys(ds::SubDimensions) = keys(ds.dim)

function Base.getindex(sd::SubDimensions,dimname)
    dn = Symbol(dimname)
    if hasproperty(sd.indices,dn)
        ind = getproperty(sd.indices,dn)
        if ind == Colon()
            return sd.dim[dimname]
        else
            return length(ind)
        end
    else
        return sd.dim[dimname]
    end
end

unlimited(sd::SubDimensions) = unlimited(sd.dim)

function SubDataset(ds::AbstractNCDataset,indices)
    dim = SubDimensions(ds.dim,indices)
    group = OrderedDict((n => SubDataset(g,indices) for (n,g) in ds.group)...)
    SubDataset(ds,indices,dim,ds.attrib,group)
end

function Base.view(ds::AbstractNCDataset; indices...)
    SubDataset(ds,values(indices))
end

function Base.getindex(ds::SubDataset,varname::Union{AbstractString, Symbol})
    ncvar = ds.ds[varname]
    if ndims(ncvar) == 0
        return ncvar
    end

    dims = dimnames(ncvar)
    ind = ntuple(i -> get(ds.indices,Symbol(dims[i]),:),ndims(ncvar))
    return view(ncvar,ind...)
end

function variable(ds::SubDataset,varname::Union{AbstractString, Symbol})
    ncvar = variable(ds.ds,varname)
    if ndims(ncvar) == 0
        return ncvar
    end
    dims = dimnames(ncvar)
    ind = ntuple(i -> get(ds.indices,Symbol(dims[i]),:),ndims(ncvar))
    return view(ncvar,ind...)
end


Base.keys(ds::SubDataset) = keys(ds.ds)
path(ds::SubDataset) = path(ds.ds)
groupname(ds::SubDataset) = groupname(ds.ds)


function dataset(v::SubVariable)
    indices = (;((Symbol(d),i) for (d,i) in zip(dimnames(v),v.indices))...)
    return SubDataset(dataset(v.parent),indices)
end

function chunking(v::SubVariable)
    storage, chunksizes = chunking(v.parent)
    return storage, min.(chunksizes,collect(size(v)))
end

deflate(v::SubVariable) = deflate(v.parent)
checksum(v::SubVariable) = checksum(v.parent)
