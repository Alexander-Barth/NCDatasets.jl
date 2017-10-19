sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat" 
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]        
    #for T in [Float32]
        data = [T(i+2*j) for i = 1:sz[1], j = 1:sz[2]]

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = data
        @test v[:,:] == data[:,:]

        @test v[2,:] == data[2,:]

        @test v[:,3] == data[:,3]

        @test v[2,3] == data[2,3]

        # ignore extra index
        @test v[2,3,1,1] == data[2,3,1,1]

        # ignore extra index
        @test v[2:3,3,1,1] == data[2:3,3,1,1]
        
        
        # write scalar, 
        v.var[:,:] = T(100)
        @test all(v.var[:,:][:] .== 100)

    end
end
