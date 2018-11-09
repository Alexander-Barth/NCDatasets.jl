if VERSION >= v"0.7"
    using Test
else
    using Base.Test
    using Compat
    using Compat: cat
end

using NCDatasets
import NCDatasets: variable, MFAttributes, close
using NCDatasets
import NCDatasets.CatArrays: CatArray
import Base: getindex, setindex!, close

function example_file(i,array)
    fname = "/tmp/filename_$(i).nc"
    @debug begin
        @show fname
    end
    Dataset(fname,"c") do ds
    # Dimensions

    ds.dim["lon"] = size(array,1)
    ds.dim["lat"] = size(array,2)
    ds.dim["time"] = 1

    # Declare variables

    ncvar = defVar(ds,"var", Float64, ("lon", "lat", "time"))
    ncvar.attrib["field"] = "u-wind, scalar, series"
    ncvar.attrib["units"] = "meter second-1"
    ncvar.attrib["long_name"] = "surface u-wind component"
    ncvar.attrib["time"] = "time"
    ncvar.attrib["coordinates"] = "lon lat"


    nclat = defVar(ds,"lat", Float64, ("lon", "lat"))
    nclat.attrib["units"] = "degrees_north"
    nclat.attrib["point_spacing"] = "uneven"
    nclat.attrib["axis"] = "Y"

    nclon = defVar(ds,"lon", Float64, ("lon", "lat"))
    nclon.attrib["units"] = "degrees_east"
    nclon.attrib["modulo"] = 360.0
    nclon.attrib["point_spacing"] = "even"
    nclon.attrib["axis"] = "X"

    nctime = defVar(ds,"time", Float64, ("time",))
    nctime.attrib["long_name"] = "surface wind time"
    nctime.attrib["field"] = "time, scalar, series"
    nctime.attrib["units"] = "days since 1858-11-17 00:00:00 GMT"

    # Global attributes

    ds.attrib["history"] = "foo"

    # Define variables

    ncvar[:,:,1] = array
    # nclat[:] = ...
    # nclon[:] = ...
    nctime[:] = i

    end
    return fname
end



A = [randn(2,3),randn(2,3),randn(2,3)]

C = cat(A...; dims = 3)
CA = CatArrays.CatArray(3,A...)

idx_global,idx_local,sz = CatArrays.idx_global_local_(CA,(1:1,1:1,1:1))

@inferred CatArrays.idx_global_local_(CA,(1:1,1:1,1:1))

@testset "CatArrays" begin
    @test CA[1:1,1:1,1:1] == C[1:1,1:1,1:1]
    @test CA[1:1,1:1,1:2] == C[1:1,1:1,1:2]
    @test CA[1:2,1:1,1:2] == C[1:2,1:1,1:2]


    @test CA[:,:,1] == C[:,:,1]
    @test CA[:,:,2] == C[:,:,2]
    @test CA[:,2,:] == C[:,2,:]
    @test CA[:,1:2:end,:] == C[:,1:2:end,:]
    @test CA[1,1,1] == C[1,1,1]
end

mutable struct MFDataset{N}
    ds::Array{Dataset,N}
    dimname::AbstractString
    attrib::MFAttributes
end

fnames = example_file.(1:3,A)

function MFDataset(fnames::AbstractArray{TS,N},mode = "r") where N where TS <: AbstractString
    ds = Dataset.(fnames,mode);
    dimname = "time"
    attrib = MFAttributes([d.attrib for d in ds])
    return MFDataset(ds,dimname,attrib)
end
function close(ds::MFDataset)
    close.(ds.ds)
end

mutable struct MFVariable{T,N,M,TA} <: AbstractArray{T,N}
    var::CatArray{T,N,M,TA}
    attrib::MFAttributes
end

Base.getindex(v::MFVariable,indexes...) = getindex(v.var,indexes...)
Base.setindex!(v::MFVariable,data,indexes...) = setindex!(v.var,data,indexes...)

function variable(ds::MFDataset,varname::AbstractString)
    vars = variable.(ds.ds,varname)
    dim = 3
    v = CatArrays.CatArray(dim,vars...)

    return MFVariable(v,MFAttributes([var.attrib for var in vars]))
end


ds = MFDataset(fnames);
varname = "var"
var = variable(ds,varname);
data = var[:,:,:]

@testset "Multi-file" begin
    @test C == data
    @test ds.attrib["history"] == "foo"
    @test var.attrib["units"] == "meter second-1"
end

close(ds)
