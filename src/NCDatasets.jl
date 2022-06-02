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

import Base: Array, close, collect, convert, delete!, display, filter, getindex,
    parent, parentindices, setindex!, show, showerror, size, view
using CFTime
using DataStructures: OrderedDict
using Dates
using NetCDF_jll
using NetworkOptions
using Printf


export CFTime
export daysinmonth, daysinyear, yearmonthday, yearmonth, monthday
export dayofyear, firstdayofyear
export DateTimeStandard, DateTimeJulian, DateTimeProlepticGregorian,
    DateTimeAllLeap, DateTimeNoLeap, DateTime360Day, AbstractCFDateTime

function __init__()
    value = ca_roots()
    if value == nothing
        return
    end

    key = "HTTP.SSL.CAINFO"
    hostport = C_NULL
    path = C_NULL
    err = @ccall(libnetcdf.NC_rcfile_insert(key::Cstring, value::Cstring, hostport::Cstring, path::Cstring)::Int32)
    @debug "NC_rcfile_insert returns $err"

    if err != NC_NOERR
        @warn "setting HTTP.SSL.CAINFO using NC_rcfile_insert " *
            "failed with error $err. See https://github.com/Alexander-Barth/NCDatasets.jl/issues/173 for more information. "

        @debug begin
            lookup = @ccall(libnetcdf.NC_rclookup(key::Cstring, hostport::Cstring, path::Cstring)::Cstring)

            if lookup !== C_NULL
                @debug "NC_rclookup: ",unsafe_string(lookup)
            else
                @debug "NC_rclookup result pointer: ",lookup
            end
        end
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
include("subvariable.jl")
include("cfconventions.jl")
include("defer.jl")
include("multifile.jl")
include("ncgen.jl")
include("select.jl")
include("precompile.jl")

export CatArrays

end # module
