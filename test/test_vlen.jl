import NCDatasets

filename = tempname()
#@show filename

dimlen = 10

T = Int32
data = Vector{Vector{T}}(undef,dimlen)
for i = 1:length(data)
    data[i] = T.(collect(1:i) .+ 100 * i) 
end


varname = "varname"
vlentypename = "name-vlen"

# write data

ds = NCDatasets.Dataset(filename,"c",format=:netcdf4)
ds.dim["casts"] = dimlen
v = NCDatasets.defVar(ds,varname,Vector{T},("casts",); typename = vlentypename)
@test eltype(v.var) == Vector{T}

#for i = 1:dimlen
#    v.var[i] = data[i]
#end
v.var[:] = data
v.var[1] = data[1]
v.var[1:dimlen] = data[1:dimlen]

close(ds)


# load data

ds = NCDatasets.Dataset(filename)
vv = NCDatasets.variable(ds,"varname")
@test eltype(vv) == Vector{T}
data2 = vv[:]

@test data == data2
@test data[1] == vv[1]
@test data[2] == vv[2]
@test data[1:2] == vv[1:2]


NCDatasets.close(ds)

#@show data
#@show data2
