using Test
using NCDatasets

cd(@__DIR__)

fname = example_file(1,rand(50,50), "test.nc"; varname = "vel")
fname = example_file(1,rand(50,50), "test2.nc"; varname = "ampl")

a = NCDataset(fname)
b = NCDataset(fname)

merge!(a, b)

close(a)
close(b)

rm("test.nc")
rm("test2.nc")
