using NCDatasets, DataStructures

fname = "filename_fv.nc"

if isfile(fname)
    rm(fname)
end

ds = NCDataset(fname,"c")

# Dimensions

sz = (1000,500,100)

ds.dim["longitude"] = sz[1]
ds.dim["latitude"] = sz[2]
ds.dim["time"] = sz[3]

# Declare variables

ncv1 = defVar(ds,"v1", UInt8, ("longitude", "latitude", "time"), fillvalue = UInt8(255), attrib = [
    "add_offset"                => -1.0,
    "scale_factor"              => 0.5,
])


# Define variables

for n = 1:sz[3]
    @show n
    ncv1[:,:,n] = rand(1:100,sz[1],sz[2])
    ncv1[:,1,n] = missing
end

close(ds)
