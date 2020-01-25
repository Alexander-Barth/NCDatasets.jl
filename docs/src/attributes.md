## Attributes

The NetCDF dataset (as returned by `NCDataset` or NetCDF groups) and the NetCDF variables (as returned by `getindex`, `variable` or `defVar`) have the field `attrib` which has the type `NCDatasets.Attributes` and behaves like a julia dictionary.

```@docs
getindex(a::NCDatasets.Attributes,name::AbstractString)
setindex!(a::NCDatasets.Attributes,data,name::AbstractString)
keys(a::NCDatasets.Attributes)
```

Loading all attributes as a `Dict` can be achieved by passing `ds.attrib` (where `ds` is the `NCDataset`) as argument to `Dict`.

```julia
using NCDatasets
ncfile = download("https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc");
ds = NCDataset(ncfile);
attributes_as_dictionary = Dict(ds.attrib)
typeof(attributes_as_dictionary)
# returns Dict{String,Any}
```
