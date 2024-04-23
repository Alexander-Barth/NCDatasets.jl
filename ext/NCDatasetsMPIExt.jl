module NCDatasetsMPIExt
using MPI
using NCDatasets
using NCDatasets:
    NC_COLLECTIVE,
    NC_GLOBAL,
    NC_INDEPENDENT,
    Variable,
    _dataset_ncmode,
    check,
    dataset,
    libnetcdf

import NCDatasets:
    NCDataset,
    access

function nc_create_par(path,cmode::Integer,mpi_comm,mpi_info)
    ncidp = Ref(Cint(0))
    check(ccall((:nc_create_par,libnetcdf),Cint,
                (Cstring,Cint,MPI.MPI_Comm,MPI.MPI_Info,Ref{Cint}),
                path,cmode,mpi_comm,mpi_info,ncidp))

    return ncidp[]
end

function nc_open_par(path,cmode::Integer,mpi_comm,mpi_info)
    ncidp = Ref(Cint(0))
    check(ccall((:nc_open_par,libnetcdf),Cint,
                (Cstring,Cint,MPI.MPI_Comm,MPI.MPI_Info,Ref{Cint}),
                path,cmode,mpi_comm,mpi_info,ncidp))

    return ncidp[]
end

function nc_var_par_access(ncid,varid,par_access)
    check(ccall((:nc_var_par_access,libnetcdf),Cint,
                (Cint,Cint,Cint),
                ncid,varid,par_access))
end

function parallel_access_mode(par_access::Symbol)
    if par_access == :collective
        return NC_COLLECTIVE
    elseif par_access == :independent
        return NC_INDEPENDENT
    else
        error("Unknown parallel access mode $par_access. Only :collective and :independent are supported.")
    end
end

# https://web.archive.org/web/20240414204638/https://docs.unidata.ucar.edu/netcdf-c/current/parallel_io.html


# Parallel file access is either collective (all processors must participate)
# or independent (any processor may access the data without waiting for others).
# All netCDF metadata writing operations are collective. That is, all creation
# of groups, types, variables, dimensions, or attributes. Data reads and writes
# (e.g. calls to nc_put_vara_int() and nc_get_vara_int()) may be independent,
# the default) or collective.
function access(ncv::Variable,par_access::Symbol)
    varid = ncv.varid
    ncid = dataset(ncv).ncid
    nc_var_par_access(ncid,varid,parallel_access_mode(par_access))
end

# set collective or independent IO globally (for all variables)
function access(ds::NCDataset,par_access::Symbol)
    nc_var_par_access(ds.ncid,NC_GLOBAL,parallel_access_mode(par_access))
end

function NCDataset(comm::MPI.Comm,filename::AbstractString,
                   mode::AbstractString = "r";
                   info = MPI.INFO_NULL,
                   format::Symbol = :netcdf4,
                   share::Bool = false,
                   diskless::Bool = false,
                   persist::Bool = false,
                   maskingvalue = missing,
                   attrib = [])

    ncid = -1
    isdefmode = Ref(false)
    ncmode = _dataset_ncmode(filename,mode,format;
                             diskless = diskless,
                             persist = persist,
                             share = share)

    @debug "ncmode: $ncmode"

    if (mode == "r") || (mode == "a")
        ncid = nc_open_par(filename,ncmode,comm,info)
    elseif mode == "c"
        ncid = nc_create_par(filename,ncmode,comm,info)
        isdefmode[] = true
    end

    iswritable = mode != "r"
    ds = NCDataset(
        ncid,iswritable,isdefmode,
        maskingvalue = maskingvalue)

    # set global attributes
    for (attname,attval) in attrib
        ds.attrib[attname] = attval
    end

    return ds
end

end
