using NCDatasets
using Test
using Downloads: download


fname = download("https://github.com/GeospatialPython/Learn/raw/master/tos_O1_2001-2002.nc")

ds = NCDataset(fname)
ncvar = ds["tos"]

@test isequal(ncvar[:,:,:][2:4,1:3,1],ncvar[2:4,1:3,1])
@test ncvar[:,:,:][1,11,1] == ncvar[1,11,1]

close(ds)
