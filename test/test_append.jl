sz = (4,5)
filename = tempname()

# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds
    # define the dimension "lon" and "lat" 
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    v = NCDatasets.defVar(ds,"var1",UInt8,("lon","lat"))
    v[:,:] = fill(123,size(v))
end

# The "a" stands for appending to an existing file

NCDatasets.Dataset(filename,"a") do ds
    v = NCDatasets.defVar(ds,"var2",UInt16,("lon","lat"))
    v[:,:] = fill(1234,size(v))

    # check if there are two variables
    @test length(keys(ds)) == 2
end

rm(filename)
