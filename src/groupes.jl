############################################################
# Groups
############################################################
"""
    Base.keys(g::NCDatasets.Groups)

Return the names of all subgroubs of the group `g`.
"""
function Base.keys(g::Groups)
    return String[nc_inq_grpname(ncid)
                  for ncid in nc_inq_grps(g.ncid)]
end


"""
    group = getindex(g::NCDatasets.Groups,groupname::AbstractString)

Return the NetCDF `group` with the name `groupname`.
For example:

```julia-repl
julia> ds = NCDataset("results.nc", "r");
julia> forecast_group = ds.group["forecast"]
julia> forecast_temp = forecast_group["temperature"]
```

"""
function Base.getindex(g::Groups,groupname::AbstractString)
    grp_ncid = nc_inq_grp_ncid(g.ncid,groupname)
    return NCDataset(grp_ncid,g.isdefmode; parentdataset = g.ds)
end

"""
    defGroup(ds::NCDataset,groupname, attrib = []))

Create the group with the name `groupname` in the dataset `ds`.
`attrib` is a list of attribute name and attribute value pairs (see `NCDataset`).
"""
function defGroup(ds::NCDataset,groupname; attrib = [])
    grp_ncid = nc_def_grp(ds.ncid,groupname)
    ds = NCDataset(grp_ncid,ds.isdefmode; parentdataset = ds)

    # set global attributes for group
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end
export defGroup

group(ds::AbstractDataset,groupname) = ds.group[groupname]

"""
    groupname(ds::NCDataset)
Return the group name of the NCDataset `ds`
"""
groupname(ds::NCDataset) = nc_inq_grpname(ds.ncid)
export groupname
