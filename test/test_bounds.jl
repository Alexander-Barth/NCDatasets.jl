using NCDatasets
using Test
using DataStructures
using Dates

time = DateTime(2000,1,2):Dates.Day(1):DateTime(2000,1,4)
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

nctime[:] = time
nctime_bounds = NCDatasets.bounds(nctime)
nctime_bounds[:,:] = time_bounds
@test nctime_bounds.var[:,:] ≈ [0.5  1.5  2.5;
                                1.5  2.5  3.5]
@test nctime_bounds[:,:] == time_bounds

close(ds)


# NCDatasets issue 170

fname = tempname()
ds = NCDataset(fname,"c")

ds.dim["time"] = 3
ds.dim["bnds"] = 2

nctime = defVar(ds,"time", Float64, ("time",), attrib = OrderedDict(
    "standard_name"             => "time",
    "long_name"                 => "time",
    "units"                     => "days since 2001-1-1",
    "bounds"                    => "time_bnds",
))

nctime_bnds = defVar(ds,"time_bnds", Float64, ("bnds", "time"))

nctos = defVar(ds,"tos", Float32, ("time",), attrib = OrderedDict(
    "_FillValue"                => Float32(1.0e20),
))

nctos[:] = zeros(Float32,3)
close(ds)

ds = NCDataset(fname)
tos = ds["tos"][:]
@test all(tos .== zeros(3))
close(ds)
