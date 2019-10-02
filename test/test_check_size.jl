using NCDatasets
using Test

filename = tempname()

ds = Dataset(filename,"c")
x = collect(1:10)
defVar(ds, "x", x, ("x",))
defDim(ds, "Time", Inf)
sync(ds)
defVar(ds, "Time", Float64, ("Time",))

defVar(ds, "a", Float64, ("x", "Time"))
defVar(ds, "u", Float64, ("x", "Time"))
defVar(ds, "v", Float64, ("x", "Time"))
defVar(ds, "w", Float64, ("x", "Time"))

for i in 1:10
    ds["Time"][i] = i
    ds["a"][:,i] = 1
    @test_throws NCDatasets.NetCDFError ds["u"][:,i] = collect(1:9)
    @test_throws NCDatasets.NetCDFError ds["v"][:,i] = collect(1:11)
    @test_throws NCDatasets.NetCDFError ds["w"][:,i] = reshape(collect(1:20), 10, 2)

    # ignore singleton dimension
    ds["w"][:,i] = reshape(collect(1:10), 1, 1, 10, 1)
end

ds["w"][:,:] = ones(10,10)

# w should grow along the unlimited dimension
ds["w"][:,:] = ones(10,15)
@test size(ds["w"]) == (10,15)

# w cannot grow along a fixed dimension
@test_throws NCDatasets.NetCDFError ds["w"][:,:] = ones(11,15)

# NetCDF: Index exceeds dimension bound
@test_throws NCDatasets.NetCDFError ds["u"][100,100]
close(ds)
