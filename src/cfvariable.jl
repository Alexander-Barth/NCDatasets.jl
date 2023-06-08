############################################################
# Creating variables
############################################################

"""
    defVar(ds::NCDataset,name,vtype,dimnames; kwargs...)
    defVar(ds::NCDataset,name,data,dimnames; kwargs...)

Define a variable with the name `name` in the dataset `ds`.  `vtype` can be
Julia types in the table below (with the corresponding NetCDF type). The
parameter `dimnames` is a tuple with the names of the dimension.  For scalar
this parameter is the empty tuple `()`.
The variable is returned (of the type `CFVariable`).

Instead of providing the variable type one can directly give also the data `data` which
will be used to fill the NetCDF variable. In this case, the dimensions with
the appropriate size will be created as required using the names in `dimnames`.

If `data` is a vector or array of `DateTime` objects, then the dates
are saved as double-precision floats and units
"$(CFTime.DEFAULT_TIME_UNITS)" (unless a time unit
is specifed with the `attrib` keyword as described below). Dates are
converted to the default calendar in the CF conversion which is the
mixed Julian/Gregorian calendar.

## Keyword arguments

* `fillvalue`: A value filled in the NetCDF file to indicate missing data.
   It will be stored in the _FillValue attribute.
* `chunksizes`: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.
* `deflatelevel`: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.
* `shuffle`: If true, the shuffle filter is activated which can improve the compression ratio.
* `checksum`: The checksum method can be `:fletcher32` or `:nochecksum` (checksumming is disabled, which is the default)
* `attrib`: An iterable of attribute name and attribute value pairs, for example a `Dict`, `DataStructures.OrderedDict` or simply a vector of pairs (see example below)
* `typename` (string): The name of the NetCDF type required for [vlen arrays](https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc_005fdef_005fvlen.html)

`chunksizes`, `deflatelevel`, `shuffle` and `checksum` can only be
set on NetCDF 4 files. Compression of strings and variable-length arrays is not
supported by the underlying NetCDF library.

## NetCDF data types

| NetCDF Type | Julia Type |
|-------------|------------|
| NC_BYTE     | Int8 |
| NC_UBYTE    | UInt8 |
| NC_SHORT    | Int16 |
| NC_INT      | Int32 |
| NC_INT64    | Int64 |
| NC_FLOAT    | Float32 |
| NC_DOUBLE   | Float64 |
| NC_CHAR     | Char |
| NC_STRING   | String |


## Dimension ordering

The data is stored in the NetCDF file in the same order as they are stored in
memory. As julia uses the
[Column-major ordering](https://en.wikipedia.org/wiki/Row-_and_column-major_order)
for arrays, the order of dimensions will appear reversed when the data is loaded
in languages or programs using
[Row-major ordering](https://en.wikipedia.org/wiki/Row-_and_column-major_order)
such as C/C++, Python/NumPy or the tools `ncdump`/`ncgen`
([NetCDF CDL](https://web.archive.org/web/20220513091844/https://docs.unidata.ucar.edu/nug/current/_c_d_l.html)).
NumPy can also use Column-major ordering but Row-major order is the default. For the column-major
interpretation of the dimensions (as in Julia), the
[CF Convention recommends](https://web.archive.org/web/20220328110810/http://cfconventions.org/Data/cf-conventions/cf-conventions-1.7/cf-conventions.html#dimensions) the
order  "longitude" (X), "latitude" (Y), "height or depth" (Z) and
"date or time" (T) (if applicable). All other dimensions should, whenever
possible, be placed to the right of the spatiotemporal dimensions.

## Example:

In this example, `scale_factor` and `add_offset` are applied when the `data`
is saved.

```julia-repl
julia> using DataStructures
julia> data = randn(3,5)
julia> NCDataset("test_file.nc","c") do ds
          defVar(ds,"temp",data,("lon","lat"), attrib = OrderedDict(
             "units" => "degree_Celsius",
             "add_offset" => -273.15,
             "scale_factor" => 0.1,
             "long_name" => "Temperature"
          ))
       end;
```

!!! note

    If the attributes `_FillValue`, `missing_value`, `add_offset`, `scale_factor`,
    `units` and `calendar` are used, they should be defined when calling `defVar`
    by using the parameter `attrib` as shown in the example above.


"""
function defVar(ds::NCDataset,name,vtype::DataType,dimnames; kwargs...)
    # all keyword arguments as dictionary
    kw = Dict(k => v for (k,v) in kwargs)

    defmode(ds) # make sure that the file is in define mode
    dimids = Cint[nc_inq_dimid(ds.ncid,dimname) for dimname in dimnames[end:-1:1]]

    typeid =
        if vtype <: Vector
            # variable-length type
            typeid = nc_def_vlen(ds.ncid, kw[:typename], ncType[eltype(vtype)])
        else
            # base-type
            ncType[vtype]
        end

    varid = nc_def_var(ds.ncid,name,typeid,dimids)

    if haskey(kw,:chunksizes)
        storage = :chunked
        chunksizes = kw[:chunksizes]

        # this will fail on NetCDF-3 files
        nc_def_var_chunking(ds.ncid,varid,storage,reverse(chunksizes))
    end

    if haskey(kw,:shuffle) || haskey(kw,:deflatelevel)
        shuffle = get(kw,:shuffle,false)
        deflate = haskey(kw,:deflatelevel)
        deflate_level = get(kw,:deflatelevel,0)

        # this will fail on NetCDF-3 files
        nc_def_var_deflate(ds.ncid,varid,shuffle,deflate,deflate_level)
    end

    if haskey(kw,:checksum)
        checksum = kw[:checksum]
        nc_def_var_fletcher32(ds.ncid,varid,checksum)
    end

    if haskey(kw,:fillvalue)
        fillvalue = kw[:fillvalue]
        nofill = get(kw,:nofill,false)
        nc_def_var_fill(ds.ncid, varid, nofill, vtype(fillvalue))
    end

    if haskey(kw,:attrib)
        v = ds[name]
        for (attname,attval) in kw[:attrib]
            v.attrib[attname] = attval
        end
    end

    return ds[name]
end


# data has the type e.g. Array{Union{Missing,Float64},3}
function defVar(ds::NCDataset,
                name,
                data::AbstractArray{Union{Missing,nctype},N},
                dimnames;
                kwargs...) where nctype <: Union{Int8,UInt8,Int16,Int32,Int64,Float32,Float64} where N
    _defVar(ds::NCDataset,name,data,nctype,dimnames; kwargs...)
end

# data has the type e.g. Vector{DateTime}, Array{Union{Missing,DateTime},3} or
# Vector{DateTime360Day}
# Data is always stored as Float64 in the NetCDF file
function defVar(ds::NCDataset,
                name,
                data::AbstractArray{<:Union{Missing,nctype},N},
                dimnames;
                kwargs...) where nctype <: Union{DateTime,AbstractCFDateTime} where N
    _defVar(ds::NCDataset,name,data,Float64,dimnames; kwargs...)
end

function defVar(ds::NCDataset,name,data,dimnames; kwargs...)
    # eltype of a String would be Char
    if data isa String
        nctype = String
    else
        nctype = eltype(data)
    end
    _defVar(ds::NCDataset,name,data,nctype,dimnames; kwargs...)
end

function _defVar(ds::NCDataset,name,data,nctype,dimnames; attrib = [], kwargs...)
    # define the dimensions if necessary
    for (i,dimname) in enumerate(dimnames)
        if !(dimname in ds.dim)
            ds.dim[dimname] = size(data,i)
        elseif !(dimname in unlimited(ds.dim))
            dimlen = ds.dim[dimname]

            if (dimlen != size(data,i))
                throw(NetCDFError(
                    -1,"dimension $(dimname) is already defined with the " *
                    "length $dimlen. It cannot be redefined with a length of $(size(data,i))."))
            end
        end
    end

    T = eltype(data)
    attrib = collect(attrib)

    if T <: Union{TimeType,Missing}
        dattrib = Dict(attrib)
        if !haskey(dattrib,"units")
            push!(attrib,"units" => CFTime.DEFAULT_TIME_UNITS)
        end
        if !haskey(dattrib,"calendar")
            # these dates cannot be converted to the standard calendar
            if T <: Union{DateTime360Day,Missing}
                push!(attrib,"calendar" => "360_day")
            elseif T <: Union{DateTimeNoLeap,Missing}
                push!(attrib,"calendar" => "365_day")
            elseif T <: Union{DateTimeAllLeap,Missing}
                push!(attrib,"calendar" => "366_day")
            end
        end
    end

    v =
        if Missing <: T
            # make sure a fill value is set (it might be overwritten by kwargs...)
            defVar(ds,name,nctype,dimnames;
                   fillvalue = fillvalue(nctype),
                   attrib = attrib,
                   kwargs...)
        else
            defVar(ds,name,nctype,dimnames;
                   attrib = attrib,
                   kwargs...)
        end

    v[:] = data
    return v
end


function defVar(ds::NCDataset,name,data::T; kwargs...) where T <: Union{Number,String,Char}
    v = defVar(ds,name,T,(); kwargs...)
    v[:] = data
    return v
end
export defVar


# more efficient implementation implementing a cache
function boundsParentVar(ds::AbstractNCDataset,varname)
    # iterating using variable ids instead of variable names
    # is more efficient (but not possible for e.g. multi-file datasets)
    eachvariable(ds::NCDataset) = (variable(ds,varid) for varid in nc_inq_varids(ds.ncid))
    eachvariable(ds) = (variable(ds,vname) for vname in keys(ds))


    # get from cache is available
    if length(values(ds._boundsmap)) > 0
        return get(ds._boundsmap,varname,"")
    else
        for v in eachvariable(ds)
            bounds = get(v.attrib,"bounds","")
            if bounds === varname
                return name(v)
            end
        end

        return ""
    end
end


export cfvariable

"""
    v = getindex(ds::NCDataset,varname::AbstractString)

Return the NetCDF variable `varname` in the dataset `ds` as a
`NCDataset.CFVariable`. The following CF convention are honored when the
variable is indexed:
* `_FillValue` or `missing_value` (which can be a list) will be returned as `missing`. `NCDatasets` does not use implicitely the default NetCDF fill values when reading data.
* `scale_factor` and `add_offset` are applied (output = `scale_factor` * `data_in_file` +  `add_offset`)
* time variables (recognized by the units attribute and possibly the calendar attribute) are returned usually as
  `DateTime` object. Note that `DateTimeAllLeap`, `DateTimeNoLeap` and
  `DateTime360Day` cannot be converted to the proleptic gregorian calendar used in
  julia and are returned as such. If a calendar is defined but not among the
ones specified in the CF convention, then the data in the NetCDF file is not
converted into a date structure.

A call `getindex(ds,varname)` is usually written as `ds[varname]`.

If variable represents a cell boundary, the attributes `calendar` and `units` of the related NetCDF variables are used, if they are not specified. For example:

```
dimensions:
  time = UNLIMITED; // (5 currently)
  nv = 2;
variables:
  double time(time);
    time:long_name = "time";
    time:units = "hours since 1998-04-019 06:00:00";
    time:bounds = "time_bnds";
  double time_bnds(time,nv);
```

In this case, the variable `time_bnds` uses the units and calendar of `time`
because both variables are related thought the bounds attribute following the CF conventions.

See also cfvariable
"""
function Base.getindex(ds::AbstractNCDataset,varname::SymbolOrString)
    return cfvariable(ds, varname)
end



"""
    dimnames(v::CFVariable)

Return a tuple of strings with the dimension names of the variable `v`.
"""
dimnames(v::Union{CFVariable,MFCFVariable})  = dimnames(v.var)


"""
    dimsize(v::CFVariable)
Get the size of a `CFVariable` as a named tuple of dimension → length.
"""
function dimsize(v::Union{CFVariable,MFCFVariable,SubVariable})
    s = size(v)
    names = Symbol.(dimnames(v))
    return NamedTuple{names}(s)
end
export dimsize


name(v::Union{CFVariable,MFCFVariable}) = name(v.var)
chunking(v::CFVariable,storage,chunksize) = chunking(v.var,storage,chunksize)
chunking(v::CFVariable) = chunking(v.var)

deflate(v::CFVariable,shuffle,dodeflate,deflate_level) = deflate(v.var,shuffle,dodeflate,deflate_level)
deflate(v::CFVariable) = deflate(v.var)

checksum(v::CFVariable,checksummethod) = checksum(v.var,checksummethod)
checksum(v::CFVariable) = checksum(v.var)


fillmode(v::CFVariable) = fillmode(v.var)



############################################################
# CFVariable
############################################################



# indexing with vector of integers

to_range_list(index::Integer,len) = index

to_range_list(index::Colon,len) = [1:len]
to_range_list(index::AbstractRange,len) = [index]

function to_range_list(index::Vector{T},len) where T <: Integer
    grow(istart) = istart[begin]:(istart[end]+step(istart))

    baseindex = 1
    indices_ranges = UnitRange{T}[]

    while baseindex <= length(index)
        range = index[baseindex]:index[baseindex]
        range_test = grow(range)
        index_view = @view index[baseindex:end]

        while checkbounds(Bool,index_view,length(range_test)) &&
            (range_test[end] == index_view[length(range_test)])

            range = range_test
            range_test = grow(range_test)
        end

        push!(indices_ranges,range)
        baseindex += length(range)
    end

    @assert reduce(vcat,indices_ranges) == index
    return indices_ranges
end

_range_indices_dest(of) = of
_range_indices_dest(of,i::Integer,rest...) = _range_indices_dest(of,rest...)

function _range_indices_dest(of,v,rest...)
    b = 0
    ind = similar(v,0)
    for r in v
        rr = 1:length(r)
        push!(ind,b .+ rr)
        b += length(r)
    end

    _range_indices_dest((of...,ind),rest...)
end
range_indices_dest(ri...) = _range_indices_dest((),ri...)

function Base.getindex(v::Union{MFVariable,SubVariable},indices::Union{Int,Colon,AbstractRange{<:Integer},Vector{Int}}...)
    @debug "transform vector of indices to ranges"

    sz_source = size(v)
    ri = to_range_list.(indices,sz_source)
    sz_dest = NCDatasets._shape_after_slice(sz_source,indices...)

    N = length(indices)

    ri_dest = range_indices_dest(ri...)
    @debug "ri_dest $ri_dest"
    @debug "ri $ri"

    if all(==(1),length.(ri))
        # single chunk
        R = first(CartesianIndices(length.(ri)))
        ind_source = ntuple(i -> ri[i][R[i]],N)
        ind_dest = ntuple(i -> ri_dest[i][R[i]],length(ri_dest))
        return v[ind_source...]
    end

    dest = Array{eltype(v),length(sz_dest)}(undef,sz_dest)
    for R in CartesianIndices(length.(ri))
        ind_source = ntuple(i -> ri[i][R[i]],N)
        ind_dest = ntuple(i -> ri_dest[i][R[i]],length(ri_dest))
        #dest[ind_dest...] = v[ind_source...]
        buffer = Array{eltype(v.var),length(ind_dest)}(undef,length.(ind_dest))
        load!(v,view(dest,ind_dest...),buffer,ind_source...)
    end
    return dest
end


############################################################
# Convertion to array
############################################################

Base.Array(v::AbstractVariable{T,N}) where {T,N} = v[ntuple(i -> :, Val(N))...]


"""
    NCDatasets.load!(ncvar::CFVariable, data, buffer, indices)

Loads a NetCDF variables `ncvar` in-place and puts the result in `data` (an
array of `eltype(ncvar)`) along the specified `indices`. `buffer` is a temporary
 array of the same size as data but the type should be `eltype(ncv.var)`, i.e.
the corresponding type in the NetCDF files (before applying `scale_factor`,
`add_offset` and masking fill values). Scaling and masking will be applied to
the array `data`.

`data` and `buffer` can be the same array if `eltype(ncvar) == eltype(ncvar.var)`.

## Example:

```julia
# create some test array
Dataset("file.nc","c") do ds
    defDim(ds,"time",3)
    ncvar = defVar(ds,"vgos",Int16,("time",),attrib = ["scale_factor" => 0.1])
    ncvar[:] = [1.1, 1.2, 1.3]
    # store 11, 12 and 13 as scale_factor is 0.1
end


ds = Dataset("file.nc")
ncv = ds["vgos"];
# data and buffer must have the right shape and type
data = zeros(eltype(ncv),size(ncv)); # here Vector{Float64}
buffer = zeros(eltype(ncv.var),size(ncv)); # here Vector{Int16}
NCDatasets.load!(ncv,data,buffer,:,:,:)
close(ds)
```
"""
@inline function load!(v::Union{CFVariable{T,N},MFCFVariable{T,N},SubVariable{T,N}}, data, buffer, indices::Union{Integer, AbstractRange{<:Integer}, Colon}...) where {T,N}

    if v.var == nothing
        return load!(v,indices...)
    else
        load!(v.var,buffer,indices...)
        fmv = fill_and_missing_values(v)
        return CFtransformdata!(data,buffer,fmv,scale_factor(v),add_offset(v),
                                time_origin(v),time_factor(v))
    end
end


function _isrelated(v1::AbstractVariable,v2::AbstractVariable)
    dimnames(v1) ⊆ dimnames(v2)
end

function Base.keys(v::AbstractVariable)
    ds = dataset(v)
    return [varname for (varname,ncvar) in ds if _isrelated(ncvar,v)]
end


function Base.getindex(v::AbstractVariable,name::AbstractString)
    ds = dataset(v)
    ncvar = ds[name]
    if _isrelated(ncvar,v)
        return ncvar
    else
        throw(KeyError(name))
    end
end
