sz = (4,5)
filename = tempname()

# Create a simple dataset with some attributes to the variables
ds = Dataset(filename,"c")

nlon = 120;
nlat = 50;
# Define the dimension "lon" and "lat" with the size 100 and 110 resp.
defDim(ds,"lon",nlon)
defDim(ds,"lat",nlat)

# Define a variable
lon = defVar(ds,"lon",Float32,("lon",))
lat= defVar(ds,"lat",Float32,("lat",))
# create two variables with the same standard name
vort = defVar(ds,"vort",Float32,("lon","lat"))
vort2 = defVar(ds,"vort2",Float32,("lon","lat"))

# write attributes
lon.attrib["standard_name"] = "longitude"
lat.attrib["standard_name"] = "latitude"
vort.attrib["units"] = "s^-1"
vort.attrib["standard_name"] = "ocean_relative_vorticity"
vort2.attrib["standard_name"] = "ocean_relative_vorticity"

close(ds)

# Single variables by standard name or units
@test var_by_att(filename, "standard_name", "longitude") == ["lon"]
@test var_by_att(filename, "standard_name", "latitude") == ["lat"]
@test var_by_att(filename, "units", "s^-1") == ["vort"]

# Two variables with the same attribute
@test length(var_by_att(filename, "standard_name", "ocean_relative_vorticity")) == 2
@test var_by_att(filename, "standard_name", "ocean_relative_vorticity")[1] == "vort"

# Empty result
@test length(var_by_att(filename, "standard_name", "time")) == 0

# File that does not exist
@test_throws NCDatasets.NetCDFError var_by_att(filename * "diva", "standard_name", "longitude")

# Bad input types (not Strings)
@test_throws MethodError var_by_att("test.nc", 1, "lon")
@test_throws MethodError var_by_att("test.nc", "standard_name", 12.2)

rm(filename)
