if VERSION >= v"0.7"
    using Test
else
    using Base.Test
    using Compat
    using Compat: cat, @debug
end

using NCDatasets
using DataStructures

function example_file(i,array)
    fname = tempname()
    @debug "fname $fname"

    Dataset(fname,"c") do ds
        # Dimensions

        ds.dim["lon"] = size(array,1)
        ds.dim["lat"] = size(array,2)
        ds.dim["time"] = Inf

        # Declare variables

        ncvar = defVar(ds,"var", Float64, ("lon", "lat", "time"))
        ncvar.attrib["field"] = "u-wind, scalar, series"
        ncvar.attrib["units"] = "meter second-1"
        ncvar.attrib["long_name"] = "surface u-wind component"
        ncvar.attrib["time"] = "time"
        ncvar.attrib["coordinates"] = "lon lat"


        nclat = defVar(ds,"lat", Float64, ("lat",))
        nclat.attrib["units"] = "degrees_north"

        nclon = defVar(ds,"lon", Float64, ("lon",))
        nclon.attrib["units"] = "degrees_east"
        nclon.attrib["modulo"] = 360.0

        nctime = defVar(ds,"time", Float64, ("time",))
        nctime.attrib["long_name"] = "surface wind time"
        nctime.attrib["field"] = "time, scalar, series"
        nctime.attrib["units"] = "days since 2000-01-01 00:00:00 GMT"

        # Global attributes

        ds.attrib["history"] = "foo"

        # Define variables

        g = defGroup(ds,"group")
        ncvarg = defVar(g,"var", Float64, ("lon", "lat", "time"))
        ncvarg.attrib["field"] = "u-wind, scalar, series"
        ncvarg.attrib["units"] = "meter second-1"
        ncvarg.attrib["long_name"] = "surface u-wind component"
        ncvarg.attrib["time"] = "time"
        ncvarg.attrib["coordinates"] = "lon lat"

        ncvar[:,:,1] = array
        ncvarg[:,:,1] = array.+1
        #nclon[:] = 1:size(array,1)
        #nclat[:] = 1:size(array,2)
        nctime[:] = i
    end
    return fname
end

A = randn(2,3,1)


fname = example_file(1,A)


ds = Dataset(fname)

info = NCDatasets.metadata(ds)

@show info

dds = DeferDataset(fname);
varname = "var"
var = variable(dds,varname);
data = var[:,:,:]


@test A == var[:,:,:]

@test dds.attrib["history"] == "foo"
@test var.attrib["units"] == "meter second-1"

@test dimnames(var) == ("lon", "lat", "time")
lon = variable(dds,"lon");
@test lon.attrib["units"] == "degrees_east"
@test size(lon) == (size(data,1),)


var = dds[varname]
@test A == var[:,:,:]

@test dimnames(var) == ("lon", "lat", "time")

@test dds.dim["lon"] == size(A,1)
@test dds.dim["lat"] == size(A,2)
@test dds.dim["time"] == size(A,3)

@test dds.dim["time"] == size(A,3)
close(dds)

# show
buf = IOBuffer()
show(buf,dds)
@test occursin("time = 3",String(take!(buf)))

#=
# write
dds = Dataset(fnames,"a");
dds["var"][2,2,:] = 1:length(fnames)

for n = 1:length(fnames)
    Dataset(fnames[n]) do ds
        @test ds["var"][2,2,1] == n
    end
end

dds.attrib["history"] = "foo2"
sync(dds)

Dataset(fnames[1]) do ds
    @test ds.attrib["history"] == "foo2"
end

@test_throws NCDatasets.NetCDFError Dataset(fnames,"not-a-mode")

@test keys(dds) == ["var", "lat", "lon", "time"]
@test keys(dds.dim) == ["lon", "lat", "time"]
@test NCDatasets.groupname(dds) == "/"
@test size(dds["var"]) == (2, 3, 3)
@test size(dds["var"].var) == (2, 3, 3)
@test name(dds["var"].var) == "var"
@test NCDatasets.groupname(dds.group["group"]) == "group"


# create new dimension in all files
dds.dim["newdim"] = 123;
sync(dds);
Dataset(fnames[1]) do ds
    @test ds.dim["newdim"] == 123
end
close(dds)
=#
nothing

