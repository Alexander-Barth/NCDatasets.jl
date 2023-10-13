# Variables

Variables (like e.g. `CFVariable`) are the quantities contained within a NetCDF dataset. See the [Datasets](@ref) page on how to obtain them from a dataset.

Different type of arrays are involved when working with NCDatasets. For instance assume that `test.nc` is a file with a `Float32` variable called `var`. Assume that we open this data set in append mode (`"a"`):

```julia
using NCDatasets
ds = NCDataset("test.nc","a")
v_cf = ds["var"]
```

The variable `v_cf` has the type `CFVariable`. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, etc., using the functions `size`, `ndims`, `length` as if `v_cf` was an ordinary Julia array.

To load the variable `v_cf` in memory as numeric data you can convert it into an array (preserving its dimensionality structure) with
```julia
Array(v_cf)
```

Since NCDatasets 0.13, the syntax `v_cf[:]` flattens the array, and is not equivalent with the above (unless `v_cf` is a vector).


You can only load sub-parts of it in memory via indexing each dimension:
```julia
v_cf[1:5, 10:20]
```
(here you must know the number of dimensions of the variable, as you must access all of them). A scalar variable can be loaded using `[]`, for example:

``` julia
using NCDatasets
NCDataset("test_scalar.nc","c") do ds
    defVar(ds,"scalar",42,())
end

ds = NCDataset("test_scalar.nc")
value = ds["scalar"][] # 42
```



!!! note
    `NCDatasets.Variable` and `NCDatasets.CFVariable` implement the interface of `AbstractArray`. It is thus possible to call any function that accepts an `AbstractArray`. But functions like `mean`, `sum` (and many more) would load every element individually which is very inefficient for large fields read from disk. You should instead convert such a variable to a standard Julia `Array` and then do computations with it. See also the [performance tips](@ref performance_tips) for more information.


The following functions are convenient for working with variables:

```@docs
Base.size(v::NCDatasets.CFVariable)
dimnames
dimsize
name
renameVar
NCDataset(var::NCDatasets.CFVariable)
nomissing
fillvalue
```

```@docs
loadragged
NCDatasets.load!
```
## Creating a variable

```@docs
defVar
```

## Storage parameter of a variable

```@docs
chunking
deflate
checksum
```


## Coordinate variables and cell boundaries

```@docs
coord
bounds
```
