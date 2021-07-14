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

unlimited(a::MFDimensions) = unique(reduce(hcat,unlimited.(a.as)))

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
    _boundsmap::Union{Nothing,Dict{String,String}}
end

mutable struct MFVariable{T,N,M,TA} <: AbstractVariable{T,N}
    var::CatArrays.CatArray{T,N,M,TA}
    attrib::MFAttributes
    dimnames::NTuple{N,String}
    varname::String
end

Base.Array(v::MFVariable) = Array(v.var)

iswritable(mfds::MFDataset) = iswritable(mfds.ds[1])


function MFDataset(ds,aggdim,attrib,dim,group)
    _boundsmap = nothing
    mfds = MFDataset(ds,aggdim,attrib,dim,group,_boundsmap)
    if !iswritable(mfds)
        initboundsmap!(mfds)
    end
    return mfds
end

"""
    mfds = NCDataset(fnames, mode = "r"; aggdim = nothing, deferopen = true)

Opens a multi-file dataset in read-only "r" or append mode "a". `fnames` is a
vector of file names. You can use [Glob.jl](https://github.com/vtjnash/Glob.jl)
to make `fnames`, e.g.
```julia
using NCDatasets, Glob
ds = NCDataset(glob("ERA5_monthly3D_reanalysis_*.nc"))
```

Variables are aggregated over the first unlimited dimension or over
the dimension `aggdim` if specified. The append mode is only implemented when
`deferopen` is `false`.

All variables containing the dimension `aggdim` are aggregated. The variable who
do not contain the dimension `aggdim` are assumed constant.

If deferopen is `false`, all files are opened at the same time.
However the operating system might limit the number of open files. In Linux,
the limit can be controled with the [command `ulimit`](https://stackoverflow.com/questions/34588/how-do-i-change-the-number-of-open-files-limit-in-linux).

All metadata (attributes and dimension length are assumed to be the same for all
NetCDF files. Otherwise reading the attribute of a multi-file dataset would be
ambiguous. An exception to this rule is the length of the dimension over which
the data is aggregated. This aggregation dimension can varify from file to file.

Setting the experimental flag `_aggdimconstant` to `true` means that the
length of the aggregation dimension is constant. This speeds up the creating of
a multi-file dataset as only the metadata of the first file has to be loaded.
"""
function NCDataset(fnames::AbstractArray{TS,N},mode = "r"; aggdim = nothing, deferopen = true,
                   _aggdimconstant = false,
                   ) where N where TS <: AbstractString
    if !(mode == "r" || mode == "a")
        throw(NetCDFError(-1,"""Unsupported mode for multi-file dataset (mode = $(mode)). Mode must be "r" or "a". """))
    end

    if deferopen
        @assert mode == "r"

        if _aggdimconstant
            # load only metadata from master
            master_index = 1
            ds_master = NCDataset(fnames[master_index],mode);
            data_master = metadata(ds_master)
            ds = Vector{Union{NCDataset,DeferDataset}}(undef,length(fnames))
            #ds[master_index] = ds_master
            for i = 1:length(fnames)
                #if i !== master_index
                ds[i] = DeferDataset(fnames[i],mode,data_master)
                #end
            end
        else
            ds = DeferDataset.(fnames,mode)
        end
    else
        ds = NCDataset.(fnames,mode);
    end

    if aggdim == nothing
        # first unlimited dimensions
        aggdim = NCDatasets.unlimited(ds[1].dim)[1]
    end

     attrib = MFAttributes([d.attrib for d in ds])
    dim = MFDimensions([d.dim for d in ds],aggdim)
    group = MFGroups([d.group for d in ds],aggdim)

    mfds = MFDataset(ds,aggdim,attrib,dim,group)
    return mfds
end

function close(mfds::MFDataset)
    close.(mfds.ds)
    return nothing
end

function sync(mfds::MFDataset)
    sync.(mfds.ds)
    return nothing
end

function path(mfds::MFDataset)
    path(mfds.ds[1]) * "…" * path(mfds.ds[end])
end
groupname(mfds::MFDataset) = groupname(mfds.ds[1])

function Base.keys(mfds::MFDataset)
    if mfds.aggdim == ""
        return unique(Iterators.flatten(keys.(mfds.ds)))
    else
        keys(mfds.ds[1])
    end
end

Base.getindex(v::MFVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) = getindex(v.var,indexes...)
Base.setindex!(v::MFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) = setindex!(v.var,data,indexes...)
Base.size(v::MFVariable) = size(v.var)
dimnames(v::MFVariable) = v.dimnames
name(v::MFVariable) = v.varname


function variable(mfds::MFDataset,varname::AbstractString)
    if mfds.aggdim == ""
        # merge all variables

        # the latest dataset should be used if a variable name is present multiple times
        for ds in reverse(mfds.ds)
            if haskey(ds,varname)
                return variable(ds,varname)
            end
        end
    else
        # aggregated along a given dimension
        vars = variable.(mfds.ds,varname)

        dim = findfirst(dimnames(vars[1]) .== mfds.aggdim)
        @debug "dim $dim"

        if (dim != nothing)
            v = CatArrays.CatArray(dim,vars...)
            return MFVariable(v,MFAttributes([var.attrib for var in vars]),
                          dimnames(vars[1]),varname)
        else
            return vars[1]
        end
    end
end
