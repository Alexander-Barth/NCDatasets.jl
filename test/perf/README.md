# Benchmarks

The operating systems typically caches access to the file system.
To make these benchmarks more realistic, the file system caches is dropped at every iteration so that the disk IO *is* included in the reported run times.
On Linux, the caches are dropped by writing `3` to the file `/proc/sys/vm/drop_caches` however this requires super user privileges.
These benchmarks require a Linux operating system (as dropping file caches is OS-specific).


## Installation

### Julia packages

Within a Julia shell install `BenchmarkTools` and `NCDatasets` using these julia commands:

```julia
using Pkg
Pkg.add(["BenchmarkTools","NCDatasets"])
```

### Python packages

Install the python packages `netCDF4` and `numpy` using this shell command:

```bash
pip install netCDF4 numpy
```

### R packages

Within a R shell install `microbenchmark` and `ncdf4` using these R commands:
```R
install.packages("microbenchmark")
install.packages("ncdf4")
```

## Running the benchmark

These are the steps to run the benchmark:

* Prepare the file `filename_fv.nc` with:

```bash
julia generate_data.jl
```

* As a *root user*, run the shell script `benchmark.sh`. It is necessary that the root user has access to the Julia, python and R netCDF packages (NCDatasets, netCDF4 and ncdf4 respectively).

```bash
./benchmark.sh
```

If all packages are installed in the home directory of an unpriviledges user e.g. `my_user_name`, they can be made available to the root user changing temporarily the `HOME` environement variable to `/home/my_user_name` in the root shell before running `./benchmark.sh`:

```bash
HOME=/home/my_user_name ./benchmark.sh
```

The script will output a markdown table with the benchmark statistics.
