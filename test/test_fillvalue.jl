using DataArrays

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
dataa = DataArray(data,data .== 2)


v[:,:] = dataa
@test ismissing(v[1,1])
@test isequal(v[:,:],dataa)

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
dataa = DataArray(data,data .== 2)

v[:,:] = dataa
@test ismissing(v[1,1])
@test isequal(v[:,:],dataa)

# load without transformation
@test isnan(v.var[1,1])


NCDatasets.close(ds)

