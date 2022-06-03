
using NCDatasets
using NCDatasets: subsub, SubDataset
using DataStructures
using Test

@test subsub((1:10,),(2:10,)) == (2:10,)
@test subsub((2:10,),(2:9,)) == (3:10,)
@test subsub((2:2:10,),(2:3,)) == (4:2:6,)
@test subsub((:,),(2:4,)) == (2:4,)
@test subsub((2:2:10,),(3,)) == (6,)
@test subsub((2:2:10,:),(2:3,2:4)) == (4:2:6,2:4)
@test subsub((2:2:10,:),(2:3,2)) == (4:2:6,2)
@test subsub((1,:),(2:3,)) == (1,2:3)
@test subsub((1,:),(1,)) == (1,1)

A = rand(10,10)
ip = (2:2:10,:)
i = (2:3,2:4)
j = subsub(ip,i)
A[ip...][i...] == A[j...]



fname = tempname()

ds = NCDataset(fname,"c", attrib = OrderedDict(
    "title"                     => "title",
));

# Dimensions

ds.dim["lon"] = 10
ds.dim["lat"] = 11

# Declare variables

nclon = defVar(ds,"lon", Float64, ("lon",), attrib = OrderedDict(
    "long_name"                 => "Longitude",
    "standard_name"             => "longitude",
    "units"                     => "degrees_east",
))

nclat = defVar(ds,"lat", Float64, ("lat",), attrib = OrderedDict(
    "long_name"                 => "Latitude",
    "standard_name"             => "latitude",
    "units"                     => "degrees_north",
))

ncvar = defVar(ds,"bat", Float32, ("lon", "lat"), attrib = OrderedDict(
    "long_name"                 => "elevation above sea level",
    "standard_name"             => "height",
    "units"                     => "meters",
    "_FillValue"                => Float32(9.96921e36),
))


# Define variables

data = rand(Float32,10,11)

nclon[:] = 1:10
nclat[:] = 1:11
ncvar[:,:] = data



@test Array(view(ncvar,1:3,1:4)) == Array(view(data,1:3,1:4))

list_indices = [(:,:),(1:3,2:3),(2,:),(2,2:3),(1:3:10,2:3)]

for indices = list_indices
    local v
    local ncvar2
    ncvar2 = ncvar[indices...]
    v = view(ncvar,indices...);

    @test size(v) == size(ncvar2)
    @test Array(v) == ncvar2
end

ncvar2 = ncvar[:,2][1:2]
v = view(view(ncvar,:,2),1:2)

@test ncvar2 == v

data_view = view(view(data,:,1:2),1:2:6,:)
ncvar_view = view(view(ncvar,:,1:2),1:2:6,:)

@test data_view == Array(ncvar_view)
@test data_view == ncvar_view

ind = CartesianIndex(1,1)
@test ncvar_view[ind] == data_view[ind]

ind = CartesianIndices((1:2,1:2))
@test ncvar_view[ind] == data_view[ind]


@test ncvar[:,1:2][1:2:6,:] == Array(view(ncvar,:,1:2)[1:2:6,:])

ind = CartesianIndices((1:2,1:2))

@test ncvar[:,1:2][ind] == Array(view(ncvar,:,1:2)[ind])


# writing to a view

vdata = view(data,2:3,3:4)
vdata[2,:] = [1,1]

vncvar = view(ncvar,2:3,3:4)
vncvar[2,:] = [1,1]

@test data == collect(ncvar)

io = IOBuffer()
show(io,view(ncvar,:,:));
@test occursin("elevation",String(take!(io)))

# subset of dataset

indices = (lon = 3:4, lat = 1:3)

sds = SubDataset(ds,indices)
@test size(sds["lon"]) == (2,)
@test size(sds["lat"]) == (3,)
@test size(sds["bat"]) == (2,3)

@test sds["bat"][2,2] == ds["bat"][4,2]

@test "lon" in keys(sds)

indices = (lon = 1:2,)
sds = SubDataset(ds,indices)
@test size(sds["lon"]) == (2,)
@test size(sds["lat"]) == (11,)
@test size(sds["bat"]) == (2,11)
@test sds.dim["lon"] == 2
@test sds.dim["lat"] == 11

io = IOBuffer()
show(io,sds);
@test occursin("lon = 2",String(take!(io)))


@test dimnames(view(ncvar,:,1)) == ("lon",)

close(ds)
