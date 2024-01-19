# Install dependencies via the shell commands:
#
# pip install netCDF4 numpy

import netCDF4
import numpy as np
import timeit

def compute(v):
    tot = 0
    for n in range(v.shape[0]):
        tot += np.max(v[n,:,:])

    return tot/v.shape[0]

def process(fname):
    with open("/proc/sys/vm/drop_caches","w") as f:
        f.write("3")

    with netCDF4.Dataset(fname) as ds:
        v = ds["v1"]
        tot = compute(v)
        return tot


if __name__ == "__main__":
    fname = "filename_fv.nc";
    tot = process(fname)

    print("result ",tot)

    setup = "from __main__ import process"
    print("python-netCDF4 version ",netCDF4.__version__)

    benchtime = timeit.repeat(lambda: process(fname), setup=setup,number = 1, repeat = 100)
    with open("python-netCDF4.txt","w") as f:
        for bt in benchtime:
            print(bt,file=f)
