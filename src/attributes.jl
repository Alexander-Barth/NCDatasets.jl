# `Attributes` is a collection of named attributes


"Return all attribute names"
function listAtt(ncid,varid)
    natts = nc_inq_varnatts(ncid,varid)
    names = Vector{String}(undef,natts)

    for attnum = 0:natts-1
        names[attnum+1] = nc_inq_attname(ncid,varid,attnum)
    end

    return names
end


attribnames(ds::Union{AbstractNCDataset,AbstractNCVariable}) = keys(ds.attrib)
attrib(ds::Union{AbstractNCDataset,AbstractNCVariable},name::SymbolOrString) = ds.attrib[name]

function Base.get(a::BaseAttributes, name::SymbolOrString,default)
    if haskey(a,name)
        return a[name]
    else
        return default
    end
end


"""
    getindex(a::Attributes,name::SymbolOrString)

Return the value of the attribute called `name` from the
attribute list `a`. Generally the attributes are loaded by
indexing, for example:

```julia
ds = NCDataset("file.nc")
title = ds.attrib["title"]
```
"""
function Base.getindex(a::Attributes,name::SymbolOrString)
    return nc_get_att(a.ds.ncid,a.varid,name)
end


function defAttrib(ds::Dataset,name::SymbolOrString,data)
    defmode(ds) # make sure that the file is in define mode
    return nc_put_att(ds.ncid,NC_GLOBAL,name,data)
end


"""
    Base.setindex!(a::Attributes,data,name::SymbolOrString)

Set the attribute called `name` to the value `data` in the
attribute list `a`. `data` can be a vector or a scalar. A scalar
is handeld as a vector with one element in the NetCDF data model.

Generally the attributes are defined by indexing, for example:

```julia
ds = NCDataset("file.nc","c")
ds.attrib["title"] = "my title"
close(ds)
```

If `data` is a string, then attribute is saved as a list of
NetCDF characters (`NC_CHAR`) with the appropriate length. To save the attribute
as a string (`NC_STRING`) you can use the following:

```julia
ds = NCDataset("file.nc","c")
ds.attrib["title"] = ["my title"]
close(ds)
```


"""
function Base.setindex!(a::Attributes,data,name::SymbolOrString)
    defmode(a.ds) # make sure that the file is in define mode
    return nc_put_att(a.ds.ncid,a.varid,name,data)
end

"""
    Base.keys(a::Attributes)

Return a list of the names of all attributes.
"""
Base.keys(a::Attributes) = listAtt(a.ds.ncid,a.varid)


"""
    Base.haskey(a::Attributes,name)

Check if name is an attribute
"""
Base.haskey(a::Attributes{NCDataset},name::SymbolOrString) = _nc_has_att(a.ds.ncid,a.varid,name)


"""
    Base.delete!(a::Attributes, name)

Delete the attribute `name` from the attribute list `a`.
"""
function Base.delete!(a::Attributes,name::SymbolOrString)
    defmode(a.ds)
    nc_del_att(a.ds.ncid,a.varid,name)
    return nothing
end

Base.show(io::IO, a::BaseAttributes) = CommonDataModel.show_attrib(io,a)
