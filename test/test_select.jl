import Base: size, getindex, setindex!
using DataStructures
using Dates
using IntervalSets
using NCDatasets
import NCDatasets: AbstractVariable, dimnames, coordinate_value, coordinate_names
using Test

struct SelectableVariable{T,N,NT,TA} <: AbstractArray{T,N} where NT <: NTuple where TA <: AbstractArray{T,N}
    dims::NT # tuple of named tuple
    data::TA
end

export SelectableVariable

Base.size(v::SelectableVariable) = size(v.data)

Base.getindex(v::SelectableVariable,indices...) = v.data[indices...]
Base.setindex!(v::SelectableVariable,data,indices...) = (v.data[indices...] = data)

function SelectableVariable(dims,data)
    if dims isa NamedTuple
        dims = (((dim=i, values = v, name = k) for (i,(k,v)) in enumerate(pairs(dims)))...,)
    end
    #@show dims
    SelectableVariable{eltype(data),ndims(data),typeof(dims),typeof(data)}(dims,data);
end



"""
    value = coordinate_value(v::SelectableVariable,name::Symbol)

    Get the values of the coordinate names with the name `name` of the variable `v`.x
"""
function coordinate_value(v::SelectableVariable,name::Symbol)
    for d in v.dims
        if d.name == name
            return (d.values,d.dim)
        end
    end
end



"""
    symbols = coordinate_names(v::SelectableVariable)

    List of symbols with all possible coordinate names related to the
variable `v`.
"""
coordinate_names(v::SelectableVariable) = getproperty.(v.dims,:name)


lon = 1:9
data = collect(2:10)


#@macroexpand NCDatasets.@select(v,lon ≈ 7.2)
v = SelectableVariable((lon = lon,),data);

#@test coordinate_names(v) == (:lon,)
#@test coordinate_value(v,:lon) == (lon,1)


target = 7.2
a = NCDatasets.@select(v,lon ≈ 7.2)[]

a = NCDatasets.@select(v,lon ≈ $target)[]


@test data[findmin(abs.(lon .- target))[2]] == a

target = 7.2
#a = NCDatasets.@select(v,lon ≈ $target)
#@test data[findmin(abs.(lon .- target))[2]] == a



a = NCDatasets.@select(v,lon ≈ $target ± 1)[]
@test v[findmin(x -> abs(x - target),lon)[2]] == a

a = NCDatasets.select(v,:lon => NCDatasets.Near(target,1))[]
@test v[findmin(x -> abs(x - target),lon)[2]] == a

a = NCDatasets.@select(v,lon ≈ $target ± 1e-10)
@test a == []

a = NCDatasets.@select(v,lon > 7.2)
@test data[lon .> 7.2] == a

a = NCDatasets.@select(v,3 <= lon <= 7.2)
@test a == data[3 .<= lon .<= 7.2]

a = NCDatasets.@select(v,3 <= lon^2 <= 7.2)
@test a == data[3 .<= lon.^2 .<= 7.2]


a = NCDatasets.@select(v,lon <= 7.2)
@test a == data[lon .<= 7.2]


a = NCDatasets.select(v,:lon => lon -> lon <= 7.2)
@test a == data[lon .<= 7.2]

a = NCDatasets.select(v,:lon => <=(7.2))
@test a == data[lon .<= 7.2]


exp = :(lon > 10 && lat < 10 && time > 2 && lon < 20)

sub_exp = NCDatasets.split_by_and(exp)
@test length(sub_exp) == 4

exp = :(lon > 10)
sub_exp = NCDatasets.split_by_and(exp)
@test length(sub_exp) == 1



lon = 1:9
lat = 1:10
data = randn(9,10)

v = SelectableVariable((lon = lon,lat = lat),data);


a = NCDatasets.@select(v,lon <= 7.2 && lat > 0)
@test a[:] == data[(lon .<= 7.2) .& (lat' .> 0)]


a = NCDatasets.@select(v,3 <= lon <= 7.2 && 2 <= lat < 4)
@test a[:] == data[(3 .<= lon .<= 7.2) .& (2 .<= lat' .< 4)]


NCDatasets.@select(v,3 <= lon <= 7.2 && 2 <= lat < 4) .= 12
i = findfirst(3 .<= lon .<= 7.2):findlast(3 .<= lon .<= 7.2)
j = findfirst(2 .<= lat .< 4):findlast(2 .<= lat .< 4)
@test all(data[i,j] .== 12)


lonr = (3,7.2)
latr = (2,4)

a = NCDatasets.@select(v,$lonr[1] <= lon <= $lonr[2] && $latr[1] <= lat <= $latr[2])

i = findall(lonr[1] .<= lon .<= lonr[2])
j = findall(latr[1] .<= lat .<= latr[2])
@test a == data[i,j]





min_lon,max_lon = (3,7.2)
min_lat,max_lat = (2,4)


a = NCDatasets.@select(v,$min_lon <= lon <= $max_lon && $min_lat <= lat <= $max_lat)
i = findall(x -> min_lon <= x <= max_lon,lon)
j = findall(x -> min_lat <= x <= max_lat,lat)
@test a == data[i,j]



# with time


lon = 1:9
lat = 2:11

dims = (lon = lon,lat = lat, time = DateTime(2001,1):Month(1):DateTime(2001,12))
sz = ((Int(length(d)) for d in dims)...,)
data = randn(sz)

v = SelectableVariable(dims,data);


a = NCDatasets.@select(v,time ≈ DateTime(2001,12))
@test a == data[:,:,end]


a = NCDatasets.@select(v,time ≈ DateTime(2001,12,2) ± Day(1))
@test a == data[:,:,end]

a = NCDatasets.@select(v,time ≈ DateTime(2001,12,3) ± Day(1))
@test size(a,3) == 0




dims = (time = DateTime(2000,1,1):Day(1):DateTime(2009,12,31),)
sz = ((Int(length(d)) for d in dims)...,)
data = randn(sz)

v = SelectableVariable(dims,data);

a = NCDatasets.@select(v,Dates.month(time) == 1)

@test a == data[findall(time -> Dates.month(time) == 1,dims.time)]


# NetCDF

fname = "sample_file.nc"
fname = tempname()
lon = -180:180
lat = -90:90
time = DateTime(2000,1,1):Day(1):DateTime(2000,1,3)
SST = randn(length(lon),length(lat),Int(length(time)))

NCDataset(fname,"c") do ds
    defVar(ds,"lon",lon,("lon",));
    defVar(ds,"lat",lat,("lat",));
    defVar(ds,"time",time,("time",));
    defVar(ds,"SST",SST,("lon","lat","time"));
    defVar(ds,"unrelated",time,("time123",));
end


ds = NCDataset(fname,"r")

v = ds["SST"]
coord_value,dim_number = coordinate_value(v,:lon)
@test coord_value == lon
@test dim_number == 1


@test coordinate_names(ds["SST"]) == [:lon, :lat, :time]
v = NCDatasets.@select(ds["SST"],30 <= lon <= 60)

ilon = findall(x -> 30 <= x <= 60,ds["lon"])
v2 = ds["SST"][ilon,:,:]
@test v == v2


v = NCDatasets.@select(ds["SST"],time ≈ DateTime(2000,1,4));
i = findmin(x -> abs.(DateTime(2000,1,4) - x),time)[2]
@test v == ds["SST"][:,:,i]

v = NCDatasets.@select(ds["SST"],time ≈ DateTime(2000,1,3,1) ± Hour(2))
i = findmin(x -> abs.(DateTime(2000,1,3,1) - x),time)[2]
@test v == ds["SST"][:,:,i]



v = NCDatasets.@select(ds["SST"],30 <= lon <= 60 && 40 <= lat <= 90)

ilon = findall(x -> 30 <= x <= 60,ds["lon"])
ilat = findall(x -> 40 <= x <= 90,ds["lat"])
v2 = ds["SST"][ilon,ilat,:]
@test v == v2


lonr = 30..60
latr = ClosedInterval(40, 90) # latitude range
v = NCDatasets.@select(ds["SST"], lon ∈ $lonr && lat in $latr)
ilon = findall(x -> 30 <= x <= 60,ds["lon"])
ilat = findall(x -> 40 <= x <= 90,ds["lat"])
v2 = ds["SST"][ilon,ilat,:]
@test v == v2

v = NCDatasets.@select(ds["SST"], lon ∈ $(30..60) && lat ∈ $(65 ± 25))
ilon = findall(x -> 30 <= x <= 60,ds["lon"])
ilat = findall(x -> 40 <= x <= 90,ds["lat"])
v2 = ds["SST"][ilon,ilat,:]
@test v == v2


v = NCDatasets.@select(ds["SST"], lon ∈ 30..60 && lat ∈ 65 ± 25)
ilon = findall(x -> 30 <= x <= 60,ds["lon"])
ilat = findall(x -> 40 <= x <= 90,ds["lat"])
v2 = ds["SST"][ilon,ilat,:]
@test v == v2


in_lon_range(lon) = 30 <= lon <= 60
v = NCDatasets.@select(ds["SST"], in_lon_range(lon))
ilon = findall(in_lon_range,ds["lon"])
v2 = ds["SST"][ilon,:,:]
@test v == v2


v = NCDatasets.@select(ds["SST"],lon ≈ 3 && lat ≈ 6)

ilon = findmin(x -> abs(x-3),ds["lon"])[2]
ilat = findmin(x -> abs(x-6),ds["lat"])[2]
v2 = ds["SST"][ilon,ilat,:]
@test v == v2


v = NCDatasets.@select(ds["SST"],lon ≈ 3 && lat ≈ 6 && time ≈ DateTime(2000,1,4) ± Day(1))[]

ilon = findmin(x -> abs(x-3),ds["lon"])[2]
ilat = findmin(x -> abs(x-6),ds["lat"])[2]
v2 = ds["SST"][ilon,ilat,end]
@test v == v2

ds_subset = NCDatasets.SubDataset(ds,(lon = 1:3,))
@test ds_subset.dim["lon"] == 3

ds_subset = view(ds; lon = 1:3)
@test ds_subset.dim["lon"] == 3

ds_subset = NCDatasets.@select(ds,30 <= lon <= 60 && 40 <= lat <= 90)
@test all(x -> 30 <= x <= 60,ds_subset["lon"][:])
@test all(x -> 40 <= x <= 90,ds_subset["lat"][:])


fname = "sample_series.nc"
fname = tempname()
time = DateTime(2000,1,1):Day(1):DateTime(2009,12,31)
salinity = randn(Int(length(time))) .+ 35
temperature = Vector{Union{Float64,Missing}}(randn(Int(length(time))))
temperature[end] = missing

NCDataset(fname,"c") do ds
    defVar(ds,"time",time,("time",));
    defVar(ds,"salinity",salinity,("time",));
    defVar(ds,"temperature",temperature,("time",));
end


ds = NCDataset(fname)
v = NCDatasets.@select(ds["temperature"],Dates.month(time) == 1 && salinity >= 35)

v2 = ds["temperature"][findall((Dates.month.(time) .== 1) .& (salinity .>= 35))]
@test v == v2

# only values which are missing
v_subset = NCDatasets.@select(ds,ismissing(temperature))
@test v_subset.dim["time"] == 1

close(ds)




using NCDatasets, Printf, Dates

function url(dt)
    array = rand(1:99,360,181)
    fname = tempname()
    NCDataset(fname,"c") do ds
        # Dimensions

        ds.dim["lon"] = size(array,1)
        ds.dim["lat"] = size(array,2)
        ds.dim["time"] = Inf

        # Declare variables

        ncvar = defVar(ds,"data", Float64, ("lon", "lat", "time"),
                       fillvalue = -9999)
        nclat = defVar(ds,"lat", Float64, ("lat",))
        nclon = defVar(ds,"lon", Float64, ("lon",))
        nctime = defVar(ds,"time", Float64, ("time",), attrib = OrderedDict(
            "units" => "days since 2000-01-01 00:00:00",
        ))

        nctime[1] = dt
        nclon[:] = 0:359
        nclat[:] = -90:90
        ncvar[:,:,1:size(array,3)] = array
    end
    return fname
end


fname_subset = tempname()
times = DateTime(1992,1,1):Dates.Day(1):DateTime(1992,1,3)
ds = NCDataset(url.(times),aggdim = "time",deferopen=false);
ds_subset = NCDatasets.@select(ds,30 <= lon <= 60 && 40 <= lat <= 90)
write(fname_subset,ds_subset)
close(ds)

ds = NCDataset(fname_subset)
@test all(lon -> 30 <= lon <= 60,ds["lon"][:])
@test all(lat -> 40 <= lat <= 90,ds["lat"][:])
close(ds)


# issue 196

using NCDatasets, Dates

time = DateTime(1000,1,1):Dates.Day(1):DateTime(2000,1,1)
data = 1:length(time)

fname = tempname()
NCDataset(fname,"c") do ds
    defVar(ds,"time",time,("time",))
    defVar(ds,"data",data,("time",))
end

data1 = NCDataset(fname) do ds
    NCDatasets.@select(ds["data"],Dates.month(time) == 1)[:]
end;

@test data[Dates.month.(time) .== 1] == data1

ds = NCDataset(fname)
ds1 = NCDatasets.@select(ds,Dates.month(time) == 1)
outfname = tempname()
write(outfname,ds1)
close(ds)

ds = NCDataset(outfname)
@test all(Dates.month.(ds["time"][:]) .== 1)
close(ds)

ds = NCDataset(fname)
data1 = NCDatasets.@select(ds["data"],Dates.month(time) == 1)
t = data1["time"][:]
@test all(Dates.month.(t) .== 1)
close(ds)
