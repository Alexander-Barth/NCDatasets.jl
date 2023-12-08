sz = (4,5)
filename = tempname()

# Create a simple dataset with some attributes to the variables
ds = NCDataset(filename,"c")

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

ds = NCDataset(filename,"r")

# Single variables by standard name or units
@test name.(varbyattrib(ds, standard_name = "longitude")) == ["lon"]
@test name.(varbyattrib(ds, standard_name = "latitude")) == ["lat"]
@test name.(varbyattrib(ds, units = "s^-1")) == ["vort"]

# Two variables with the same attribute
@test length(varbyattrib(ds, standard_name = "ocean_relative_vorticity")) == 2
@test name(varbyattrib(ds, standard_name = "ocean_relative_vorticity")[1]) == "vort"

# Empty result
@test varbyattrib(ds, standard_name = "time") == []

# Bad input types (not Strings)
#@test_throws MethodError varbyattrib("test.nc", 1, "lon")
#@test_throws MethodError varbyattrib("test.nc", "standard_name", 12.2)

close(ds)
rm(filename)
