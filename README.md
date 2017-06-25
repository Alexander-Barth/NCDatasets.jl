# NCDatasets

[![Build Status](https://travis-ci.org/Alexander-Barth/NCDatasets.jl.svg?branch=master)](https://travis-ci.org/Alexander-Barth/NCDatasets.jl)

[![Coverage Status](https://coveralls.io/repos/Alexander-Barth/NCDatasets.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/Alexander-Barth/NCDatasets.jl?branch=master)

[![codecov.io](http://codecov.io/github/Alexander-Barth/NCDatasets.jl/coverage.svg?branch=master)](http://codecov.io/github/Alexander-Barth/NCDatasets.jl?branch=master)


`NCDatasets` allows to read and create NetCDF files.
NetCDF data set and attribute list behaviour like Julia dictionaries and variables like Julia Arrays.

However, unlike Julia dictionaries, the order of the attributes and variables is preserved as they a stored in the netCDF file.

For interactive use, the following (without ending semicolon) 
displays the content of the file similar to `ncdump -h file.nc"

```julia
ds = NCDatasets.Dataset("file.nc")
```

The following displays the information just for the variable `varname` and the global attributes:

```julia
ds["varname"]
ds.attrib
```

Support for NetCDF CF Convention:
* _FillValue will be returned as NA (DataArrays)
* `scale_factor` and `add_offset` are applied
* time variables (recognised by the `units` attribute) are returned as `DateTime` object.

The raw data can also be accessed (without the transformation above can also be accessed).





# Credits

`netcdf_c.jl`, `build.jl` and the error handling code of the NetCDF C API are from NetCDF.jl by Fabian Gans (Max-Planck-Institut für Biogeochemie, Jena, Germany) released under the MIT license.
