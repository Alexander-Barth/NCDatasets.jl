using NCDatasets
using Test

sz = (4,5)
filename = tempname()
#filename = "/tmp/test-10.nc"
# The mode "c" stands for creating a new file (clobber)

NCDataset(filename,"c", attrib = [
    "title" => "NetCDF variable with grous"]) do ds

    # define the dimension "lon" and "lat"
    defDim(ds,"lon",sz[1])
    defDim(ds,"lat",sz[2])

    forecast = defGroup(ds,"forecast", attrib = [
        "model" => "my model"])
    v = defVar(forecast,"var",Float64,("lon","lat"))
    v[:,:] = fill(Float64(123),size(v))
end

NCDataset(filename) do ds
   forecast = NCDatasets.group(ds,"forecast")
   @test all(forecast["var"][:,:] .== 123)

    s = IOBuffer()
    show(s,ds)
    @test occursin("Groups",String(take!(s)))

end
