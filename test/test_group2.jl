using NCDatasets
using Test

sz = (4,5)
filename = tempname()

NCDataset(filename,"c") do ds
    # define the dimension "lon" and "lat"
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    @test haskey(ds.dim,"lon")
    @test ds.dim["lon"] == sz[1]
    @test ds.dim["lat"] == sz[2]

    forecast = defGroup(ds,"forecast")
    v = defVar(forecast,"var",Float64,("lon","lat"))
    v[:,:] = fill(Float64(123),size(v))
end

NCDataset(filename) do ds
    @test haskey(ds.group,"forecast")

    forecast = ds.group["forecast"]

    @test all(forecast["var"][:,:] .== 123)

    s = IOBuffer()
    show(s,ds)
    @test occursin("Groups",String(take!(s)))

end

# test shadowing of dimensions
NCDataset(filename,"c") do ds
    ds.dim["lon"] = 1
    ds.dim["lat"] = 1

    forecast = defGroup(ds,"forecast")
    forecast.dim["lon"] = sz[1]
    forecast.dim["lat"] = sz[2]
    v = defVar(forecast,"var",Float64,("lon","lat"))
    @test size(v) == sz
end
