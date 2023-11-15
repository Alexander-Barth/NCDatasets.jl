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

