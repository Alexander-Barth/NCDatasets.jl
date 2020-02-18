using Test
using NCDatasets

ampl = rand(50,50)
vel = rand(50,50)

fnames = [example_file(1, vel; varname = "vel"),
          example_file(1, ampl; varname = "ampl")]


dest = NCDataset(fnames[1], "a")
src = NCDataset(fnames[2])

@test sort!(keys(dest)) == ["lat", "lon", "time", "vel"]

merge!(dest, src)

@test sort!(keys(dest)) == ["ampl", "lat", "lon", "time", "vel"]

x = Array(dest["ampl"])
@test x[:,:,1] == ampl

close(dest)
close(src)

rm.(fnames)
