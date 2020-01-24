using NCDatasets
using Test

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
