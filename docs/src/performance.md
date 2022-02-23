# [Performance tips](@id performance_tips)

* Reading data from a file is not type-stable, because the type of the output of the read operation does depedent on the type defined in the NetCDF files and the value of various attribute (like `scale_factor`, `add_offset` and `units` for time conversion). All this information cannot be inferred from a static analysis of the source code. It is therefore recommended to use [type annotation](https://docs.julialang.org/en/v1/manual/types/index.html#Type-Declarations-1) if resulting type of a read operation in known:

```julia
ds = NCDataset("file.nc")
nctemp = ds["temp"]
temp = nctemp[:,:] :: Array{Float64,2}
# or
# call_barrier_function(nctemp)
# call_barrier_function(temp)
close(ds)
```

Alternatively, one can also use so called "[function barriers](https://docs.julialang.org/en/v1/manual/performance-tips/index.html#kernel-functions-1)" or the in-place `NCDatasets.load!` function (which is unexported, so it has to be prefixed with the module name):

```julia
ds = NCDataset("file.nc")

temp = zeros(10,20)
NCDatasets.load!(variable(ds,"temp"),temp,:,:)
```

* Most julia functions (like `mean`, `sum`,... from the module Statistics) access an array element-wise. It is generally much faster to load the data in memory (if possible) to make the computation.

```julia
using NCDatasets, BenchmarkTools, Statistics
ds = NCDataset("file.nc","c")
data = randn(100,100);
defVar(ds,"myvar",data,("lon","lat"))
close(ds)

ds = NCDataset("file.nc")
@btime mean(ds["myvar"]) # takes 107.357 ms
@btime mean(ds["myvar"][:,:]) # takes 106.873 μs, 1000 times faster
close(ds)
```

* Avoid when possible indexing with arrays and `CartesianIndex` as they also result in loading the data element-wise.

```julia
ds = NCDataset("dataset.nc");
v = ds["v1"][:,[1,2,3],:]; # slow
v = ds["v1"][:,1:3,:]; # fast
v = ds["v1"][:,:,CartesianIndex(1)] # slow
v = ds["v1"][:,:,1] # fast
close(ds)
```
