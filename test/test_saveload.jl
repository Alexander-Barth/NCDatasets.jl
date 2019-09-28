using NCDatasets
using Test

filename = tempname()

A = [123. 2.; 45. 23.]
dt = [DateTime(2001,1,1), DateTime(2002,1,1)]

NCDatasets.ncsave(filename,Dict("A"  => A), "dt" => dt)

data = NCDatasets.ncload(filename)

@test data["A"] == A
@test data["dt"] == dt
