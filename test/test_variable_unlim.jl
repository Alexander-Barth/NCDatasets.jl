using NCDatasets
using Test

sz = (4,5)
filename = tempname()
# The mode "c" stands for creating a new file (clobber)

NCDatasets.NCDataset(filename,"c") do ds
    # define the dimension "lon" and "lat"
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = Inf

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
        local data
        data = zeros(T,sz)

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))

        for j = 1:sz[2]
            data[:,j] .= T(j)
            v[:,j] = fill(T(j), sz[1])
        end

        @test all(v[:,:] == data)

    end
end
rm(filename)

# issue #28

filename = tempname()
ds = NCDataset(filename,"c")
defDim(ds,"lon",Inf)
defDim(ds,"lat",110)
v = defVar(ds,"temperature",Float32,("lon","lat"))
data = [Float32(i+j) for i = 1:100, j = 1:110]
v[1:100,1] = data[:,1]
v[1:100,:] = data
close(ds)
rm(filename)


# issue 231

using NCDatasets
using Test
sz = (4,5,1)
filename = tempname()

for f = [:netcdf3_64bit_offset,:netcdf4]
    local ds, v
    ds = NCDataset(filename,"c",format=f)
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]
    ds.dim["time"] = Inf

    T = Float32
    v = defVar(ds,"var-$T",T,("lon","lat","time"))

    j = 1
    v[:,:,j] = fill(T(j), sz[1:2])

    @test size(v) == sz

    storage,chunksizes = NCDatasets._chunking(v)
    @test storage == :chunked
    @test chunksizes == sz
end
