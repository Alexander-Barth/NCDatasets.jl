sz = (4,5)
filename = tempname()
#filename = "/tmp/test-10.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds    
    # define the dimension "lon" and "lat" 
    NCDatasets.defDim(ds,"lon",sz[1])
    NCDatasets.defDim(ds,"lat",sz[2])

    forecast = NCDatasets.defGroup(ds,"forecast")   
    v = NCDatasets.defVar(forecast,"var",Float64,("lon","lat"))
    v[:,:] = fill(Float64(123),size(v))
end

NCDatasets.Dataset(filename) do ds
   forecast = NCDatasets.group(ds,"forecast")    
   @test all(forecast["var"][:,:] .== 123)

    s = IOBuffer()
    show(s,ds)
    @test contains(String(take!(s)),"Groups")

end

#@show NCDatasets.Dataset(filename)

