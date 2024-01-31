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
close(ds)

fname = tempname()

ds = NCDataset(fname,"c")

ds.dim["xi_u"] = 137
ds.dim["xi_v"] = 138
ds.dim["eta_u"] = 75
ds.dim["eta_v"] = 74
ds.dim["ocean_time"] = Inf # unlimited dimension

nclon_u = defVar(ds,"lon_u", Float64, ("xi_u", "eta_u"), attrib = OrderedDict(
    "standard_name"             => "longitude",
))
nclat_u = defVar(ds,"lat_u", Float64, ("xi_u", "eta_u"), attrib = OrderedDict(
    "standard_name"             => "latitude",
))
nclon_v = defVar(ds,"lon_v", Float64, ("xi_v", "eta_v"), attrib = OrderedDict(
    "standard_name"             => "longitude",
))
nclat_v = defVar(ds,"lat_v", Float64, ("xi_v", "eta_v"), attrib = OrderedDict(
    "standard_name"             => "latitude",
))
ncubar = defVar(ds,"ubar", Float32, ("xi_u", "eta_u", "ocean_time"), attrib = OrderedDict(
    "standard_name"             => "barotropic_sea_water_x_velocity",
))
ncvbar = defVar(ds,"vbar", Float32, ("xi_v", "eta_v", "ocean_time"), attrib = OrderedDict(
    "standard_name"             => "barotropic_sea_water_y_velocity",
))
close(ds)


ds = NCDataset(fname)
# This produces an error because it is unclear if we should load lon_u or lon_v
@test_throws KeyError ds[CF"longitude"] # error

nclon_u2 = ds["ubar"][CF"longitude"]
@test name(nclon_u2) == "lon_u"


nclon_u2 = ds["ubar"]["lon_u"]
@test name(nclon_u2) == "lon_u"

nclon_u2 = ds["ubar"][:lon_u]
@test name(nclon_u2) == "lon_u"
close(ds)
