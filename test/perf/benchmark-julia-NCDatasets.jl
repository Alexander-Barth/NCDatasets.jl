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

function process(fname,drop_caches)
    if drop_caches
        # drop file caches; requires root
        write("/proc/sys/vm/drop_caches","3")
    end

    ds = NCDataset(fname,"r") do ds
        v = ds["v1"];
        tot = compute(v)
        return tot
    end
end

drop_caches = "--drop-caches" in ARGS
println("Julia ",VERSION)
println("drop caches: ",drop_caches)

fname = "filename_fv.nc"
tot = process(fname,drop_caches)
println("result ",tot)

bm = run(@benchmarkable process(fname,drop_caches) samples=100 seconds=10000)

@show bm

open("julia-NCDatasets.txt","w") do f
    for t in bm.times
        println(f,t/1e9)
    end
end
