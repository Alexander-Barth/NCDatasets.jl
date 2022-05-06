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

using NetworkOptions
using NetCDF_jll
using Dates
using Printf
using Scratch

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

const NCRC = Ref{String}()

function __init__()
    ca_path = ca_roots()
    if ca_path !== nothing
        dir = get_scratch!(NetCDF_jll, "config")
        path = joinpath(dir, ".ncrc")
        ENV["NCRCENV_RC"] = path
        NCRC[] = path
        content = string("HTTP.SSL.CAINFO=", ca_path)
        write(path, content)
    end
end

const default_timeunits = "days since 1900-00-00 00:00:00"

const SymbolOrString = Union{Symbol, AbstractString}

include("CatArrays.jl")
include("types.jl")
include("colors.jl")
include("errorhandling.jl")
include("netcdf_c.jl")
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
include("precompile.jl")

export CatArrays

end # module
