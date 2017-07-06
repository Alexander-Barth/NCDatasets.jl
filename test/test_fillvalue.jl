filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
defDim(ds,"lon",10)
defDim(ds,"lat",11)

v = defVar(ds,"var_with_missing_data",Float32,("lon","lat"))

data = [Float32(i+j) for i = 1:10, j = 1:11]
fv = Float32(-9999.)
v.attrib["_FillValue"] = fv
# mask the frist element
dataa = DataArray(data,data .== 2)


v[:,:] = dataa
@test isna(v[1,1])
@test isequal(v[:,:],dataa)

# load without transformation
@test v.var[1,1] == fv

# write/read without transformation
v.var[:,:] = data
@test v.var[:,:] ≈ data

close(ds)
