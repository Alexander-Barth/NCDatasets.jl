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


function Base.get(a::BaseAttributes, name::AbstractString,default)
    if haskey(a,name)
        return a[name]
    else
        return default
    end
end


"""
    getindex(a::Attributes,name::AbstractString)

Return the value of the attribute called `name` from the
attribute list `a`. Generally the attributes are loaded by
indexing, for example:

```julia
ds = NCDataset("file.nc")
title = ds.attrib["title"]
```
"""
function Base.getindex(a::Attributes,name::AbstractString)
    return nc_get_att(a.ds.ncid,a.varid,name)
end


"""
    Base.setindex!(a::Attributes,data,name::AbstractString)

Set the attribute called `name` to the value `data` in the
attribute list `a`. Generally the attributes are defined by
indexing, for example:

```julia
ds = NCDataset("file.nc","c")
ds.attrib["title"] = "my title"
```
"""
function Base.setindex!(a::Attributes,data,name::AbstractString)
    defmode(a.ds.ncid,a.ds.isdefmode) # make sure that the file is in define mode
    return nc_put_att(a.ds.ncid,a.varid,name,data)
end

"""
    Base.keys(a::Attributes)

Return a list of the names of all attributes.
"""
Base.keys(a::Attributes) = listAtt(a.ds.ncid,a.varid)


function Base.show(io::IO, a::BaseAttributes; indent = "  ")
    try
        # use the same order of attributes than in the NetCDF file
        for (attname,attval) in a
            print(io,indent,@sprintf("%-20s = ",attname))
            printstyled(io, @sprintf("%s",attval),color=:blue)
            print(io,"\n")
        end
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                print(io,"NetCDF attributes (file closed)")
                return
            end
        end
        rethrow
    end
end
