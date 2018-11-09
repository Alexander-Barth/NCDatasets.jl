
function MFDataset(fnames::AbstractArray{TS,N},mode = "r"; aggdim = nothing) where N where TS <: AbstractString
    ds = Dataset.(fnames,mode);

    if aggdim == nothing
        # first unlimited dimensions
        aggdim = NCDatasets.unlimited(ds[1].dim)[1]
    end

    attrib = MFAttributes([d.attrib for d in ds])
    return MFDataset(ds,aggdim,attrib)
end

close(mfds::MFDataset) = close.(mfds.ds)


mutable struct MFVariable{T,N,M,TA} <: AbstractArray{T,N}
    var::CatArrays.CatArray{T,N,M,TA}
    attrib::MFAttributes
end

Base.getindex(v::MFVariable,indexes...) = getindex(v.var,indexes...)
Base.setindex!(v::MFVariable,data,indexes...) = setindex!(v.var,data,indexes...)
_attrib(v::MFVariable) = Attributes(v.ncid,v.varid,v.isdefmode)


function variable(mfds::MFDataset,varname::AbstractString)
    vars = variable.(mfds.ds,varname)

    dim = findfirst(dimnames(vars[1]) .== mfds.aggdim)
    @show dim
    @debug begin
        @show dim
    end

    if dim != nothing
        v = CatArrays.CatArray(dim,vars...)
        return MFVariable(v,MFAttributes([var.attrib for var in vars]))
    else
        return vars[1]
    end
end

