"""
NCDatasets is a module to read and write NetCDF files.
This is minimal example how to read a NetCDF file.

```julia
using NCDatasets
# open the file and show its metadata (if called in the REPL without ending semicolon)
ds = NCDataset("filename.nc","r")
# load all data of the variable temperature
v = ds["temperature"][:,:]
# load the attribute units
unit = v.attrib["units"]
# close the file
close(ds)
```

More information is available at https://github.com/Alexander-Barth/NCDatasets.jl .
"""
module NCDatasets
using Dates
using Printf

using Base
using DataStructures: OrderedDict
import Base.convert

import Base: close
import Base: Array

using CFTime
export CFTime
export daysinmonth, daysinyear, yearmonthday, yearmonth, monthday
export dayofyear, firstdayofyear
export DateTimeStandard, DateTimeJulian, DateTimeProlepticGregorian,
    DateTimeAllLeap, DateTimeNoLeap, DateTime360Day, AbstractCFDateTime

const default_timeunits = "days since 1900-00-00 00:00:00"

include("CatArrays.jl")
export CatArrays

include("errorhandling.jl") # error checking from NetCDF.jl
include("netcdf_c.jl") # writting files from NetCDF.jl
include("dataset.jl")
include("attributes.jl")
include("dimensions.jl")
include("groupes.jl")
include("variable.jl")
include("cfvariable.jl")
include("cfconventions.jl")
include("defer.jl")
include("multifile.jl")
include("ncgen.jl")

# it is good practise to use the default fill-values, thus we export them
export NC_FILL_BYTE, NC_FILL_CHAR, NC_FILL_SHORT, NC_FILL_INT, NC_FILL_FLOAT,
    NC_FILL_DOUBLE, NC_FILL_UBYTE, NC_FILL_USHORT, NC_FILL_UINT, NC_FILL_INT64,
    NC_FILL_UINT64, NC_FILL_STRING




end # module
