using Missings

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 10
ds.dim["lat"] = 11

v = NCDatasets.defVar(ds,"var_with_missing_data",Float32,("lon","lat"))

data = [Float32(i+j) for i = 1:10, j = 1:11]
fv = NCDatasets.NC_FILL_FLOAT
v.attrib["_FillValue"] = fv
# mask the frist element
datam = Array{Union{Float32,Missing}}(data)
datam[1] = missing

v[:,:] = datam
@test ismissing(v[1,1])
@test isequal(v[:,:],datam)

# load without transformation
@test v.var[1,1] == fv

# write/read without transformation
v.var[:,:] = data
@test v.var[:,:] ≈ data

NCDatasets.close(ds)


sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat" 
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [Float32]
        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"); fillvalue = 124)
        v[:,:] = fill(T(123),size(v))
        @test all(v[:,:][:] .== 123)

        @test NCDatasets.fillvalue(v) == 124
        @test NCDatasets.fillmode(v) == (false,124)

    end
end


# NaN as fillvalue


filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 10
ds.dim["lat"] = 11

v = NCDatasets.defVar(ds,"var_with_missing_data",Float32,("lon","lat"))

data = [Float32(i+j) for i = 1:10, j = 1:11]
fv = NaN32
v.attrib["_FillValue"] = fv
# mask the frist element
datam = Array{Union{Float32,Missing}}(data)
datam[1] = missing

v[:,:] = datam
@test ismissing(v[1,1])
@test isequal(v[:,:],datam)

# load without transformation
@test isnan(v.var[1,1])

NCDatasets.close(ds)

# all fill-values
filename = tempname()
ds = NCDatasets.Dataset(filename,"c")
ds.dim["lon"] = 3
v = NCDatasets.defVar(ds,"var_with_all_missing_data",Float32,("lon",))

data = [missing, missing, missing]
v.attrib["_FillValue"] = fv

v[:] = data
@test all(ismissing.(v[:]))

NCDatasets.close(ds)

# test nomissing

data = [missing, Float64(1.), Float64(2.)]
@test_throws ErrorException NCDatasets.nomissing(data)

dataf = NCDatasets.nomissing(data,-9999.)
@test eltype(dataf) == Float64
@test dataf == [-9999., 1., 2.]


data = Union{Float64,Missing}[1., 2.]
dataf = NCDatasets.nomissing(data)
@test eltype(dataf) == Float64
@test dataf == [1., 2.]

@test nomissing(Union{Int64,Missing}[]) == []
