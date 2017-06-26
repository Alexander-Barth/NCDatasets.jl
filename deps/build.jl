using BinDeps
using Conda

function validate_netcdf_version(name,handle)
    f = Libdl.dlsym_e(handle, "nc_inq_libvers")
    verstr = unsafe_string(ccall(f,Ptr{UInt8},()))

    ver = VersionNumber(split(verstr)[1])
    return ver > v"4.2"
end

@BinDeps.setup
libnetcdf = library_dependency("libnetcdf", aliases = ["libnetcdf4","libnetcdf-7","netcdf"], validate = validate_netcdf_version)

#Conda.add_channel("conda-forge")
provides(Conda.Manager, "libnetcdf", libnetcdf)
provides(AptGet, "libnetcdf-dev", libnetcdf, os = :Linux)
provides(Yum, "netcdf-devel", libnetcdf, os = :Linux)

@BinDeps.install Dict(:libnetcdf => :libnetcdf)
