"""
    ncvar = NCDatasets.ancillaryvariables(ncv::NCDatasets.CFVariable,modifier)

Return the first ancillary variables from the NetCDF variable `ncv` with the
standard name modifier `modifier`. It can be used for example to access
related variable like status flags.
"""
function ancillaryvariables(ncv::NCDatasets.CFVariable,modifier)
    ds = Dataset(ncv)
    varname = name(ncv)

    if !haskey(ncv.attrib,"ancillary_variables")
        return nothing
    end

    ancillary_variables = split(ncv.attrib["ancillary_variables"])

    for j = 1:length(ancillary_variables)
        ncv_ancillary = ds[ancillary_variables[j]]
        if occursin(modifier,ncv_ancillary.attrib["standard_name"])
            @debug ancillary_variables[j]
            return ncv_ancillary
        end
    end

    # nothing found
    return nothing
end

import Base: filter
"""
    data = NCDatasets.filter(ncv, indices...; accepted_status_flags = nothing)

Load and filter observations by replacing all variables without an acepted status
flag to `missing`. It is used the attribute `ancillary_variables` to identify
the status flag.

```
# da["data"] is 2D matrix
good_data = NCDatasets.filter(ds["data"],:,:, accepted_status_flags = ["good_data","probably_good_data"])
```

"""
function filter(ncv::Union{Variable,CFVariable}, indices...; accepted_status_flags = nothing)
#function filter_(ncv, indices...)
#    accepted_status_flags = ("good_value", "probably_good_value")
    data = ncv[indices...];

    if (accepted_status_flags != nothing)
        ncv_ancillary = ancillaryvariables(ncv,"status_flag");
        if ncv_ancillary == nothing
            error("no variable with the attribute status_flag as standard_name among $(ancillary_variables) found")
        end

        flag_values = ncv_ancillary.attrib["flag_values"]
        flag_meanings = ncv_ancillary.attrib["flag_meanings"]::String
        if typeof(flag_meanings) <: AbstractString
            flag_meanings = split(flag_meanings)
        end

        accepted_status_flag_values = zeros(eltype(flag_values),length(accepted_status_flags))
        for i = 1:length(accepted_status_flags)
            tmp = findfirst(accepted_status_flags[i] .== flag_meanings)

            if tmp == nothing
                error("cannot recognise flag $(accepted_status_flags[i])")
            end
            accepted_status_flag_values[i] = flag_values[tmp]
        end
        #@debug accepted_status_flag_values

        dataflag = ncv_ancillary.var[indices...];
        for i in eachindex(data)
            good = false;
            for accepted_status_flag_value in accepted_status_flag_values
                good = good || (dataflag[i] .== accepted_status_flag_value)
            end
            if !good
                #@show i,dataflag[i]
                data[i] = missing
            end
        end
    end

    return data
end


"""
    cv = coord(v::Union{CFVariable,Variable},standard_name)

Find the coordinate of the variable `v` by the standard name `standard_name`
or some [standardized heuristics based on units](https://web.archive.org/web/20190918144052/http://cfconventions.org/cf-conventions/cf-conventions.html#latitude-coordinate). If the heuristics fail to detect the coordinate,
consider to modify the netCDF file to add the `standard_name` attribute.
All dimensions of the coordinate must also be dimensions of the variable `v`.

## Example
```julia
using NCDatasets
ds = Dataset("file.nc")
ncv = ds["SST"]
lon = coord(ncv,"longitude")[:]
lat = coord(ncv,"latitude")[:]
v = ncv[:]
close(ds)
```
"""
function coord(v::Union{CFVariable,Variable},standard_name)
    matches = Dict(
        "time" => [r".*since.*"],
        # It is great to have choice!
        # https://web.archive.org/web/20190918144052/http://cfconventions.org/cf-conventions/cf-conventions.html#latitude-coordinate
        "longitude" => [r"degree east",r"degrees east",r"degrees_east",
                        r"degree_east", r"degree_E", r"degrees_E",
                        r"degreeE", r"degreesE"],
        "latitude" => [r"degree north",r"degrees north",r"degrees_north",
                       r"degree_north", r"degree_N", r"degrees_N", r"degreeN",
                       r"degreesN"],
    )

    ds = Dataset(v)
    dims = Set(dimnames(v))

    # find by standard name
    for coord in varbyattrib(ds,standard_name = standard_name)
        if Set(dimnames(coord))  ⊆ dims
            return coord
        end
    end

    # find by units
    if haskey(matches,standard_name)
        # prefer e.g. vectors over scalars
        # this is necessary for ROMS model output
        coordfound = nothing
        coordndims = -1

        for (_,coord) in ds
            units = get(coord.attrib,"units","")

            for re in matches[standard_name]
                if match(re,units) != nothing
                    if Set(dimnames(coord)) ⊆ dims
                        if ndims(coord) > coordndims
                            coordfound = coord
                            coordndims = ndims(coord)
                        end
                    end
                end
            end
        end

        return coordfound
    end

    return nothing
end

export coord
