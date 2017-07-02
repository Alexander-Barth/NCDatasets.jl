filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
defDim(ds,"lon",10)
defDim(ds,"lat",11)

v = defVar(ds,"scaled_var",Float32,("lon","lat"))

data = [Float32(i+j) for i = 1:10, j = 1:11]
offset = 1
factor = 2
v.attrib["add_offset"] = offset
v.attrib["scale_factor"] = factor

v[:,:] = data
@test v[:,:] ≈ data

# load without transformation (offset/scaling)
@test v.var[:,:] ≈ (data-offset)/factor

# write/read without transformation (offset/scaling)
v.var[:,:] = data
@test v.var[:,:] ≈ data

close(ds)
