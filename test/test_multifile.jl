using Test
using NCDatasets
using Dates

function example_file(i,array, fname = tempname();
    varname = "var")
    @debug "fname $fname"

    NCDataset(fname,"c") do ds
        # Dimensions

        ds.dim["lon"] = size(array,1)
        ds.dim["lat"] = size(array,2)
        ds.dim["time"] = Inf

        # Declare variables

        ncvar = defVar(ds,varname, Float64, ("lon", "lat", "time"),
                       fillvalue = -9999)
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
        ncvarg = defVar(g,varname, Float64, ("lon", "lat", "time"))
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



A = [randn(2,3),randn(2,3),randn(2,3)]

C = cat(A...; dims = 3)
CA = CatArrays.CatArray(3,A...)

idx_global_local = CatArrays.index_global_local(CA,(1:1,1:1,1:1))

@inferred CatArrays.index_global_local(CA,(1:1,1:1,1:1))

@test CA[1:1,1:1,1:1] == C[1:1,1:1,1:1]
@test CA[1:1,1:1,1:2] == C[1:1,1:1,1:2]
@test CA[1:2,1:1,1:2] == C[1:2,1:1,1:2]


@test CA[:,:,1] == C[:,:,1]
@test CA[:,:,2] == C[:,:,2]
@test CA[:,2,:] == C[:,2,:]
@test CA[:,1:2:end,:] == C[:,1:2:end,:]
@test CA[1,1,1] == C[1,1,1]

CA[2,2,:] = [1.,2.,3.]
@test A[1][2,2] == 1.
@test A[2][2,2] == 2.
@test A[3][2,2] == 3.



A = [randn(2,3),randn(2,3),randn(2,3)]
C = cat(A...; dims = 3)
fnames = example_file.(1:3,A)

varname = "var"

for deferopen in (false,true)
    local data
    local lon

    mfds = NCDataset(fnames, deferopen = deferopen);
    var = variable(mfds,varname);
    data = var[:,:,:]

    @test C == var[:,:,:]

    @test_throws BoundsError var[:,:,end+1]
    @test_throws BoundsError mfds[varname].var[:,:,end+1]

    @test mfds.attrib["history"] == "foo"
    @test var.attrib["units"] == "meter second-1"

    @test dimnames(var) == ("lon", "lat", "time")
    # lon does not vary in time and thus there should be no aggregation
    lon = variable(mfds,:lon);
    @test lon.attrib["units"] == "degrees_east"
    @test size(lon) == (size(data,1),)

    var = mfds[varname]
    @test C == var[:,:,:]
    @test dimnames(var) == ("lon", "lat", "time")

    @test mfds.dim["lon"] == size(C,1)
    @test mfds.dim["lat"] == size(C,2)
    @test mfds.dim["time"] == size(C,3)

    @test mfds.dim["time"] == size(C,3)

    # save a aggregated file
    fname_merged = tempname()
    write(fname_merged,mfds)

    ds_merged = NCDataset(fname_merged)
    @test mfds.dim["time"] == size(C,3)
    close(ds_merged)


    # show
    buf = IOBuffer()
    show(buf,mfds)
    occursin("time = 3",String(take!(buf)))

    close(mfds)
end


# write
mfds = NCDataset(fnames,"a",deferopen = false);
mfds[varname][2,2,:] = 1:length(fnames)

for n = 1:length(fnames)
    NCDataset(fnames[n]) do ds
        @test ds[varname][2,2,1] == n
    end
end

mfds.attrib["history"] = "foo2"
sync(mfds)

NCDataset(fnames[1]) do ds
    @test ds.attrib["history"] == "foo2"
end

@test_throws NCDatasets.NetCDFError NCDataset(fnames,"not-a-mode")

@test keys(mfds) == [varname, "lat", "lon", "time"]
@test keys(mfds.dim) == ["lon", "lat", "time"]
@test NCDatasets.groupname(mfds) == "/"
@test size(mfds[varname]) == (2, 3, 3)
@test size(mfds[varname].var) == (2, 3, 3)
@test name(mfds[varname].var) == varname
@test NCDatasets.groupname(mfds.group["group"]) == "group"
@test fillvalue(mfds[varname]) == -9999.
@test fillvalue(mfds[varname].var) == -9999.


# create new dimension in all files
mfds.dim["newdim"] = 123;
sync(mfds);
NCDataset(fnames[1]) do ds
    @test ds.dim["newdim"] == 123
end
close(mfds)



# multi-file merge

ampl = rand(50,50)
vel = rand(50,50)

fnames = [example_file(1, vel; varname = "vel"),
          example_file(1, ampl; varname = "ampl")]

ds = NCDataset(fnames,aggdim = "", deferopen = false);

@test ds["ampl"][:,:,1] == ampl
@test ds["vel"][:,:,1] == vel

@test sort(keys(ds)) == ["ampl", "lat", "lon", "time", "vel"]


# save a merged file
fname_merged = tempname()
write(fname_merged,ds)
close(ds)

ds_merged = NCDataset(fname_merged)
@test sort(keys(ds_merged)) == ["ampl", "lat", "lon", "time", "vel"]
@test ds_merged["ampl"][:,:,1] == ampl
@test ds_merged["vel"][:,:,1] == vel
close(ds_merged)
rm(fname_merged)
nothing



# multi-file with different time units
fnames = [tempname(), tempname()]
times = [DateTime(2000,1,1), DateTime(2000,1,2)]
time_units = ["days since 2000-01-01","seconds since 2000-01-01"]

for i = 1:2
    local ds
    ds = NCDataset(fnames[i],"c")
    defVar(ds,"time",times[i:i],("time",),attrib = Dict(
        "units" => time_units[i],
        "scale_factor" => Float64(10*i),
        "add_offset" => Float64(i),
    ))
    close(ds)
end

ds = NCDataset(fnames,aggdim = "time")
@time ds["time"][:] == times
close(ds)
