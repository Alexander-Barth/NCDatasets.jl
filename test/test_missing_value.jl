using NCDatasets
using DataStructures

# same behaviour as Python's netCDF4 1.5.8 and XArray 0.21.1

filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDataset(filename,"c")


ds.dim["dim"] = 3

# single missing value

missing_value = 123.
v = defVar(ds,"var1",Float64,("dim",), attrib = OrderedDict("missing_value" => missing_value))
data = [0., 1., 123.]
v.var[:] = data
@test isequal(v[:],[0.,1.,missing])

# 2 missing values
missing_value = [123., 124.]
v = defVar(ds,"var2",Float64,("dim",), attrib = OrderedDict("missing_value" => missing_value))
data = [0., 123., 124.]
v.var[:] = data
@test isequal(v[:],[0.,missing,missing])


# missing values of wrong type
v =  @test_warn "var3" defVar(ds,"var3",Float64,("dim",), attrib = OrderedDict("missing_value" => "value of wrong type"))
data = [0., 1., 2.]
v.var[:] = data
@test isequal(v[:],[0.,1.,2.])

close(ds)

