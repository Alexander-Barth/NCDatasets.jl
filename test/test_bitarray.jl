using NCDatasets

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 10
ds.dim["lat"] = 11

v = defVar(ds,"var_with_missing_data",UInt8,("lon","lat"))

data = trues(10,11)

# previously we got an infinite recursion
v[1:10,1:11] = data
@test Bool.(v[:,:]) ≈ data

v[:,:] = data
@test Bool.(v[:,:]) ≈ data

v[:] = data
@test Bool.(v[:,:]) ≈ data

close(ds)
