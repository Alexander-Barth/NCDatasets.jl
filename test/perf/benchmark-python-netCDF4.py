import netCDF4
import numpy as np
import timeit

def compute(v):
    tot = 0
    for n in range(v.shape[0]):
        tot += np.max(v[n,:,:])

    return tot/v.shape[0]

def process(fname):
    with netCDF4.Dataset(fname) as ds:
        v = ds["v1"]
        tot = compute(v)
        return tot

def process_example():
    fname = "filename_fv.nc";
    process(fname)


setup = "from __main__ import process_example"
print("python-netCDF4 version ",netCDF4.__version__)

benchtime = timeit.repeat("process_example()", setup=setup,number = 1, repeat = 100)
with open("python-netCDF4.txt","w") as f:
    for bt in benchtime:
        print(bt,file=f)
