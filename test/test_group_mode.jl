using NCDatasets

# issue #96

filename = tempname()

ds = Dataset(filename, "c")

data = defGroup(ds, "data")
st = defGroup(data, "stats")

defDim(data,"n_levels",10)
defDim(data,"n_fov",5)
defDim(data,"n_for",4)
defDim(data,"n_lines",2)

defVar(st, "air_temperature", Float32, ("n_levels","n_fov","n_for","n_lines"))

close(ds)


ds = Dataset(filename, "a")
data = ds.group["data"]
oe = defGroup(data, "optimal_estimation")

defVar(oe, "other_variable", Float32, ("n_levels","n_fov","n_for","n_lines"))

@test "other_variable" in keys(oe)

close(ds)

rm(filename)
