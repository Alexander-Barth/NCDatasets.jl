

const NCIterable = Union{BaseAttributes,AbstractDimensions,AbstractNCDataset,AbstractGroups}
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

iswritable(ds::NCDataset) = ds.iswritable

function isopen(ds::NCDataset)
    try
        dspath = path(ds)
        return true
    catch err
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                return false
            end
        end
        rethrow()
    end
end

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

"Initialize the ds._boundsmap variable"
function initboundsmap!(ds)
    ds._boundsmap = Dict{String,String}()
    for vname in keys(ds)
        v = variable(ds,vname)
        bounds = get(v.attrib,"bounds",nothing)

        if bounds !== nothing
            ds._boundsmap[bounds] = vname
        end
    end
end

############################################################
# High-level
############################################################

"""
    NCDataset(filename::AbstractString, mode = "r";
              format::Symbol = :netcdf4,
              share::Bool = false,
              diskless::Bool = false,
              persist::Bool = false,
              memory::Union{Vector{UInt8},Nothing} = nothing,
              attrib = [])

Load, create, or even overwrite a NetCDF file at `filename`, depending on `mode`

* `"r"` (default) : open an existing netCDF file or OPeNDAP URL
   in read-only mode.
* `"c"` : create a new NetCDF file at `filename` (an existing file with the same
  name will be overwritten).
* `"a"` : open `filename` into append mode (i.e. existing data in the netCDF
  file is not overwritten and a variable can be added).


If `share` is true, the `NC_SHARE` flag is set allowing to have multiple
processes to read the file and one writer process. Likewise setting `diskless`
or `persist` to `true` will enable the flags `NC_DISKLESS` or `NC_PERSIST` flag.
More information is available in the [NetCDF C-API](https://www.unidata.ucar.edu/software/netcdf/docs/).

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
* `:netcdf5_64bit_data`: improved netCDF format supporting 64-bit integer data types.


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

The NetCDF dataset can also be a `memory` as a vector of bytes. A non-empty string
a `filename` is still required, for example:

```julia
using NCDataset, HTTP
resp = HTTP.get("https://www.unidata.ucar.edu/software/netcdf/examples/ECMWF_ERA-40_subset.nc")
ds = NCDataset("some_string","r",memory = resp.body)
total_precipitation = ds["tp"][:,:,:]
close(ds)
```

`Dataset` is an alias of `NCDataset`.
"""
function NCDataset(filename::AbstractString,
                   mode::AbstractString = "r";
                   format::Symbol = :netcdf4,
                   share::Bool = false,
                   diskless::Bool = false,
                   persist::Bool = false,
                   memory::Union{Vector{UInt8},Nothing} = nothing,
                   attrib = [])

    ncid = -1
    isdefmode = Ref(false)

    ncmode =
        if mode == "r"
            NC_NOWRITE
        elseif mode == "a"
            NC_WRITE
        elseif mode == "c"
            NC_CLOBBER
        else
            throw(NetCDFError(-1, "Unsupported mode '$(mode)' for filename '$(filename)'"))
        end

    if diskless
        ncmode = ncmode | NC_DISKLESS

        if persist
            ncmode = ncmode | NC_PERSIST
        end
    end

    if share
        @debug "share mode"
        ncmode = ncmode | NC_SHARE
    end

    @debug "ncmode: $ncmode"

    if (mode == "r") || (mode == "a")
        if memory == nothing
            ncid = nc_open(filename,ncmode)
        else
            ncid = nc_open_mem(filename,ncmode,memory)
        end
    elseif mode == "c"
        if format == :netcdf5_64bit_data
            ncmode = ncmode | NC_64BIT_DATA
        elseif format == :netcdf3_64bit_offset
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

        ncid = nc_create(filename,ncmode)
        isdefmode[] = true
    end

    iswritable = mode != "r"
    ds = NCDataset(ncid,iswritable,isdefmode)

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
    #@debug "closing netCDF NCDataset $(ds.ncid) $(NCDatasets.path(ds))"
    try
        nc_close(ds.ncid)
    catch err
        # like Base, allow close on closed file
        if isa(err,NetCDFError)
            if err.code == NC_EBADID
                return ds
            end
        end
        rethrow()
    end
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
function varbyattrib(ds::Union{AbstractNCDataset,AbstractVariable}; kwargs...)
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


dimnames(ds::AbstractNCDataset) = keys(ds.dim)
dim(ds::AbstractNCDataset,name::AbstractString) = ds.dim[name]

function Base.getindex(ds::Union{AbstractNCDataset,AbstractVariable},n::CFStdName)
    ncvars = varbyattrib(ds, standard_name = String(n.name))
    if length(ncvars) == 1
        return ncvars[1]
    else
        throw(KeyError("$(length(ncvars)) matches while searching for a variable with standard_name attribute equal to $(n.name)"))
    end
end


function _write(dest::NCDataset, src::AbstractDataset;
                    include = keys(src),
                    exclude = String[],
                    _ignore_checksum = false,
                    )

    unlimited_dims = unlimited(src)

    for (dimname,dimlength) in dims(src)
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
                defDim(dest, dimname, dimlength)
            end
        # end
    end

    # loop over variables
    for varname in include
        (varname ∈ exclude) && continue
        @debug "Writing variable $varname..."

        var = variable(src,varname)
        dimension_names = dimnames(var)
        cfdestvar = defVar(dest, varname, eltype(var), dimension_names;
                           attrib = attribs(var))
        destvar = variable(dest,varname)

        if hasmethod(chunking,Tuple{typeof(var)})
            storage,chunksizes = chunking(var)
            @debug "chunking " name(var) size(var) size(cfdestvar) storage chunksizes
            chunking(cfdestvar,storage,chunksizes)
        end

        if hasmethod(deflate,Tuple{typeof(var)})
            isshuffled,isdeflated,deflate_level = deflate(var)
            @debug "compression" isshuffled isdeflated deflate_level
            deflate(cfdestvar,isshuffled,isdeflated,deflate_level)
        end

        if hasmethod(checksum,Tuple{typeof(var)}) && !_ignore_checksum
            checksummethod = checksum(var)
            @debug "check-sum" checksummethod
            checksum(cfdestvar,checksummethod)
        end

        # copy data
        if hasmethod(eachchunk,Tuple{typeof(var)})
            for indices in eachchunk(var)
                destvar[indices...] = var[indices...]
            end
        else
            indices = ntuple(i -> :,ndims(var))
            destvar[indices...] = var[indices...]
        end
    end

    # loop over all global attributes
    for (attribname,attribval) in attribs(src)
        dest.attrib[attribname] = attribval
    end

    # loop over all groups
    for (groupname,groupsrc) in groups(src)
        groupdest = defGroup(dest,groupname)
        write(groupdest,groupsrc)
    end

    return dest
end



"""
    write(dest_filename::AbstractString, src::AbstractNCDataset; include = keys(src), exclude = [], idimensions = Dict())
    write(dest::NCDataset, src::AbstractNCDataset; include = keys(src), exclude = [], idimensions = Dict())

Write the variables of `src` dataset into an empty `dest` dataset (which must be opened in mode `"a"` or `"c"`).
The keywords `include` and `exclude` configure which variable of `src` should be included
(by default all), or which should be `excluded` (by default none).

If the first argument is a file name, then the dataset is open in create mode (`"c"`).

This function is useful when you want to save the dataset from a multi-file dataset.

To save a subset, one can use the view function `view` to virtually slice
a dataset:

## Example

```
NCDataset(fname_src) do ds
    write(fname_slice,view(ds, lon = 2:3))
    # deprecated
    # write(fname_slice,ds,idimensions = Dict("lon" => 2:3))
end
```

All variables in the source file `fname_src` with a dimension `lon` will be sliced
along the indices `2:3` for the `lon` dimension. All attributes (and variables
without a dimension `lon`) will be copied over unmodified.
"""
function Base.write(dest::NCDataset, src::AbstractDataset;
                    include = keys(src),
                    exclude = String[],
                    idimensions = Dict(),
                    _ignore_checksum = false,
                    )

    if !isempty(idimensions)
        Base.depwarn(
            "The parameter `idimensions` is deprecated. Please use views instead",
            :write)
    end

    src_subset = view(src;((Symbol(k)=>v) for (k,v) in idimensions)...)
    _write(dest, src_subset;
          include = include,
          exclude = exclude,
          _ignore_checksum = _ignore_checksum)
end

function Base.write(dest_filename::AbstractString, src::AbstractDataset; kwargs...)
    NCDataset(dest_filename,"c") do dest
        write(dest,src; kwargs...)
    end
    return nothing
end


get_chunk_cache() = nc_get_chunk_cache()

function set_chunk_cache(;size=nothing,nelems=nothing,preemption=nothing)
    size_orig,nelems_orig,preemption_orig = nc_get_chunk_cache()
    size = (isnothing(size) ? size_orig : size)
    nelems = (isnothing(nelems) ? nelems_orig : nelems)
    preemption = (isnothing(preemption) ? preemption_orig : preemption)
    nc_set_chunk_cache(size,nelems,preemption)
end
