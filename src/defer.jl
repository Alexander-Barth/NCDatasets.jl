
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

        vars[varname] = OrderedDict(
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

function DeferDataset(filename,mode,info)
    Dataset(filename,mode) do ds
        r = Resource(filename,mode,info)
        groupname = "/"
        da = DeferAttributes(r,"/",r.metadata["attrib"])
        dd = DeferDimensions(r,r.metadata["dim"])
        dg = DeferGroups(r,r.metadata["group"])
        return DeferDataset(r,groupname,da,dd,dg,info)
    end
end

function DeferDataset(filename,mode = "r")
    Dataset(filename,mode) do ds
        info = metadata(ds)
        r = Resource(filename,mode,info)
        groupname = "/"
        da = DeferAttributes(r,"/",r.metadata["attrib"])
        dd = DeferDimensions(r,r.metadata["dim"])
        dg = DeferGroups(r,r.metadata["group"])
        return DeferDataset(r,groupname,da,dd,dg,info)
    end
end

close(dds::DeferDataset) = nothing
groupname(dds::DeferDataset) = dds.groupname
path(dds::DeferDataset) = dds.r.filename
Base.keys(dds::DeferDataset) = collect(keys(dds.data["var"]))

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
    data = dds.data["var"][varname]
    T = data["eltype"]
    N = length(data["dimensions"])
    da = DeferAttributes(dds.r,varname,data["attrib"])

    return DeferVariable{T,N}(dds.r,varname,da,data)
end

function Base.getindex(dv::DeferVariable,indexes::Union{Int,Colon,UnitRange{Int},StepRange{Int,Int}}...)
    Variable(dv) do v
        return v[indexes...]
    end
end


Base.size(dv::DeferVariable) = dv.data["size"]
dimnames(dv::DeferVariable) = dv.data["dimensions"]
name(dv::DeferVariable) = dv.varname

#----------------------------------------------
Base.keys(dd::DeferDimensions) = collect(keys(dd.data))
Base.getindex(dd::DeferDimensions,name::AbstractString) = dd.data[name]["length"]


Base.keys(da::DeferAttributes) = collect(keys(da.data))
Base.getindex(da::DeferAttributes,name::AbstractString) = da.data[name]

#------------------------------------------------

Base.keys(dg::DeferGroups) = collect(keys(dg.data))
function Base.getindex(dg::DeferGroups,name::AbstractString)
    data = dg.data[name]
    da = DeferAttributes(dg.r,"/",data["attrib"])
    dd = DeferDimensions(dg.r,data["dim"])
    dg = DeferGroups(dg.r,data["group"])
    return DeferDataset(dg.r,name,da,dd,dg,data)
end
