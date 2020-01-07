# Variables
Variables (like e.g. `CFVariable`) are the quantities contained within a NetCDF dataset. See the [Datasets](@ref) page on how to obtain them from a dataset.

Different type of arrays are involved when working with NCDatasets. For instance assume that `test.nc` is a file with a `Float32` variable called `var`. Assume that we open this data set in append mode (`"a"`):

```julia
using NCDatasets
ds = Dataset("test.nc","a")
v_cf = ds["var"]
```

The variable `v_cf` has the type `CFVariable`. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, etc., using the functions `size`, `ndims`, `length` as if `v_cf` was an ordinary Julia array.

To load the variable `v_cf` in memory as numeric data you can convert it into an array with e.g.
```julia
Array(v_cf) # the syntax v_cf[:] does the same, it doesn't make a vector
```
or, you can only load sub-parts of it in memory via indexing each dimension:
```julia
v_cf[1:5, 10:20]
```


The following functions are convenient for working with variables:

```@docs
dimnames
name
nsize
loadragged
NCDatasets.load!
```

## Dimensions
Dimensions are the dependent variables of a dataset (the ones with respect a `Variable` is defined). They are obtained with using [`dimnames`](@ref) on a `Variable`. We have the following functions relevant to them:

```@docs
setindex!(d::NCDatasets.Dimensions,len,name::AbstractString)
unlimited(d::NCDatasets.Dimensions)
```

## Internals of a variable
```@docs
chunking
deflate
checksum
```

## Creating a variable/dimension
```@doc
defDim
defVar
```

## Coordinate variables
```@docs
coord
```