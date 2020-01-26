#!/bin/bash

julia   benchmark-julia-NCDatasets.jl
python3 benchmark-python-netCDF4.py
Rscript benchmark-R-ncdf4.R

julia summary.jl
