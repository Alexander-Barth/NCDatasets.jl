sz = (4,5)
filename = tempname()
#filename = "/tmp/test-10.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds    
    # define the dimension "lon" and "lat" 
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    @test haskey(ds.dim,"lon")
    @test ds.dim["lon"] == sz[1]
    @test ds.dim["lat"] == sz[2]
    
    forecast = NCDatasets.defGroup(ds,"forecast")   
    v = NCDatasets.defVar(forecast,"var",Float64,("lon","lat"))
    v[:,:] = fill(Float64(123),size(v))
end

NCDatasets.Dataset(filename) do ds
    @test haskey(ds.group,"forecast")
    
    forecast = ds.group["forecast"]

    @test all(forecast["var"][:,:] .== 123)

    s = IOBuffer()
    show(s,ds)
    @test occursin("Groups",String(take!(s)))

end

#@show NCDatasets.Dataset(filename)

