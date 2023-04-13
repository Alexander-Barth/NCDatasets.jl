
Base.keys(a::MFAttributes) = keys(a.as[1])



function Base.getindex(a::MFDimensions,name::AbstractString)
    if name == a.aggdim
        if a.isnewdim
            return length(a.as)
        else
            return sum(d[name] for d in a.as)
        end
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

Base.keys(a::MFGroups) = keys(a.as[1])


function Base.keys(a::MFDimensions)
    k = collect(keys(a.as[1]))

    if a.isnewdim
        push!(k,a.aggdim)
    end

    return k
end

unlimited(a::MFDimensions) = unique(reduce(hcat,unlimited.(a.as)))

function Base.getindex(a::MFGroups,name::AbstractString)
    ds = getindex.(a.as,name)
    attrib = MFAttributes([d.attrib for d in ds])
    dim = MFDimensions([d.dim for d in ds],a.aggdim,a.isnewdim)
    group = MFGroups([d.group for d in ds],a.aggdim,a.isnewdim)
    constvars = Symbol[]

    return MFDataset(ds,a.aggdim,a.isnewdim,constvars,attrib,dim,group)
end


Base.Array(v::MFVariable) = Array(v.var)

iswritable(mfds::MFDataset) = iswritable(mfds.ds[1])


function MFDataset(ds,aggdim,isnewdim,constvars,attrib,dim,group)
    _boundsmap = Dict{String,String}()
    mfds = MFDataset(ds,aggdim,isnewdim,constvars,attrib,dim,group,_boundsmap)
    if !iswritable(mfds)
        initboundsmap!(mfds)
    end
    return mfds
end

"""
    mfds = NCDataset(fnames, mode = "r"; aggdim = nothing, deferopen = true,
                  isnewdim = false,
                  constvars = [])

Opens a multi-file dataset in read-only `"r"` or append mode `"a"`. `fnames` is a
vector of file names.

Variables are aggregated over the first unlimited dimension or over
the dimension `aggdim` if specified. Variables without the dimensions `aggdim`
are not aggregated. All variables containing the dimension `aggdim` are
aggregated. The variable who do not contain the dimension `aggdim` are assumed
constant.

If variables should be aggregated over a new dimension (not present in the
NetCDF file), one should set `isnewdim` to `true`. All NetCDF files should have
the same variables, attributes and groupes. Per default, all variables will
have an additional dimension unless they are marked as constant using the
`constvars` parameter.

The append mode is only implemented when `deferopen` is `false`.
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

Examples:

You can use [Glob.jl](https://github.com/vtjnash/Glob.jl) to make `fnames`
from a file pattern, e.g.

```julia
using NCDatasets, Glob
ds = NCDataset(glob("ERA5_monthly3D_reanalysis_*.nc"))
```

Aggregation over a new dimension:

```julia
using NCDatasets
for i = 1:3
  NCDataset("foo\$i.nc","c") do ds
    defVar(ds,"data",[10., 11., 12., 13.], ("lon",))
  end
end

ds = NCDataset(["foo\$i.nc" for i = 1:3],aggdim = "sample", isnewdim = true)
size(ds["data"])
# output
# (4, 3)
```


"""
function NCDataset(fnames::AbstractArray{TS,N},mode = "r"; aggdim = nothing,
                   deferopen = true,
                   _aggdimconstant = false,
                   isnewdim = false,
                   constvars = Union{Symbol,String}[],
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
            for (i,fname) in enumerate(fnames)
                #if i !== master_index
                ds[i] = DeferDataset(fname,mode,data_master)
                #end
            end
        else
            ds = DeferDataset.(fnames,mode)
        end
    else
        ds = NCDataset.(fnames,mode);
    end

    if (aggdim == nothing) && !isnewdim
        # first unlimited dimensions
        aggdim = NCDatasets.unlimited(ds[1].dim)[1]
    end

    attrib = MFAttributes([d.attrib for d in ds])

    dim = MFDimensions([d.dim for d in ds],aggdim,isnewdim)
    group = MFGroups([d.group for d in ds],aggdim,isnewdim)

    mfds = MFDataset(ds,aggdim,isnewdim,Symbol.(constvars),attrib,dim,group)
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

Base.getindex(v::MFVariable,indexes::Union{Int,Colon,AbstractRange{<:Integer}}...) = getindex(v.var,indexes...)
Base.setindex!(v::MFVariable,data,indexes::Union{Int,Colon,AbstractRange{<:Integer}}...) = setindex!(v.var,data,indexes...)

Base.size(v::MFVariable) = size(v.var)
Base.size(v::MFCFVariable) = size(v.var)
dimnames(v::MFVariable) = v.dimnames
name(v::MFVariable) = v.varname


function _variable(mfds::MFDataset,varname::SymbolOrString)
    if mfds.isnewdim
        if Symbol(varname) in mfds.constvars
            return variable(mfds.ds[1],varname)
        end
        # aggregated along a given dimension
        vars = variable.(mfds.ds,varname)
        v = CatArrays.CatArray(ndims(vars[1])+1,vars...)
        return MFVariable(mfds,v,MFAttributes([var.attrib for var in vars]),
                          (dimnames(vars[1])...,mfds.aggdim),String(varname))
    elseif mfds.aggdim == ""
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
        @debug "dimension $dim"

        if (dim != nothing)
            v = CatArrays.CatArray(dim,vars...)
            return MFVariable(mfds,v,MFAttributes([var.attrib for var in vars]),
                          dimnames(vars[1]),String(varname))
        else
            return vars[1]
        end
    end
end
variable(mfds::MFDataset,varname::AbstractString) = _variable(mfds,varname)
variable(mfds::MFDataset,varname::Symbol) = _variable(mfds,varname)



function _cfvariable(mfds::MFDataset,varname::SymbolOrString)
    if mfds.isnewdim
        if Symbol(varname) in mfds.constvars
            return cfvariable(mfds.ds[1],varname)
        end
        # aggregated along a given dimension
        cfvars = cfvariable.(mfds.ds,varname)
        cfvar = CatArrays.CatArray(ndims(cfvars[1])+1,cfvars...)
        var = variable(mfds,varname)

        return MFCFVariable(mfds,cfvar,var,var.attrib,
                            dimnames(var),varname)
    elseif mfds.aggdim == ""
        # merge all variables

        # the latest dataset should be used if a variable name is present multiple times
        for ds in reverse(mfds.ds)
            if haskey(ds,varname)
                return cfvariable(ds,varname)
            end
        end
    else
        # aggregated along a given dimension
        cfvars = cfvariable.(mfds.ds,varname)

        dim = findfirst(dimnames(cfvars[1]) .== mfds.aggdim)
        @debug "dim $dim"

        if (dim != nothing)
            cfvar = CatArrays.CatArray(dim,cfvars...)
            var = variable(mfds,varname)

            return MFCFVariable(mfds,cfvar,var,var.attrib,
                          dimnames(var),String(varname))
        else
            return cfvars[1]
        end
    end
end


cfvariable(mfds::MFDataset,varname::AbstractString) = _cfvariable(mfds,varname)
cfvariable(mfds::MFDataset,varname::Symbol) = _cfvariable(mfds,varname)

fillvalue(v::Union{MFVariable{T},MFCFVariable{T}}) where T = v.attrib["_FillValue"]::T
dataset(v::Union{MFVariable,MFCFVariable}) = v.ds


Base.getindex(v::MFCFVariable,ind...) = v.cfvar[ind...]
Base.setindex!(v::MFCFVariable,data,ind...) = v.cfvar[ind...] = data


function Base.cat(vs::AbstractVariable...; dims::Integer)
    CatArrays.CatArray(dims,vs...)
end
