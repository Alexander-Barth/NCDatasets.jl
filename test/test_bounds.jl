using NCDatasets
using Test
using DataStructures
using Dates

time = DateTime(2000,1,1):Dates.Day(1):DateTime(2000,1,3)
time_bounds = Matrix{DateTime}(undef,2,length(time))
time_bounds[1,:] = time .- Dates.Hour(12)
time_bounds[2,:] = time .+ Dates.Hour(12)

fname = tempname()
ds = NCDataset(fname,"c")
ds.dim["nv"] = 2;
ds.dim["time"] = length(time);

nctime = defVar(ds, "time", Float64, ("time",),attrib=OrderedDict(
    "units" => "days since 2000-01-01",
    "scale_factor" => 10.,
    "bounds" => "time_bounds"));

nctime_bounds = defVar(ds, "time_bounds", Float64, ("nv","time"),attrib=OrderedDict())

ncvar = nctime
nctime_bounds = NCDatasets.bounds(ncvar)
nctime_bounds[:,:] = time_bounds
@test nctime_bounds.var[:,:] ≈ [-0.5  0.5  1.5;
                                0.5  1.5  2.5]
@test nctime_bounds[:,:] == time_bounds

close(ds)
