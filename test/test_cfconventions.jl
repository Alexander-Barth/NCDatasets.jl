using NCDatasets
if VERSION >= v"0.7.0-beta.0"
    using Test
else
    using Base.Test
end

fname = tempname()

ds = Dataset(fname,"c")
# Dimensions

ds.dim["time"] = 3

# Declare variables

ncLAT = defVar(ds,"LAT", Float64, ("time",))
ncLAT.attrib["standard_name"] = "latitude"
ncLAT.attrib["long_name"] = "Latitude coordiante"
ncLAT.attrib["units"] = "degree_north"
ncLAT.attrib["ancillary_variables"] = "QC_LAT"
ncLAT.attrib["axis"] = "Y"

ncQC_LAT = defVar(ds,"QC_LAT", Int8, ("time",))
ncQC_LAT.attrib["standard_name"] = "latitude status_flag"
ncQC_LAT.attrib["long_name"] = "Quality flag for latitude"
ncQC_LAT.attrib["_FillValue"] = Int8(10)
ncQC_LAT.attrib["flag_values"] = Int8[0, 1, 2, 3, 4, 6, 9]
ncQC_LAT.attrib["flag_meanings"] = "no_qc_performed good_data probably_good_data probably_bad_data bad_data spike missing_value"

ncDEPTH = defVar(ds,"DEPTH", Float64, ()) 
ncDEPTH.attrib["standard_name"] = "depth"
ncDEPTH.attrib["long_name"] = "Depth coordinate"
ncDEPTH.attrib["units"] = "m"
ncDEPTH.attrib["positive"] = "down"
ncDEPTH.attrib["axis"] = "Z"
ncDEPTH.attrib["reference_datum"] = "geographical coordinates, WGS84 projection"



ncLAT[:] = [1.,2.,3.]
ncQC_LAT[:] = [1,1,4]

close(ds)


ds = Dataset(fname,"r")

@test name(NCDatasets.ancillaryvariables(ds["LAT"],"status_flag")) == "QC_LAT"
@test isequal(NCDatasets.filter(ds["LAT"],:,accepted_status_flags = ["good_data","probably_good_data"]),
    [1.,2.,missing])
