using Dates
using NCDatasets
using Test

var = 10.0:10.0:40.0
tax = DateTime(2001,1,1) .+ Day.(Int.(var))
fname = tempname()
fname2 = tempname()
ds = NCDataset(fname, "c")
defDim(ds, "time", Inf) # "unlimited"
defVar(ds, "time", tax, ("time",))
defVar(ds, "var", var, ("time",),deflatelevel=9)
close(ds)

NCDataset(fname, "r") do ds
    time = ds["time"]
    var = ds["var"]
    NCDataset(fname2, "c") do ds2
        defVar(ds2, "time", time, ("time",))
        defVar(ds2, "var",  var,  ("time",))
        @test "time" in unlimited(ds)
  end
end

NCDataset(fname, "r") do ds
    NCDataset(fname2, "c") do ds2
        defVar(ds2, ds["time"])
        defVar(ds2, ds["var"])
        @test "time" in unlimited(ds)
        isshuffled,isdeflated,deflatelevel = deflate(ds["var"])
        @test deflatelevel == 9
  end
end

rm(fname)
rm(fname2)
