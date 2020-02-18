#=
Core type definitions for the `NCDataset` struct,
the `Attributes` and `Group` parts as well.
and the `Attributes` part of it.
Helper functions defined for these as well.

High-level interface is at the "High-level" section about actually
loading/reading/making datasets.
=#

############################################################
# Type definitions
############################################################
# -----------------------------------------------------
# base type of attributes list
# concrete types are Attributes (single NetCDF file) and
# MFAttributes (multiple NetCDF files)

abstract type BaseAttributes
end

abstract type AbstractDataset
end


abstract type AbstractDimensions
end

abstract type AbstractGroups
end



# -----------------------------------------------------
# List of attributes (for a single NetCDF file)
# all ids should be Cint

mutable struct Attributes <: BaseAttributes
    ncid::Cint
    varid::Cint
    isdefmode::Vector{Bool}
end

mutable struct Groups <: AbstractGroups
    ncid::Cint
    isdefmode::Vector{Bool}
end

mutable struct Dimensions <: AbstractDimensions
    ncid::Cint
    isdefmode::Vector{Bool}
end

mutable struct NCDataset <: AbstractDataset
    ncid::Cint
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be an array, so that it is copied by reference
    isdefmode::Vector{Bool}
    attrib::Attributes
    dim::Dimensions
    group::Groups
end

"Alias to `NCDataset`"
const Dataset = NCDataset

const NCIterable = Union{BaseAttributes,AbstractDimensions,AbstractDataset,AbstractGroups}
Base.length(a::NCIterable) = length(keys(a))


############################################################
# Mappings
############################################################

# Mapping between NetCDF types and Julia types
const jlType = Dict(
    NC_BYTE   => Int8,
    NC_UBYTE  => UInt8,
    NC_SHORT  => Int16,
    NC_USHORT => UInt16,
    NC_INT    => Int32,
    NC_UINT   => UInt32,
    NC_INT64  => Int64,
    NC_UINT64 => UInt64,
    NC_FLOAT  => Float32,
    NC_DOUBLE => Float64,
    NC_CHAR   => Char,
    NC_STRING => String
)

# Inverse mapping
const ncType = Dict(value => key for (key, value) in jlType)

"""
    fillvalue(::Type{Int8})
    fillvalue(::Type{UInt8})
    fillvalue(::Type{Int16})
    fillvalue(::Type{UInt16})
    fillvalue(::Type{Int32})
    fillvalue(::Type{UInt32})
    fillvalue(::Type{Int64})
    fillvalue(::Type{UInt64})
    fillvalue(::Type{Float32})
    fillvalue(::Type{Float64})
    fillvalue(::Type{Char})
    fillvalue(::Type{String})

Default fill-value for the given type.
"""
@inline fillvalue(::Type{Int8})    = NC_FILL_BYTE
@inline fillvalue(::Type{UInt8})   = NC_FILL_UBYTE
@inline fillvalue(::Type{Int16})   = NC_FILL_SHORT
@inline fillvalue(::Type{UInt16})  = NC_FILL_USHORT
@inline fillvalue(::Type{Int32})   = NC_FILL_INT
@inline fillvalue(::Type{UInt32})  = NC_FILL_UINT
@inline fillvalue(::Type{Int64})   = NC_FILL_INT64
@inline fillvalue(::Type{UInt64})  = NC_FILL_UINT64
@inline fillvalue(::Type{Float32}) = NC_FILL_FLOAT
@inline fillvalue(::Type{Float64}) = NC_FILL_DOUBLE
@inline fillvalue(::Type{Char})    = NC_FILL_CHAR
@inline fillvalue(::Type{String})  = NC_FILL_STRING



"Make sure that a dataset is in data mode"
function datamode(ncid,isdefmode::Vector{Bool})
    if isdefmode[1]
        nc_enddef(ncid)
        isdefmode[1] = false
    end
end

"Make sure that a dataset is in define mode"
function defmode(ncid,isdefmode::Vector{Bool})
    if !isdefmode[1]
        nc_redef(ncid)
        isdefmode[1] = true
    end
end


############################################################
# High-level
############################################################

"""
    NCDataset(filename::AbstractString, mode = "r";
            format::Symbol = :netcdf4, attrib = [])

Load, create, or even overwrite a NetCDF file at `filename`, depending on `mode`:

* `"r"` (default) : open an existing netCDF file or OPeNDAP URL
   in read-only mode.
* `"c"` : create a new NetCDF file at `filename` (an existing file with the same
  name will be overwritten).
* `"a"` : open `filename` into append mode (i.e. existing data in the netCDF
  file is not overwritten and a variable can be added).

Notice that this does not close the dataset, use `close` on the
result (or see below the `do`-block).

The optional parameter `attrib` is an iterable of attribute name and attribute
value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a
vector of pairs (see example below).

# Supported `format` values:

* `:netcdf4` (default): HDF5-based NetCDF format.
* `:netcdf4_classic`: Only netCDF 3 compatible API features will be used.
* `:netcdf3_classic`: classic netCDF format supporting only files smaller than 2GB.
* `:netcdf3_64bit_offset`: improved netCDF format supporting files larger than 2GB.

Files can also be open and automatically closed with a `do` block.

```julia
NCDataset("file.nc") do ds
    data = ds["temperature"][:,:]
end
```

Here is an attribute example:
```julia
using DataStructures
NCDataset("file.nc", "c", attrib = OrderedDict("title" => "my first netCDF file")) do ds
   defVar(ds,"temp",[10.,20.,30.],("time",))
end;
```

`NCDataset` is an alias to `NCDataset`.
"""
function NCDataset(filename::AbstractString,
                 mode::AbstractString = "r";
                 format::Symbol = :netcdf4,
                 diskless = false,
                 persist = false,
                 attrib = [])

    ncid = -1
    isdefmode = [false]

    if (mode == "r") || (mode == "a")
        ncmode =
            if (mode == "r")
                NC_NOWRITE
            else
                NC_WRITE
            end

        if diskless
            ncmode = ncmode | NC_DISKLESS
        end

        ncid = nc_open(filename,ncmode)
    elseif mode == "c"
        ncmode  = NC_CLOBBER

        if format == :netcdf3_64bit_offset
            ncmode = ncmode | NC_64BIT_OFFSET
        elseif format == :netcdf4_classic
            ncmode = ncmode | NC_NETCDF4 | NC_CLASSIC_MODEL
        elseif format == :netcdf4
            ncmode = ncmode | NC_NETCDF4
        elseif format == :netcdf3_classic
            # do nothing
        else
            throw(NetCDFError(-1, "Unkown format '$(format)' for filename '$(filename)'"))
        end

        if diskless
            ncmode = ncmode | NC_DISKLESS

            if persist
                ncmode = ncmode | NC_PERSIST
            end
        end


        ncid = nc_create(filename,ncmode)
        isdefmode[1] = true
    else
        throw(NetCDFError(-1, "Unsupported mode '$(mode)' for filename '$(filename)'"))
    end

    ds = NCDataset(ncid,isdefmode)

    # set global attributes
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

function NCDataset(ncid::Integer,
                 isdefmode::Vector{Bool})
    attrib = Attributes(ncid,NC_GLOBAL,isdefmode)
    dim = Dimensions(ncid,isdefmode)
    group = Groups(ncid,isdefmode)
    return NCDataset(ncid,isdefmode,attrib,dim,group)
end

function NCDataset(f::Function,args...; kwargs...)
    ds = NCDataset(args...; kwargs...)
    try
        f(ds)
    finally
        #@debug "closing netCDF NCDataset $(NCDatasets.path(ds))"
        close(ds)
    end
end

export NCDataset, Dataset

############################################################
# High-level: user convenience
############################################################
"""
    keys(ds::NCDataset)

Return a list of all variables names in NCDataset `ds`.
"""
Base.keys(ds::NCDataset) = listVar(ds.ncid)

"""
    path(ds::NCDataset)
Return the file path (or the opendap URL) of the NCDataset `ds`
"""
path(ds::NCDataset) = nc_inq_path(ds.ncid)
export path


"""
    sync(ds::NCDataset)

Write all changes in NCDataset `ds` to the disk.
"""
function sync(ds::NCDataset)
    datamode(ds.ncid,ds.isdefmode)
    nc_sync(ds.ncid)
end
export sync

"""
    close(ds::NCDataset)

Close the NCDataset `ds`. All pending changes will be written
to the disk.
"""
Base.close(ds::NCDataset) = nc_close(ds.ncid)
export close

############################################################
# Common methods
############################################################
function Base.iterate(a::NCIterable, state = keys(a))
    if length(state) == 0
        return nothing
    end

    return (state[1] => a[popfirst!(state)], state)
end

"""
    varbyattrib(ds, attname = attval)

Returns a list of variable(s) which has the attribute `attname` matching the value `attval`
in the dataset `ds`.
The list is empty if the none of the variables has the match.
The output is a list of `CFVariable`s.

# Examples

Load all the data of the first variable with standard name "longitude" from the
NetCDF file `results.nc`.

```julia-repl
julia> ds = NCDataset("results.nc", "r");
julia> data = varbyattrib(ds, standard_name = "longitude")[1][:]
```

"""
function varbyattrib(ds::NCDataset; kwargs...)
    # Start with an empty list of variables
    varlist = []

    # Loop on the variables
    for v in keys(ds)
        var = ds[v]

        matchall = true

        for (attsym,attval) in kwargs
            attname = String(attsym)

            # Check if the variable has the desired attribute
            if haskey(var.attrib, attname)
                # Check if the attribute value is the selected one
                if var.attrib[attname] != attval
                    matchall = false
                    break
                end
            else
                matchall = false
                break
            end
        end

        if matchall
            push!(varlist, var)
        end
    end

    return varlist
end
export varbyattrib


"""
    haskey(ds::NCDataset,name)
    haskey(d::Dimensions,name)
    haskey(ds::Attributes,name)

Return true if the NCDataset `ds` (or dimension/attribute list) has a variable (dimension/attribute) with the name `name`.
For example:

```julia
ds = NCDataset("/tmp/test.nc","r")
if haskey(ds,"temperature")
    println("The file has a variable 'temperature'")
end

if haskey(ds.dim,"lon")
    println("The file has a dimension 'lon'")
end
```

This example checks if the file `/tmp/test.nc` has a variable with the
name `temperature` and a dimension with the name `lon`.
"""
Base.haskey(a::NCIterable,name::AbstractString) = name in keys(a)
Base.in(name::AbstractString,a::NCIterable) = name in keys(a)



function Base.show(io::IO,ds::AbstractDataset; indent="")
    try
        dspath = path(ds)
        printstyled(io, indent, "NCDataset: ",dspath,"\n", color=:red)
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                print(io,"closed NetCDF NCDataset")
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

"""
    merge!(a::NCDataset, b::AbstractDataset; include, exclude)
Merge the variables of `b` into `a` (which must be opened in mode `"a"` or `"c"`).
The keywords `include` and `exclude` configure which keys of `b` should be included
(by default all), or which should be `excluded` (by default none).

This function is useful when you want to e.g. combine variables of several different
`.nc` files into a new one.
"""
function Base.merge!(a::NCDataset, b::AbstractDataset;
    include = keys(b), exclude = String[])
    for x in include
        (x ∈ keys(a) || x ∈ exclude) && continue
        println("Porting variable $x...")
        cfvar = b[x]
        if x ∈ keys(b.dim) # this is a dimension
            defDim(a, x, length(cfvar))
        end
        defVar(a, x, Array(cfvar), dimnames(cfvar); attrib = Dict(cfvar.attrib))
    end
    return a
end
