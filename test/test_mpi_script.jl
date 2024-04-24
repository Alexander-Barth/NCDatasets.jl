# for example run as:
# $HOME/.julia/packages/MPI/z2owj/bin/mpiexecjl -n 4 julia test_mpi_script.jl

using MPI
using NCDatasets
using Test

MPI.Init()

mpi_comm = MPI.COMM_WORLD
mpi_comm_size = MPI.Comm_size(mpi_comm)
mpi_rank = MPI.Comm_rank(mpi_comm)

# need to be the same file for all processes
path = ARGS[1]
i = mpi_rank + 1

ds = NCDataset(mpi_comm,path,"c")

defDim(ds,"lon",10)
defDim(ds,"lat",mpi_comm_size)
ncv = defVar(ds,"temp",Int32,("lon","lat"))

# see
# https://web.archive.org/web/20240414204638/https://docs.unidata.ucar.edu/netcdf-c/current/parallel_io.html
NCDatasets.access(ncv.var,:collective)


@debug("rank $(mpi_rank) writing to netCDF variable")
ncv[:,i] .= mpi_rank

ncv.attrib["units"] = "degree Celsius"
ds.attrib["comment"] = "MPI test"
close(ds)


ds = NCDataset(mpi_comm,path,"r")
ncv = ds["temp"]

@test size(ncv) == (10,mpi_comm_size)
@debug("rank $(mpi_rank) reading from netCDF variable")

@test all(==(mpi_rank),ncv[:,i])
@test ncv.attrib["units"] == "degree Celsius"
@test ds.attrib["comment"] == "MPI test"

close(ds)

MPI.Finalize()
