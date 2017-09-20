sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat" 
    #NCDatasets.defDim(ds,"lon",sz[1])
    #NCDatasets.defDim(ds,"lat",Inf)

    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = Inf

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [Float32]
        data = zeros(T,sz)
        
        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))

        for j = 1:sz[2]
            data[:,j] = T(j)
            v[:,j] = T(j)
        end

        @test all(v[:,:] == data)

    end
end
