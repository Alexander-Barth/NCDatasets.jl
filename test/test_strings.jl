using Test
using NCDatasets

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 26

v = defVar(ds,"var_string",String,("lon",))
v1 = defVar(ds,"var_string1",String,("lon",))

data = ["$(Char(Int('A')+i))" for i = 0:25]

v[:] = data

# element-wise
for i in 1:length(data)
    v1[i] = data[i]
end

close(ds)


ds = NCDataset(filename)
vs = ds["var_string"]
vs1 = ds["var_string"]

@test vs[:] == data
@test vs1[:] == data

@test vs[2:3] == data[2:3]

@test vs[2] == data[2]

# ignore additional indices
@test vs[2,1,1] == data[2,1,1]

# ignore additional indices
@test vs[2:3,1,1] == data[2:3,1,1]



close(ds)


