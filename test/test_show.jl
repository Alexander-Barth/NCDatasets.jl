using NCDatasets
using Test

# display
buf = IOBuffer()
filename = tempname()
NCDataset(filename,"c") do ds
    # define the dimension "lon" and "lat" with the size 100 and 110 resp.
    defDim(ds,"lon",100)
    defDim(ds,"lat",110)

    # define a global attribute
    ds.attrib["title"] = "this is a test file"
    v = defVar(ds,"temperature",Float32,("lon","lat"))
    v.attrib["units"] = "degree Celsius"

    show(buf,ds)
    @test occursin("temperature",String(take!(buf)))

    show(buf,ds.attrib)
    @test occursin("title",String(take!(buf)))

    show(buf,ds.dim)
    @test occursin("lon",String(take!(buf)))
    show(buf,ds.dim)
    @test occursin("lat",String(take!(buf)))

    show(buf,ds["temperature"])
    @test occursin("temperature",String(take!(buf)))

    show(buf,ds["temperature"].attrib)
    @test occursin("Celsius",String(take!(buf)))
end

ds = NCDataset(filename,"r")
closedvar = ds["temperature"]
close(ds)

# test displaying closed dataset
show(buf,ds)
@test occursin("closed",String(take!(buf)))

show(buf,ds.attrib)
@test occursin("closed",String(take!(buf)))

show(buf,closedvar)
@test occursin("closed",String(take!(buf)))
