"""
    escape(val)

Escape backslash, dollar and quote from string `val`.
"""
function escape(val)
     valescaped = val
     # backslash must come first
     for c in ['\\','$','"']
        valescaped = replace(valescaped,c => "\\$c")
    end
	return valescaped
end


function ncgen(io::IO,fname; newfname = "filename.nc")
    ds = NCDataset(fname)
    unlimited_dims = unlimited(ds.dim)

    print(io,"ds = NCDataset(\"$(escape(newfname))\",\"c\", attrib = [\n")
    ncgen_setattrib(io,ds.attrib)
    print(io,"])\n\n")

    print(io,"# Dimensions\n\n")
    for (d,v) in ds.dim
        if d in unlimited_dims
            print(io,"ds.dim[\"$d\"] = Inf # unlimited dimension\n")
        else
            print(io,"ds.dim[\"$d\"] = $v\n")
        end
    end

    print(io,"\n# Declare variables\n\n")

    for (d,v) in ds
        print(io,"nc$d = defVar(ds,\"$d\", $(eltype(v.var)), $(dimnames(v)), attrib = [\n")
        ncgen_setattrib(io,v.attrib)
        print(io,"])\n\n")
    end

    print(io,"\n# Define variables\n\n")

    for d in keys(ds)
        print(io,"# nc$d[:] = ...\n")
    end

    print(io,"\nclose(ds)\n")
    close(ds)
end


"""
    ncgen(fname; ...)
    ncgen(fname,jlname; ...)

Generate the Julia code that would produce a NetCDF file with the same metadata
as the NetCDF file `fname`. The code is placed in the file `jlname` or printed
to the standard output. By default the new NetCDF file is called `filename.nc`.
This can be changed with the optional parameter `newfname`.
"""
ncgen(fname; kwargs...)  = ncgen(Compat.stdout,fname; kwargs...)

function ncgen(fname,jlname; kwargs...)
    open(jlname,"w") do io
        ncgen(io, fname; kwargs...)
    end
end

litteral(val::String) = "\"$(escape(val))\""
litteral(val::Float32) = "$(eltype(val))($(val))"
litteral(val) = val

function ncgen_setattrib(io,attrib)
    for (d,val) in attrib
        litval = litteral(val)
        print(io,"    \"$d\"" * (" "^max(0,(25-length(d)))) * " => $litval,\n");
    end
end

