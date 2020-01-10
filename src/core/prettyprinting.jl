#=
Here we define all pretty printing for all types by dispatching `show`
=#

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


function Base.show(io::IO,ds::AbstractDataset; indent="")
    try
        dspath = path(ds)
        printstyled(io, indent, "Dataset: ",dspath,"\n", color=:red)
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                print(io,"closed NetCDF Dataset")
                return
            end
        end
        rethrow
    end

    print(io,indent,"Group: ",groupname(ds),"\n")
    print(io,"\n")

    dims = collect(ds.dim)

    if length(dims) > 0
        printstyled(io, indent, "Dimensions\n",color=:red)

        for (dimname,dimlen) in dims
            print(io,indent,"   $(dimname) = $(dimlen)\n")
        end
        print(io,"\n")
    end

    varnames = keys(ds)

    if length(varnames) > 0

        printstyled(io, indent, "Variables\n",color=:red)

        for name in varnames
            show(io,variable(ds,name); indent = "$(indent)  ")
            print(io,"\n")
        end
    end

    # global attribues
    if length(ds.attrib) > 0
        printstyled(io, indent, "Global attributes\n",color=:red)
        show(io,ds.attrib; indent = "$(indent)  ");
    end

    # groups
    groupnames = keys(ds.group)

    if length(groupnames) > 0
        printstyled(io, indent, "Groups\n",color = :red)
        for groupname in groupnames
            show(io,group(ds,groupname); indent = "  ")
        end
    end

end



function Base.show(io::IO,v::AbstractVariable; indent="")
    delim = " × "
    dims =
        try
            dimnames(v)
        catch err
            if isa(err,NetCDFError)
                if err.code == NC_EBADID
                    print(io,"NetCDF variable (file closed)")
                    return
                end
            end
            rethrow
        end
    sz = size(v)

    printstyled(io, indent, name(v),color=:green)
    if length(sz) > 0
        print(io,indent," (",join(sz,delim),")\n")
        print(io,indent,"  Datatype:    ",eltype(v),"\n")
        print(io,indent,"  Dimensions:  ",join(dims,delim),"\n")
    else
        print(io,indent,"\n")
    end

    if length(v.attrib) > 0
        print(io,indent,"  Attributes:\n")
        show(io,v.attrib; indent = "$(indent)   ")
    end
end

Base.show(io::IO,v::CFVariable; indent="") = Base.show(io::IO,v.var; indent=indent)

Base.display(v::Union{Variable,CFVariable}) = show(Compat.stdout,v)
