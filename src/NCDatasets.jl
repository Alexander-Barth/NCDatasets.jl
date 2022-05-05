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

function __init__()
    println("running __init__")
    state = Ref{UInt64}(0)  # allow ocopen to write the address here
    url = ""  # don't know what this url should be, perhaps empty is fine
    flag = 10065  # CURLOPT_CAINFO
    value = ca_roots()
    @info "calling ocopen" state url
    err = @ccall(libnetcdf.ocopen(state::Ptr{Cvoid}, url::Cstring)::Int32)
    @info "calling ocset_curlopt" state flag value err
    err = @ccall(libnetcdf.ocset_curlopt(state::Ptr{Cvoid}, flag::Int32, value::Cstring)::Int32)
    println(err)
    println("finished __init__")
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
