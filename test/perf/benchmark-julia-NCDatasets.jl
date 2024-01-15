using NCDatasets
using Statistics
using BenchmarkTools

function compute(v)
    tot = zero(eltype(v))

    for n = 1:size(v,3)
        slice = v[:,:,n]
        partial_sum = maximum(skipmissing(slice))
        tot += partial_sum
    end
    return tot/size(v,3)
end

function process(fname)
    # drop file caches; requires root
    write("/proc/sys/vm/drop_caches","3")

    ds = NCDataset(fname,"r") do ds
        v = ds["v1"];
        tot = compute(v)
        return tot
    end
end

fname = "filename_fv.nc"
tot = process(fname)

println("result ",tot)

bm = run(@benchmarkable process(fname) samples=100 seconds=10000)

@show bm

open("julia-NCDatasets.txt","w") do f
    for t in bm.times
        println(f,t/1e9)
    end
end
