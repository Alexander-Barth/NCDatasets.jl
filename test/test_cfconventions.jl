using NCDatasets
using Test
using DataStructures

fname = tempname()

ds = NCDataset(fname,"c")
# Dimensions

ds.dim["time"] = 3

# Declare variables
ncLAT = defVar(ds,"LAT", Float64, ("time",), attrib = [
    "standard_name"             => "latitude",
    "long_name"                 => "Latitude coordiante",
    "units"                     => "degree_north",
    "ancillary_variables"       => "QC_LAT",
    "axis"                      => "Y",
])

ncQC_LAT = defVar(ds,"QC_LAT", Int8, ("time",), attrib = [
    "standard_name"             => "latitude status_flag",
    "long_name"                 => "Quality flag for latitude",
    "_FillValue"                => Int8(10),
    "flag_values"               => Int8[0, 1, 2, 3, 4, 6, 9],
    "flag_meanings"             => "no_qc_performed good_data probably_good_data probably_bad_data bad_data spike missing_value",
])

ncDEPTH = defVar(ds,"DEPTH", Float64, (), attrib = [
    "standard_name"             => "depth",
    "long_name"                 => "Depth coordinate",
    "units"                     => "m",
    "positive"                  => "down",
    "axis"                      => "Z",
    "reference_datum"           => "geographical coordinates, WGS84 projection",
])

ncLAT[:] = [1.,2.,3.]
ncQC_LAT[:] = [1,1,4]

close(ds)


ds = NCDataset(fname,"r")

@test name(NCDatasets.ancillaryvariables(ds["LAT"],"status_flag")) == "QC_LAT"
@test isequal(NCDatasets.filter(ds["LAT"],:,accepted_status_flags = ["good_data","probably_good_data"]),
    [1.,2.,missing])

close(ds)

# query by CF Standard Name

fname = tempname()

ds = NCDataset(fname,"c", attrib = OrderedDict(
    "title"                     => "title",
));

# Dimensions

ds.dim["lon"] = 10
ds.dim["lat"] = 11

# Declare variables

nclon = defVar(ds,"lon", Float64, ("lon",), attrib = OrderedDict(
    "long_name"                 => "Longitude",
    "standard_name"             => "longitude",
    "units"                     => "degrees_east",
))

nclat = defVar(ds,"lat", Float64, ("lat",), attrib = OrderedDict(
    "long_name"                 => "Latitude",
    "standard_name"             => "latitude",
    "units"                     => "degrees_north",
))

ncvar = defVar(ds,"bat", Float32, ("lon", "lat"), attrib = OrderedDict(
    "long_name"                 => "elevation above sea level",
    "standard_name"             => "height",
    "units"                     => "meters",
    "_FillValue"                => Float32(9.96921e36),
))

ncvar1 = defVar(ds,"temp1", Float32, ("lon", "lat"), attrib = OrderedDict(
    "standard_name"             => "temperature",
    "units"                     => "degree Celsius",
    "_FillValue"                => Float32(9.96921e36),
))

ncvar2 = defVar(ds,"temp2", Float32, ("lon", "lat"), attrib = OrderedDict(
    "standard_name"             => "temperature",
    "units"                     => "degree Celsius",
    "_FillValue"                => Float32(9.96921e36),
))



# Define variables

data = rand(Float32,10,11)

nclon[:] = 1:10
nclat[:] = 1:11
ncvar[:,:] = data


height = ds[CF"height"]
@test height[:,:] == data
@test height[CF"longitude"][:] == 1:10
@test height[CF"latitude"][:] == 1:11


height = @view ds[CF"height"][2:3,2:3]
@test height[:,:] == data[2:3,2:3]
@test height[CF"longitude"][:] == 2:3
@test height[CF"latitude"][:] == 2:3

@test_throws KeyError ds[CF"temperature"]

#=
using Plots
function myplot(height::NCDatasets.AbstractVariable)
    heatmap(
        height[CF"longitude"][:],
        height[CF"latitude"][:],
        height[:,:])

end
myplot(height)
=#
