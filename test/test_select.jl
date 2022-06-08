using Test
using Dates
using NCDatasets
import Base: size, getindex, setindex!
using NCDatasets: AbstractVariable

#using NCDatasets: scan_exp, scan_coordinate_name, split_by_and, coordinate_value, coordinate_names, @select
import NCDatasets: coordinate_value, coordinate_names

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


function scan_exp!(exp::Symbol,varnames,found)
    if exp in varnames
        push!(found,exp)
    end
    return found
end

function scan_exp!(exp::Expr,varnames,found)
    for i = 1:length(exp.args)
        scan_exp!(exp.args[i],varnames,found)
    end
    return found
end

function scan_exp!(exp,varnames,found)
    # do nothing
end


scan_exp(exp::Expr,varnames) = scan_exp!(exp::Expr,varnames,Symbol[])


function scan_coordinate_name(exp,coordinate_names)
    params = scan_exp(exp,coordinate_names)
    #println("dn",coordinate_names)
    #println("pp",params)
    if length(params) != 1
        error("Multiple (or none) coordinates in expression $exp ($params) while looking for $(coordinate_names).")
    end
    param = params[1]
    return param
end


function split_by_and!(exp,sub_exp)
    if exp.head == :&&
        split_by_and!(exp.args[1],sub_exp)
        split_by_and!(exp.args[2],sub_exp)
    else
        push!(sub_exp,exp)
    end
    return sub_exp
end



split_by_and(exp) = split_by_and!(exp,[])

_intersect(r1::AbstractVector,r2::AbstractVector) = intersect(r1,r2)
_intersect(r1::AbstractVector,r2::Number) = (r2 in r1 ? r2 : [])
_intersect(r1::Number,r2::Number) = (r2 == r1 ? r2 : [])
_intersect(r1::Colon,r2) = r2
_intersect(r1::Colon,r2::AbstractRange) = r2




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

a = NCDatasets.@select(v,lon ≈ $target ± 1e-10)
@test a == []

a = NCDatasets.@select(v,lon > 7.2)
@test data[lon .> 7.2] == a

a = NCDatasets.@select(v,3 <= lon^2 <= 7.2)
@test a == data[3 .<= lon.^2 .<= 7.2]


a = NCDatasets.@select(v,lon <= 7.2)
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
sz = ((length(d) for d in dims)...,)
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
SST = randn(length(lon),length(lat),length(time))

NCDataset(fname,"c") do ds
    defVar(ds,"lon",lon,("lon",));
    defVar(ds,"lat",lat,("lat",));
    defVar(ds,"time",time,("time",));
    defVar(ds,"SST",SST,("lon","lat","time"));
    defVar(ds,"unrelated",time,("time123",));
end


ds = NCDataset(fname,"r")

v = ds["SST"]
coord_value,dim = coordinate_value(v,:lon)
@test coord_value == lon
@test dim == 1


@test coordinate_names(ds["SST"]) == [:lon, :lat, :time]
v = nothing
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


fname = "sample_series.nc"
fname = tempname()
time = DateTime(2000,1,1):Day(1):DateTime(2009,12,31)
salinity = randn(length(time)) .+ 35
temperature = randn(length(time))

NCDataset(fname,"c") do ds
    defVar(ds,"time",time,("time",));
    defVar(ds,"salinity",salinity,("time",));
    defVar(ds,"temperature",temperature,("time",));
end


ds = NCDataset(fname)
v = NCDatasets.@select(ds["temperature"],Dates.month(time) == 1 && salinity >= 35)

v2 = ds["temperature"][findall((Dates.month.(time) .== 1) .& (salinity .>= 35))]
@test v == v2
close(ds)

