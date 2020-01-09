#=
Multi-file related type definitions
=#

mutable struct MFAttributes{T} <: BaseAttributes where T <: BaseAttributes
    as::Vector{T}
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

Base.keys(a::MFAttributes) = keys(a.as[1])


mutable struct MFDimensions{T} <: AbstractDimensions where T <: AbstractDimensions
    as::Vector{T}
    aggdim::String
end


mutable struct MFGroups{T} <: AbstractGroups where T <: AbstractGroups
    as::Vector{T}
    aggdim::String
end



function Base.getindex(a::MFDimensions,name::AbstractString)
    if name == a.aggdim
        return sum(d[name] for d in a.as)
    else
        return a.as[1][name]
    end
end

function Base.setindex!(a::MFDimensions,data,name::AbstractString)
    for a in a.as
        a[name] = data
    end
    return data
end

Base.keys(a::Union{MFDimensions,MFGroups}) = keys(a.as[1])


function Base.getindex(a::MFGroups,name::AbstractString)
    ds = getindex.(a.as,name)
    attrib = MFAttributes([d.attrib for d in ds])
    dim = MFDimensions([d.dim for d in ds],a.aggdim)
    group = MFGroups([d.group for d in ds],a.aggdim)

    return MFDataset(ds,a.aggdim,attrib,dim,group)
end

#---
mutable struct MFDataset{T,N,TA,TD,TG} <: AbstractDataset where T <: AbstractDataset
    ds::Array{T,N}
    aggdim::AbstractString
    attrib::MFAttributes{TA}
    dim::MFDimensions{TD}
    group::MFGroups{TG}
end

mutable struct MFVariable{T,N,M,TA} <: AbstractVariable{T,N}
    var::CatArrays.CatArray{T,N,M,TA}
    attrib::MFAttributes
    dimnames::NTuple{N,String}
    varname::String
end
