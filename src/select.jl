export select


"""
    select(v::Variable; dimensions_to_limits...)
Select the subset of the variable `v` by keeping the values of
each of the given dimension that are between the corresponding limits.
Return a _view_ into `v`, which retains its type (i.e. again a `Variable`,
not an `Array` like `getindex`.

This function is called like
```julia
select(v; lat = (-90, 0), lon = (0, 180))
```
each keyword denotes a dimension to index into, and select values of `v` along
that dimension that satisfy `lower ≤ value ≤ upper`. Notice that for
`select` the values given to each keyword represent true numeric values of
the dimensions and not integers (see [`iselect`](@ref) for that).
There for you could also use syntax like `time = (Date("2015"), Date("2016"))`
if one of your dimensions has a value that is `Date`.

Currently this function assumes sorted dimensions for the variable.
"""
function select(v; d...)
    dnames = string.(keys(d))
    limits = values(values(d))
    #use dnames and limits to make something like a SubArray but for Variable
end
