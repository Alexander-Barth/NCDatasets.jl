# for example run as:
# $HOME/.julia/packages/MPI/z2owj/bin/mpiexecjl -n 4 julia test_mpi_netcdf.jl

using MPIPreferences
using MPI
using NCDatasets
using Test

# only tested so far with OpenMPI
# and NetCDF_jll v400.902.211+0
@assert MPIPreferences.binary == "OpenMPI_jll"

mpiexec = realpath(joinpath(dirname(pathof(MPI)),"..","bin","mpiexecjl"))

#println("mpiexec ",mpiexec)

print("$mpiexec -n 4 julia test_mpi.jl")

MPI.Init()

mpi_comm = MPI.COMM_WORLD
mpi_comm_size = MPI.Comm_size(mpi_comm)
mpi_rank = MPI.Comm_rank(mpi_comm)

# need to be the same file for all processes
path = "/tmp/test-mpi.nc"
i = mpi_rank + 1


ds = NCDataset(mpi_comm,path,"c")

defDim(ds,"lon",10)
defDim(ds,"lat",mpi_comm_size)
ncv = defVar(ds,"temp",Float32,("lon","lat"))

# see
# https://web.archive.org/web/20240414204638/https://docs.unidata.ucar.edu/netcdf-c/current/parallel_io.html
NCDatasets.access(ncv.var,:collective)


print("rank $(mpi_rank) writing to netCDF variable\n")
ncv[:,i] .= mpi_rank

ncv.attrib["units"] = "degree Celsius"
ds.attrib["comment"] = "MPI test"
close(ds)


ds = NCDataset(mpi_comm,path,"r")
ncv = ds["temp"]

@test size(ncv) == (10,mpi_comm_size)
print("rank $(mpi_rank) reading from netCDF variable\n")

@test all(==(mpi_rank),ncv[:,i])
@test ncv.attrib["units"] == "degree Celsius"
@test ds.attrib["comment"] == "MPI test"

close(ds)

MPI.Finalize()
