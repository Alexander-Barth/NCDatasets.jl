
function metadata(ds::Dataset)
    # dimensions

    dim = OrderedDict()
    unlimited_dims = unlimited(ds.dim)

    for (dimname,dimlen) in ds.dim
        dim[dimname] = Dict(
            "name" => dimname,
            "length" => dimlen,
            "unlimited" => dimname in unlimited_dims
        )
    end

    # variables
    vars = OrderedDict()

    for (varname,ncvar) in ds
        storage,chunksizes = chunking(ncvar.var)
        isshuffled,isdeflated,deflatelevel = deflate(ncvar.var)

        vars[varname] = Dict(
            "name" => varname,
            "size" => size(ncvar),
            "eltype" => eltype(ncvar.var),
            "attrib" => OrderedDict(ncvar.attrib),
            "dimensions" => dimnames(ncvar),
            "chunksize" => chunksizes,
            "fillvalue" => fillvalue(ncvar.var),
            "shuffle" => isshuffled,
            "deflatelevel" => deflatelevel
        )
    end

    group = OrderedDict()
    for (groupname,ncgroup) in ds.group
        group[groupname] = metadata(ncgroup)
    end

    return OrderedDict(
        "dim" => dim,
        "var" => vars,
        "attrib" => OrderedDict(ds.attrib),
        "group" => group
        )
end

function DeferDataset(filename,mode = "r")
    Dataset(filename,mode) do ds
        info = metadata(ds)
        r = Resource(filename,mode,info)
        da = DeferAttributes(r,"/",r.metadata["attrib"])
        dd = DeferDimensions(r,r.metadata["dim"])
        dg = DeferGroups(r,r.metadata["group"])
        return DeferDataset(r,da,dd,dg)
    end
end

close(dds::DeferDataset) = nothing
groupname(dds::DeferDataset) = keys(dds.group.data)
Base.keys(dds::DeferDataset) = collect(keys(dds.r.metadata["var"]))

function Dataset(f::Function, r::Resource)
    Dataset(r.filename,r.mode) do ds
        f(ds)
    end
end

function Dataset(f::Function, dds::DeferDataset)
    Dataset(dds.r.filename,dds.r.mode) do ds
        f(ds)
    end
end

function Variable(f::Function, dv::DeferVariable)
    Dataset(dv.r.filename,dv.r.mode) do ds
        f(variable(ds,dv.varname))
    end
end

function variable(dds::DeferDataset,varname::AbstractString)
    T = dds.r.metadata["var"][varname]["eltype"]
    N = length(dds.r.metadata["var"][varname]["dimensions"])
    da = DeferAttributes(dds.r,varname,dds.r.metadata["var"][varname]["attrib"])

    return DeferVariable{T,N}(dds.r,varname,da)
end

function Base.getindex(dv::DeferVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    Variable(dv) do v
        return v[indexes...]
    end
end


Base.size(dv::DeferVariable) = dv.r.metadata["var"][dv.varname]["size"]
dimnames(dv::DeferVariable) = dv.r.metadata["var"][dv.varname]["dimensions"]
name(dv::DeferVariable) = dv.varname

#----------------------------------------------
Base.keys(dd::DeferDimensions) = collect(keys(dd.data))
Base.getindex(dd::DeferDimensions,name::AbstractString) = dd.data[name]["length"]


Base.keys(da::DeferAttributes) = collect(keys(da.data))
Base.getindex(da::DeferAttributes,name::AbstractString) = da.data[name]

#------------------------------------------------

Base.keys(dg::DeferGroups) = collect(keys(dg.data))
function Base.getindex(dg::DeferGroups,name::AbstractString)
    r = dg.r.metadata["group"][name]
    da = DeferAttributes(dg.r,"/",r["attrib"])
    dd = DeferDimensions(dg.r,r["dim"])
    dg = DeferGroups(dg.r,r["group"])
    return DeferDataset(dg.r,da,dd,dg)
end
