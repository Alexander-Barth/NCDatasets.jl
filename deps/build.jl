using BinDeps
import CondaBinDeps

if VERSION >= v"0.7.0"
    using Libdl
end

function validate_netcdf_version(name,handle)
    f = Libdl.dlsym_e(handle, "nc_inq_libvers")
    #
    # Example
    # banner = "4.5.6.7 of Apr 1 2000 00:00:00"
    banner = unsafe_string(ccall(f,Ptr{UInt8},()))

    # remove the date
    # verstr = "4.5.6.7"
    verstr = split(banner)[1]

    # vernumbers = ["4","5","6","7"]
    vernumbers = split(verstr,r"[.-]")

    # major_minor_patch = ["4","5","6"]
    major_minor_patch = vernumbers[1:min(3,length(vernumbers))]

    # ver = v"4.5.6"
    ver = VersionNumber([parse(Int,s) for s in major_minor_patch]...)

    return ver > v"4.2"
end

@BinDeps.setup
libnetcdf = library_dependency("libnetcdf", aliases = ["libnetcdf4","libnetcdf-7","netcdf"], validate = validate_netcdf_version)

#CondaBinDeps.Conda.add_channel("conda-forge")
provides(CondaBinDeps.Manager, "libnetcdf", libnetcdf)
provides(AptGet, "libnetcdf-dev", libnetcdf, os = :Linux)
provides(Yum, "netcdf-devel", libnetcdf, os = :Linux)

@BinDeps.install Dict(:libnetcdf => :libnetcdf)
