

"""
    mfds = Dataset(fnames,mode = "r"; aggdim = nothing, deferopen = true)

Opens a multi-file dataset in read-only "r" or append mode "a". `fnames` is a
vector of file names.
Variables are aggregated over the first unlimited dimension or over
the dimension `aggdim` if specified. The append mode is only implemented when
`deferopen` is `false`.

All variables containing the dimension `aggdim` are aggregated. The variable who
do not contain the dimension `aggdim` are assumed constant.

If deferopen is `false`, all files are opened at the same time.
However the operating system might limit the number of open files. In Linux,
the limit can be controled with the command `ulimit` [1,2].

[1]: https://stackoverflow.com/questions/34588/how-do-i-change-the-number-of-open-files-limit-in-linux
[2]: https://unix.stackexchange.com/questions/8945/how-can-i-increase-open-files-limit-for-all-processes/8949#8949
"""
function Dataset(fnames::AbstractArray{TS,N},mode = "r"; aggdim = nothing, deferopen = false) where N where TS <: AbstractString
    if !(mode == "r" || mode == "a")
        throw(NetCDFError(-1,"""Unsupported mode for multi-file dataset (mode = $(mode)). Mode must be "r" or "a". """))
    end

    if deferopen
        @assert mode == "r"
        master_index = 1
        ds_master = Dataset(fnames[master_index],mode);
        data_master = metadata(ds_master)
        ds = Vector{Union{Dataset,DeferDataset}}(undef,length(fnames))
        #ds[master_index] = ds_master
        for i = 1:length(fnames)
            #if i !== master_index
                ds[i] = DeferDataset(fnames[i],mode,data_master)
            #end
        end
    else
        ds = Dataset.(fnames,mode);
    end

    if aggdim == nothing
        # first unlimited dimensions
        aggdim = NCDatasets.unlimited(ds[1].dim)[1]
    end

    attrib = MFAttributes([d.attrib for d in ds])
    dim = MFDimensions([d.dim for d in ds],aggdim)
    group = MFGroups([d.group for d in ds],aggdim)

    return MFDataset(ds,aggdim,attrib,dim,group)
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
Base.keys(mfds::MFDataset) = keys(mfds.ds[1])

Base.getindex(v::MFVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) = getindex(v.var,indexes...)
Base.setindex!(v::MFVariable,data,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...) = setindex!(v.var,data,indexes...)
Base.size(v::MFVariable) = size(v.var)
dimnames(v::MFVariable) = v.dimnames
name(v::MFVariable) = v.varname


function variable(mfds::MFDataset,varname::AbstractString)
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
