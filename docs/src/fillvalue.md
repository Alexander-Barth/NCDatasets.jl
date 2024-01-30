
# Fill values and missing values

In the NetCDF [CF conventions](https://cfconventions.org/Data/cf-conventions/cf-conventions-1.11/cf-conventions.html#missing-data) there are the attributes `_FillValue` (single scalar)  and `missing_value` (single scalar or possibly a vector with multiple missing values).
While missing values are represented as a special [`Missing` type](https://docs.julialang.org/en/v1/manual/missing/) in Julia, for some application it is more convenient to use another special value like the special floating point number `NaN`.
For example:


```julia
using NCDatasets
data = [1. 2. 3.; missing 20. 30.]
ds = NCDataset("example.nc","c")
defVar(ds,"var",data,("lon","lat"),fillvalue = 9999.)
```

Get the raw data as stored in the NetCDF file:

```julia
ds["var"].var[:,:]
# 2×3 Matrix{Float64}:
#     1.0   2.0   3.0
#  9999.0  20.0  30.0
```

Get the data using CF transformation, in particular the fill value is replaced by `missing`:

```julia
ds["var"][:,:]
# 2×3 Matrix{Union{Missing, Float64}}:
# 1.0        2.0   3.0
#  missing  20.0  30.0
```

The function `nomissing` allows to replace all missing value with a different values:

```julia
var_nan = nomissing(ds["var"][:,:],NaN)
# 2×3 Matrix{Float64}:
#   1.0   2.0   3.0
#  NaN    20.0  30.0
close(ds)
```

Such substitution can also be made more automatically using the experimental parameter` maskingvalue` that can be user per variable:


```julia
ds = NCDataset("example.nc","r")
ncvar_nan = cfvariable(ds,"var",maskingvalue = NaN)
ncvar_nan[:,:]
# 2×3 Matrix{Float64}:
#   1.0   2.0   3.0
# NaN    20.0  30.0
close(ds)
```

Or per data-set:

```julia
ds = NCDataset("example.nc","r", maskingvalue = NaN)
ds["var"][:,:]
# 2×3 Matrix{Float64}:
#   1.0   2.0   3.0
# NaN    20.0  30.0
close(ds)
```

Note choosing the `maskingvalue` affects the element type of the NetCDF variable using julia type promotion rules, in particular note that following vector:


```julia
[1, NaN]
# 2-element Vector{Float64}:
#    1.0
#  NaN
```

is a vector with the element type `Float64` and not `Union{Float64,Int}`. All integers
are thus promoted to floating point number as `NaN` is a `Float64`.

Note that since NaN is considered as a `Float64` in Julia, we have also a promotion to `Float64` in such cases:

```julia
[1f0, NaN]
# 2-element Vector{Float64}:
#   1.0
# NaN
```

where `1f0` is the `Float32` number 1. Consider to use `NaN32` to avoid this promotion (which is automatically converted to 64-bit NaN for a `Float64` array):

```julia
using NCDatasets
data32 = [1f0 2f0 3f0; missing 20f0 30f0]
data64 = [1. 2. 3.; missing 20. 30.]
ds = NCDataset("example_float32_64.nc","c")
defVar(ds,"var32",data32,("lon","lat"),fillvalue = 9999f0)
defVar(ds,"var64",data64,("lon","lat"),fillvalue = 9999.)
close(ds)

ds = NCDataset("example_float32_64.nc","r", maskingvalue = NaN32)
ds["var32"][:,:]
# 2×3 Matrix{Float32}:
#   1.0   2.0   3.0
# NaN    20.0  30.0

ds["var64"][:,:]
# 2×3 Matrix{Float64}:
#   1.0   2.0   3.0
# NaN    20.0  30.0
```

## Precision when converting integers to floats

Promoting an integer to a floating point number can lead to loss of precision. These are the smallest integers that cannot be represented as 32 and 64-bit floating numbers:

```julia
Float32(16_777_217) == 16_777_217 # false
Float64(9_007_199_254_740_993) == 9_007_199_254_740_993 # false
```

The use of `missing` as fill value, is thus preferable generally.
