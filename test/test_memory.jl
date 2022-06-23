using NCDatasets
using Dates
using Test
using NCDatasets: NC_NOWRITE, nc_open_mem

fname = tempname()
lon = -180:180
lat = -90:90
time = DateTime(2000,1,1):Day(1):DateTime(2000,1,3)
SST = randn(length(lon),length(lat),length(time))

ds = NCDataset(fname,"c")
defVar(ds,"lon",lon,("lon",));
defVar(ds,"lat",lat,("lat",));
defVar(ds,"time",time,("time",));
defVar(ds,"SST",SST,("lon","lat","time"));
close(ds)



memory = read(fname)

ds = NCDataset("some_string","r",memory = memory)
SST2 = ds["SST"][:,:,:]

@test path(ds) == "some_string"
@test SST == SST2


