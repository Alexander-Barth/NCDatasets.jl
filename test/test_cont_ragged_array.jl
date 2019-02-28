using NCDatasets
if VERSION >= v"0.7.0-beta.0"
    using Test
else
    using Base.Test
end

fname = tempname()
fname = "test_cont_ragged_array.nc"
ds = Dataset(fname,"c")
# Dimensions

ds.dim["obs"] = 7
ds.dim["profile"] = 3

# Declare variables

ncprofile = defVar(ds,"profile", Int32, ("profile",))
ncprofile.attrib["cf_role"] = "profile_id"

nctime = defVar(ds,"time", Float64, ("profile",))
nctime.attrib["standard_name"] = "time"
nctime.attrib["long_name"] = "time"
nctime.attrib["units"] = "days since 1970-01-01 00:00:00"

nclon = defVar(ds,"lon", Float32, ("profile",))
nclon.attrib["standard_name"] = "longitude"
nclon.attrib["long_name"] = "longitude"
nclon.attrib["units"] = "degrees_east"

nclat = defVar(ds,"lat", Float32, ("profile",))
nclat.attrib["standard_name"] = "latitude"
nclat.attrib["long_name"] = "latitude"
nclat.attrib["units"] = "degrees_north"

ncrowSize = defVar(ds,"rowSize", Int32, ("profile",))
ncrowSize.attrib["long_name"] = "number of obs for this profile "
ncrowSize.attrib["sample_dimension"] = "obs"

ncz = defVar(ds,"z", Float32, ("obs",))
ncz.attrib["standard_name"] = "altitude"
ncz.attrib["long_name"] = "height above mean sea level"
ncz.attrib["units"] = "km"
ncz.attrib["positive"] = "up"
ncz.attrib["axis"] = "Z"

ncpressure = defVar(ds,"pressure", Float32, ("obs",))
ncpressure.attrib["standard_name"] = "air_pressure"
ncpressure.attrib["long_name"] = "pressure level"
ncpressure.attrib["units"] = "hPa"
ncpressure.attrib["coordinates"] = "time lon lat z"

nctemperature = defVar(ds,"temperature", Float32, ("obs",))
nctemperature.attrib["standard_name"] = "surface_temperature"
nctemperature.attrib["long_name"] = "skin temperature"
nctemperature.attrib["units"] = "Celsius"
nctemperature.attrib["coordinates"] = "time lon lat z"

nchumidity = defVar(ds,"humidity", Float32, ("obs",))
nchumidity.attrib["standard_name"] = "relative_humidity"
nchumidity.attrib["long_name"] = "relative humidity"
nchumidity.attrib["units"] = "%"
nchumidity.attrib["coordinates"] = "time lon lat z"

# Global attributes

ds.attrib["featureType"] = "profile"

# Define variables

ncprofile[:] = [1,2,3]
nctime[:] = [1,1,1]
nclon[:] = [0,0,0]
nclat[:] = [0,0,0]
ncrowSize[:] = [3,2,2]
ncz[:] = [1.,2.,3.,  10.,20.,  100., 200]
ncpressure[:] = [1.,2.,3.,  10.,20.,  100., 200]
nctemperature[:] = [1.,2.,3.,  10.,20.,  100., 200]
nchumidity[:] = [1.,2.,3.,  10.,20.,  100., 200]

close(ds)


ds = Dataset(fname);
ncvar = ds["z"]
data = loadragged(ncvar,:)
@test data == [[1.,2.,3.],  [10.,20.],  [100., 200.]]
close(ds)

#rm(fname)
