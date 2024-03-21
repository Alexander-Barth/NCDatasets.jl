#!/bin/bash

args="$@"
julia   benchmark-julia-NCDatasets.jl $args
python3 benchmark-python-netCDF4.py $args
Rscript benchmark-R-ncdf4.R $args

julia summary.jl
