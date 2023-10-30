# All types using in `NCDatasets`
# Note in CommonDataModel the special properties `attrib`, `dim` and `group`
# are made available.


# Exception type for error thrown by the NetCDF library
mutable struct NetCDFError <: Exception
    code::Cint
    msg::String
end

abstract type AbstractNCDataset <: AbstractDataset
end

abstract type AbstractNCVariable{T,N} <: AbstractVariable{T,N}
end

# Variable (as stored in NetCDF file, without using
# add_offset, scale_factor and _FillValue)
mutable struct Variable{NetCDFType,N,TDS} <: AbstractNCVariable{NetCDFType, N}
    ds::TDS
    varid::Cint
    dimids::NTuple{N,Cint}
end

mutable struct NCDataset{TDS} <: AbstractNCDataset where TDS <: Union{AbstractNCDataset,Nothing}
    # parent_dataset is nothing for the root dataset
    parentdataset::TDS
    ncid::Cint
    iswritable::Bool
    # true of the NetCDF is in define mode (i.e. metadata can be added, but not data)
    # need to be a reference, so that remains syncronised when copied
    isdefmode::Ref{Bool}
    # mapping between variables related via the bounds attribute
    # It is only used for read-only datasets to improve performance
    _boundsmap::Dict{String,String}
    function NCDataset(ncid::Integer,
                       iswritable::Bool,
                       isdefmode::Ref{Bool};
                       parentdataset = nothing,
                       )

        function _finalize(ds)
            #@debug begin
            #    ccall(:jl_, Cvoid, (Any,), "finalize $ncid $timeid \n")
            #end
            # only close open root group
            if (ds.ncid != -1) && (ds.parentdataset == nothing)
                close(ds)
            end
        end
        ds = new{typeof(parentdataset)}()
        ds.parentdataset = parentdataset
        ds.ncid = ncid
        ds.iswritable = iswritable
        ds.isdefmode = isdefmode
        ds._boundsmap = Dict{String,String}()
        if !iswritable
            initboundsmap!(ds)
        end
        #timeid = Dates.now()
        #@debug "add finalizer $ncid $(timeid)"
        finalizer(_finalize, ds)
        return ds
    end
end

"Alias to `NCDataset`"
const Dataset = NCDataset


# Multi-file related type definitions

mutable struct MFVariable{T,N,M,TA,TDS} <: AbstractNCVariable{T,N}
    ds::TDS
    var::CatArrays.CatArray{T,N,M,TA}
    dimnames::NTuple{N,String}
    varname::String
end

mutable struct MFCFVariable{T,N,M,TA,TV,TDS} <: AbstractNCVariable{T,N}
    ds::TDS
    cfvar::CatArrays.CatArray{T,N,M,TA}
    var::TV
    dimnames::NTuple{N,String}
    varname::String
end

mutable struct MFDataset{T,N,S<:AbstractString} <: AbstractNCDataset where T <: AbstractNCDataset
    ds::Array{T,N}
    aggdim::S
    isnewdim::Bool
    constvars::Vector{Symbol}
    _boundsmap::Dict{String,String}
end

# DeferDataset are Dataset which are open only when there are accessed and
# closed directly after. This is necessary to work with a large number
# of NetCDF files (e.g. more than 1000).

struct Resource
    filename::String
    mode::String
    metadata::OrderedDict
end

mutable struct DeferDataset <: AbstractNCDataset
    r::Resource
    groupname::String
    data::OrderedDict
    _boundsmap::Union{Nothing,Dict{String,String}}
end

mutable struct DeferVariable{T,N} <: AbstractNCVariable{T,N}
    r::Resource
    varname::String
    data::OrderedDict
end

# view of subsets

struct SubVariable{T,N,TA,TI,TAttrib,TV} <: AbstractNCVariable{T,N}
    parent::TA
    indices::TI
    attrib::TAttrib
    # unpacked variable
    var::TV
end

struct SubDataset{TD,TI,TA,TG}  <: AbstractNCDataset
    ds::TD
    indices::TI
    attrib::TA
    group::TG
end
