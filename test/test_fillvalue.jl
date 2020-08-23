using NCDatasets
using Test

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.NCDataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 10
ds.dim["lat"] = 11

fv = fillvalue(Float32)

v = NCDatasets.defVar(ds,"var_with_missing_data",Float32,("lon","lat"), fillvalue = fv)

data = [Float32(i+j) for i = 1:10, j = 1:11]
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

NCDatasets.NCDataset(filename,"c") do ds

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
ds = NCDatasets.NCDataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
ds.dim["lon"] = 10
ds.dim["lat"] = 11

fv = NaN32
v = NCDatasets.defVar(ds,"var_with_missing_data",Float32,("lon","lat"), fillvalue = fv)

data = [Float32(i+j) for i = 1:10, j = 1:11]
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
ds = NCDatasets.NCDataset(filename,"c")
ds.dim["lon"] = 3

v = NCDatasets.defVar(ds,"var_with_all_missing_data",Float32,("lon",), fillvalue = fv)
data = [missing, missing, missing]

v[:] = data
@test all(ismissing.(v[:]))

v[1] = 1234.
@test !ismissing(v[1])

v[1] = missing
@test ismissing(v[1])

v[1] = 1234.
v[1:1] .= missing
@test ismissing(v[1])

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


@test nomissing([1,2,3,4],-9999) == [1,2,3,4]
@test nomissing([missing,2,3,4],-9999) == [-9999,2,3,4]

# issue 39
using NCDatasets

filename = tempname()

NCDataset(filename, "c") do ds
    defDim(ds, "lon", 2)
    defDim(ds, "lat", 2)
    v = defVar(ds, "Char variable", Char, ("lon","lat"), fillvalue = ' ')
    v[:,:] = ['a' 'b'; 'c' 'd']
end

NCDataset(filename, "r") do ds
    @test ds["Char variable"][:,:] == ['a' 'b'; 'c' 'd']
end

rm(filename)


# String fillvalues

filename = tempname()
ds = Dataset(filename,"c")
defDim(ds, "mode_items", 10)
v = defVar(ds,"instrument_mode",String,("mode_items",),
       attrib = Dict("_FillValue" => "UNDEFINED MODE"))

@test fillvalue(v) == "UNDEFINED MODE"
close(ds)
rm(filename)


filename = tempname()
ds = Dataset(filename,"c")
defDim(ds, "mode_items", 10)
v = defVar(ds,"instrument_mode",String,("mode_items",),fillvalue = "UNDEFINED MODE")
@test fillvalue(v) == "UNDEFINED MODE"
close(ds)
rm(filename)
