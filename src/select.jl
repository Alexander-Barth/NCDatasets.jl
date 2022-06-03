
function scan_exp!(exp::Symbol,varnames,found)
    if exp in varnames
        push!(found,exp)
    end
    return found
end

function scan_exp!(exp::Expr,varnames,found)
    for i = 1:length(exp.args)
        scan_exp!(exp.args[i],varnames,found)
    end
    return found
end

function scan_exp!(exp,varnames,found)
    # do nothing
end


scan_exp(exp::Expr,varnames) = scan_exp!(exp::Expr,varnames,Symbol[])


function scan_coordinate_name(exp,coordinate_names)
    params = scan_exp(exp,coordinate_names)

    if length(params) != 1
        error("Multiple (or none) coordinates in expression $exp ($params) while looking for $(coordinate_names).")
    end
    param = params[1]
    return param
end


function split_by_and!(exp,sub_exp)
    if exp.head == :&&
        split_by_and!(exp.args[1],sub_exp)
        split_by_and!(exp.args[2],sub_exp)
    else
        push!(sub_exp,exp)
    end
    return sub_exp
end

split_by_and(exp) = split_by_and!(exp,[])

_intersect(r1::AbstractVector,r2::AbstractVector) = intersect(r1,r2)
_intersect(r1::AbstractVector,r2::Number) = (r2 in r1 ? r2 : [])
_intersect(r1::Number,r2::Number) = (r2 == r1 ? r2 : [])
_intersect(r1::Colon,r2) = r2
_intersect(r1::Colon,r2::AbstractRange) = r2


"""
    vsubset = NCDatasets.@select(v,expression)

Return a subset of the variable `v` following the condition `expression` as a view. The condition
has the following form:

`condition1 && condition2 && condition3 ... conditionN `

Every condition should involve a single 1D NetCDF variable (typically a coordinate variable, referred as `coord` below)
and should have a shared dimension with the variable `v`. All local variables (including local functions) need to have a \$ prefix (see examples below) as the condition is evaluated in the scope of the module NCDatasets[^1]. This macro is highly experimental and subjected to change.

Every condition can either perform:

* a nearest match: `coord ≈ target_coord`. Only the data corresponding to the index closest to `target_coord` is loaded.

* a nearest match with tolerance: `coord ≈ target_coord ± tolerance`. As before, but if the difference between the closest value in `coord` and `target_coord` is larger (in absolute value) than `tolerance`, an empty array is returned.

* a condition operating on scalar values. For example, a `condition` equal to `10 <= lon <= 20` loads all data with the longitude between 10 and 20 or `abs(lat) > 60` loads all variables with a latitude north of 60° N and south of 60° S (assuming that the NetCDF has the 1D variables `lon` and `lat` for longitude and latitude).

Only the data which satisfies all conditions is loaded. All conditions must be chained with an `&&` (logical and). They should not contain additional parenthesis or other logical operators such as `||` (logical or).

To convert the view into a regular array one can use `collect` or `Array` for arrays.
As in julia, views of scalars are wrapped into a zero dimensional arrays which can be dereferenced by using `[]`. Modifying a view will modify the underlying NetCDF file (if
the file is opened as writable).

As for any view, one can use `parentindices(vsubset)` to get the indices matching a select query.

## Examples

Create a sample file with random data:

```julia
using NCDatasets, Dates
fname = "sample_file.nc"
lon = -180:180
lat = -90:90
time = DateTime(2000,1,1):Day(1):DateTime(2000,1,3)
SST = randn(length(lon),length(lat),length(time))

ds = NCDataset(fname,"c")
defVar(ds,"lon",lon,("lon",));
defVar(ds,"lat",lat,("lat",));
defVar(ds,"time",time,("time",));
defVar(ds,"SST",SST,("lon","lat","time"));


# load by bounding box
v = NCDatasets.@select(ds["SST"],30 <= lon <= 60 && 40 <= lat <= 90)

# substitute a local variable in condition using \$
lonr = (30,60) # longitude range
latr = (40,90) # latitude range

v = NCDatasets.@select(v,\$lonr[1] <= lon <= \$lonr[2] && \$latr[1] <= lat <= \$latr[2])

# get the indices matching a select query
(lon_indices,lat_indices,time_indices) = parentindices(v)

# find the nearest time instance
v = NCDatasets.@select(ds["SST"],time ≈ DateTime(2000,1,4))

# find the nearest time instance but not earlier or later than 2 hours
# an empty array is returned if no time instance is present

v = NCDatasets.@select(ds["SST"],time ≈ DateTime(2000,1,3,1) ± Hour(2))

# Note DateTime and Hour do not need to a \$ prefix because NCDataset imports
# the modules Dates and CFTime.

close(ds)
```

Any 1D variable with the same dimension name can be used in `@select`. For example,
if we have a time series of temperature and salinity, the temperature values
can also be selected based on salinity:

```julia
# create a sample time series
using NCDatasets, Dates
fname = "sample_series.nc"
time = DateTime(2000,1,1):Day(1):DateTime(2009,12,31)
salinity = randn(length(time)) .+ 35
temperature = randn(length(time))

NCDataset(fname,"c") do ds
    defVar(ds,"time",time,("time",));
    defVar(ds,"salinity",salinity,("time",));
    defVar(ds,"temperature",temperature,("time",));
end

ds = NCDataset(fname)

# load all temperature data from January where the salinity is larger than 35.
v = NCDatasets.@select(ds["temperature"],Dates.month(time) == 1 && salinity >= 35)

# this is equivalent to
v2 = ds["temperature"][findall(Dates.month.(time) .== 1 .&& salinity .>= 35)]

@test v == v2
close(ds)
```



!!! note

    For optimal performance, one should try to load contiguous data ranges, in
    particular when the data is loaded over HTTP/OPeNDAP.

[^1]: Please file an [issue](https://github.com/Alexander-Barth/NCDatasets.jl/issues/) if you know a better solution.
"""
macro select(v,expression)
    expression_list = split_by_and(expression)
    code = [
        quote
            coord_names = coordinate_names($(esc(v)))
            indices = Any[Colon() for _ in 1:ndims($(esc(v)))]
        end
    ]

    # loop over all sub-expressions separated by &&
    for e in expression_list
        exp2 = Meta.quot(e)
        push!(code,
              quote
                  exp = $(esc(exp2)) # with $ $values are replaced
                  #exp = $(exp2) # good without $
              param = scan_coordinate_name(exp,coord_names)
              coord,j = coordinate_value($(esc(v)),param)
              end)

        if (e.head == :call) && (e.args[1] == :≈)
            # target = e.args[3]
            # tolerance = nothing

            # if (hasproperty(target,:head) &&
            #     (target.head == :call) && (target.args[1] == :±))
            #     value,tolerance = target.args[2:end]
            # else
            #     value = target
            #     #error("unable to understand $e")
            # end

            push!(code,
                  quote
                  #value = $(esc(value)) # good without $
                  target = exp.args[3] # good with $
                  tolerance = nothing
                  if (hasproperty(target,:head) &&
                      (target.head == :call) && (target.args[1] == :±))
                      value,tolerance = target.args[2:end]
                      tolerance = eval(tolerance)
                  else
                      value = target
                  end

                  value = eval(value)
                  diff, ind = findmin(x -> abs(x - value),coord)

                  if (tolerance != nothing) && (diff > tolerance)
                      ind = Int[]
                  end
                  indices[j] = _intersect(indices[j],ind)
                  end)
        elseif (e.head == :comparison) || (
            (e.head == :call) && (e.args[1] in (:>,:>=,:<,:<=,:(==)) ))

            # only without $
            #e2 = copy(e)
            #e2.args[3] = :x
            #fun = Expr(:->,:x,e2)

            push!(code,
                  quote
                  #fun = $(esc(fun)) # only without $
                  fun = eval(Expr(:->,param,exp)) # only with $
                  ind = findall(fun,coord)
                  indices[j] = _intersect(indices[j],ind)
                  end)
        else
            error("cannot parse expression $e")
        end
    end

    push!(code,:(view($(esc(v)),indices...)))
    return Expr(:block,code...)
end




function coordinate_value(v::AbstractVariable,name_coord::Symbol)
    ncv = NCDataset(v)[name_coord]
    @assert ndims(ncv) == 1
    dimension_name = dimnames(ncv)[1]
    i = findfirst(==(dimension_name),dimnames(v))
    fmtd(v) = join(dimnames(v),"×")

    if i == nothing
        error("$name_coord (dimensions: $(fmtd(ncv))) and $(name(v)) (dimensions: $(fmtd(v))) do not share a named dimension")
    end
    return Array(ncv),i
end


function coordinate_names(v::AbstractVariable)
    ds = NCDataset(v)
    dimension_names = dimnames(v)

    return [Symbol(varname) for (varname,ncvar) in ds
     if (ndims(ncvar) == 1) && dimnames(ncvar) ⊆ dimension_names]
end

#  LocalWords:  params vsubset conditionN NetCDF coord NCDatasets lon
#  LocalWords:  julia dereferenced parentindices fname nc DateTime ds
#  LocalWords:  randn NCDataset defVar lonr latr CFTime OPeNDAP args
#  LocalWords:  hasproperty esc Expr fmtd ncv
