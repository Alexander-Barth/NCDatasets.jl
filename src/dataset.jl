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

mutable struct Attributes{TDS<:AbstractDataset} <: BaseAttributes
    ds::TDS
    varid::Cint
end

mutable struct Groups{TDS<:AbstractDataset} <: AbstractGroups
    ds::TDS
end

mutable struct Dimensions{TDS<:AbstractDataset} <: AbstractDimensions
    ds::TDS
end


mutable struct NCDataset{TDS} <: AbstractDataset where TDS <: Union{AbstractDataset,Nothing}
    # parent_dataset is nothing for the root dataset
    parentdataset::TDS
    ncid::Cint
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be a reference, so that remains syncronised when copied
    isdefmode::Ref{Bool}
    attrib::Attributes
    dim::Dimensions
    group::Groups

    function NCDataset(ncid::Integer,
                       isdefmode::Ref{Bool};
                       parentdataset = nothing,
                       )

        function _finalize(ds)
            @debug begin
                ccall(:jl_, Cvoid, (Any,), "finalize $ncid $timeid \n")
            end
            # only close open root group
            if (ds.ncid != -1) && (ds.parentdataset == nothing)
                close(ds)
            end
        end
        ds = new{typeof(parentdataset)}()
        ds.parentdataset = parentdataset
        ds.ncid = ncid
        ds.isdefmode = isdefmode
        ds.attrib = Attributes(ds,NC_GLOBAL)
        ds.dim = Dimensions(ds)
        ds.group = Groups(ds)

        timeid = Dates.now()
        @debug "add finalizer $ncid $timeid"
        finalizer(_finalize, ds)
        return ds
    end
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
function datamode(ds)
    if ds.isdefmode[]
        nc_enddef(ds.ncid)
        ds.isdefmode[] = false
    end
end

"Make sure that a dataset is in define mode"
function defmode(ds)
    if !ds.isdefmode[]
        nc_redef(ds.ncid)
        ds.isdefmode[] = true
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
    isdefmode = Ref(false)

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
        isdefmode[] = true
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


function NCDataset(f::Function,args...; kwargs...)
    ds = NCDataset(args...; kwargs...)
    try
        f(ds)
    finally
        @debug "closing netCDF NCDataset $(ds.ncid) $(NCDatasets.path(ds))"
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
    datamode(ds)
    nc_sync(ds.ncid)
end
export sync

"""
    close(ds::NCDataset)

Close the NCDataset `ds`. All pending changes will be written
to the disk.
"""
function Base.close(ds::NCDataset)
    @debug "closing netCDF NCDataset $(ds.ncid) $(NCDatasets.path(ds))"
    nc_close(ds.ncid)
    # prevent finalize to close file as ncid can reused for future files
    ds.ncid = -1
    return ds
end
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
    write(dest_filename::AbstractString, src::AbstractDataset; include = keys(src), exclude = [], idimensions = Dict())
    write(dest::NCDataset, src::AbstractDataset; include = keys(src), exclude = [], idimensions = Dict())

Write the variables of `src` dataset into an empty `dest` dataset (which must be opened in mode `"a"` or `"c"`).
The keywords `include` and `exclude` configure which variable of `src` should be included
(by default all), or which should be `excluded` (by default none).

If the first argument is a file name, then the dataset is open in create mode (`"c"`).

This function is useful when you want to save the dataset from a multi-file dataset.

`idimensions` is a dictionary with dimension names mapping to a list of
indices if only a subset of the dataset should be saved.

## Example

```
NCDataset(fname_src) do ds
    write(fname_slice,ds,idimensions = Dict("lon" => 2:3))
end
```

All variables in the source file `fname_src` with a dimension `lon` will be sliced
along the indices `2:3` for the `lon` dimension. All attributes (and variables
without a dimension `lon`) will be copied over unmodified.

It is assumed that all the variable of the output file can be loaded in memory.
"""
function Base.write(dest::NCDataset, src::AbstractDataset;
                    include = keys(src),
                    exclude = String[],
                    idimensions = Dict())

    unlimited_dims = unlimited(src.dim)

    for (dimname,dimlength) in src.dim
        isunlimited = dimname in unlimited_dims

        # if haskey(dest.dim,dimname)
        #     # check length
        #     if (dest.dim[dimname] !== src.dim[dimname]) && !isunlimited
        #         throw(DimensionMismatch("length of the dimensions $dimname are inconstitent in files $(path(dest)) and $(path(src))"))
        #     end
        # else
            if isunlimited
                defDim(dest, dimname, Inf)
            else
                if haskey(idimensions,dimname)
                    dimlength = length(idimensions[dimname])
                    @debug "subset $dimname $(idimensions[dimname])"
                end
                defDim(dest, dimname, dimlength)
            end
        # end
    end

    # loop over variables
    for varname in include
        (varname ∈ exclude) && continue
        @debug "Writing variable $varname..."

        cfvar = src[varname]
        dimension_names = dimnames(cfvar)

        # indices for subset
        index = ntuple(i -> get(idimensions,dimension_names[i],:),length(dimension_names))

        destvar = defVar(dest, varname, eltype(cfvar.var), dimension_names; attrib = cfvar.attrib)
        # copy data
        destvar.var[:] = cfvar.var[index...]
    end

    # loop over all global attributes
    for (attribname,attribval) in src.attrib
        dest.attrib[attribname] = attribval
    end

    # loop over all groups
    for (groupname,groupsrc) in src.group
        groupdest = defGroup(dest,groupname)
        write(groupdest,groupsrc; idimensions = idimensions)
    end
    return dest
end

function Base.write(dest_filename::AbstractString, src::AbstractDataset; kwargs...)
    NCDataset(dest_filename,"c") do dest
        write(dest,src; kwargs...)
    end
    return nothing
end
