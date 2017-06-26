using BinDeps
using Conda

@BinDeps.setup
libnetcdf = library_dependency("libnetcdf", aliases = ["libnetcdf4","libnetcdf-7","netcdf"])

#Conda.add_channel("conda-forge")
provides(Conda.Manager, "libnetcdf", libnetcdf)
provides(AptGet, "libnetcdf-dev", libnetcdf, os = :Linux)
provides(Yum, "netcdf-devel", libnetcdf, os = :Linux)

@BinDeps.install Dict(:libnetcdf => :libnetcdf)
