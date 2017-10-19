import NCDatasets

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 26

v = NCDatasets.defVar(ds,"var_string",String,("lon",))

data = ["$(Char(Int('A')+i))" for i = 0:25]



v[:] = data
NCDatasets.close(ds)


ds = NCDatasets.Dataset(filename)
vs = ds["var_string"].var

@test vs[:] == data

@test vs[2:3] == data[2:3]

@test vs[2] == data[2]

# ignore additional indices
@test vs[2,1,1] == data[2,1,1]

# ignore additional indices
@test vs[2:3,1,1] == data[2:3,1,1]



NCDatasets.close(ds)


