using NCDatasets
fname = tempname()


NCDataset(fname,"c") do ds
  defVar(ds,"data",[10., 11., 12., 13.], ("time",), attrib = Dict(
      "add_offset" => 10.,
      "scale_factor" => 0.2))
end

# stored valued are [0., 5., 10., 15.]
# since 0.2 .* [0., 5., 10., 15.] .+ 10 is [10., 11., 12., 13.]

ds = NCDataset(fname);

@test ds["data"].var[:] ==  [0., 5., 10., 15.]

@test cfvariable(ds,"data")[:] == [10., 11., 12., 13.]

# neither add_offset nor scale_factor are applied
@test cfvariable(ds,"data", add_offset = nothing, scale_factor = nothing)[:] == [0, 5, 10, 15]

# add_offset is applied but not scale_factor
@test cfvariable(ds,"data", scale_factor = nothing)[:] == [10, 15, 20, 25]

# 0 is declared a fill value (add_offset and scale_factor are applied as usual)
@test isequal(cfvariable(ds,"data", fillvalue = 0)[:], [missing, 11., 12., 13.])

# 0 and 5 are declared a missing value
@test isequal(cfvariable(ds,"data", missing_value = (0,5))[:], [missing, missing, 12., 13.])


@test cfvariable(ds,"data", units = "days since 2000-01-01")[:] ==  [
    DateTime(2000,1,11), DateTime(2000,1,12), DateTime(2000,1,13), DateTime(2000,1,14)]

close(ds)

#rm(fname)
