using NCDatasets
if VERSION >= v"0.7.0-beta.0"
    using Test
    using Dates
    using Printf
else
    using Base.Test
end

using Compat
using BenchmarkTools

sz = (400,400)
data = randn(sz)

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = Dataset(filename,"c")

# define the dimension "lon" and "lat"
defDim(ds,"lon",sz[1])
defDim(ds,"lat",sz[2])

T = Float64
v = defVar(ds,"var-$T",T,("lon","lat"))
# write array
v[:,:] = data
close(ds)

function sequential_access!(filename,diskless,d)
    sz = size(d)
    ds = Dataset(filename,"r", diskless = true)
    v = ds["var-Float64"]

    for j = 1:sz[2]
        for i = 1:sz[1]
            d[i,j] = v[i,j]
        end
    end

    close(ds)
end


function random_access!(filename,diskless,d)
    sz = size(d)
    ds = Dataset(filename,"r", diskless = diskless)
    v = ds["var-Float64"]

    for I in Random.shuffle(CartesianIndices(sz)[:])
        d[I] = v[I]
    end
    close(ds)
end


d = similar(data)

for diskless in [false,true]
    println("sequential access, diskless=$(diskless)")
    @btime sequential_access!($filename,$diskless,$d)
    @test data == d

    println("random access, diskless=$(diskless)")
    @btime random_access!($filename,$diskless,$d)
    @test data == d
end
