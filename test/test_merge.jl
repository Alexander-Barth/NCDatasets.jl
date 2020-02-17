using Test
using NCDatasets

cd(@__DIR__)

ampl = rand(50,50)

example_file(1,rand(50,50), "test.nc"; varname = "vel")
example_file(1, ampl, "test2.nc"; varname = "ampl")

a = NCDataset("test.nc", "a")
b = NCDataset("test2.nc")

@test sort!(keys(a)) == ["lat", "lon", "time", "vel"]

merge!(a, b)

@test sort!(keys(a)) == ["ampl", "lat", "lon", "time", "vel"]

x = Array(a["ampl"])
@test x == ampl

close(a)
close(b)

rm("test.nc")
rm("test2.nc")
