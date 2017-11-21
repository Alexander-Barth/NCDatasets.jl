sz = (40,10)
filename = tempname()
#filename = "/tmp/test-7.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat" 
    NCDatasets.defDim(ds,"lon",sz[1])
    NCDatasets.defDim(ds,"lat",sz[2])


    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [Float32]
        data = fill(T(123),sz)

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat");
                              shuffle = true,
                              chunksizes = [20,5],
                              deflatelevel = 9,
                              checksum = :nochecksum
                              )
        # check checksum method
        checksummethod = NCDatasets.checksum(v)
        @test checksummethod == :nochecksum

        # change checksum method
        NCDatasets.checksum(v,:fletcher32)
        checksummethod = NCDatasets.checksum(v)
        @test checksummethod == :fletcher32
        
        # check chunking
        storage,chunksizes = NCDatasets.chunking(v)
        @test storage == :chunked
        @test chunksizes[1] == 20

        # change chunking
        NCDatasets.chunking(v,:chunked,[3,3])
        storage,chunksizes = NCDatasets.chunking(v)
        @test storage == :chunked
        #@show chunksizes
        @test chunksizes[1] == 3
        
        # check compression
        shuffle,deflate,deflate_level = NCDatasets.deflate(v)
        @test shuffle == true
        @test deflate == true
        @test deflate_level == 9


        # change compression
        NCDatasets.deflate(v,false,true,4)
        shuffle,deflate,deflate_level = NCDatasets.deflate(v)
        @test shuffle == false
        @test deflate == true
        @test deflate_level == 4
                
        # write an array
        v[:,:] = data
        @test all(v[:,:] .== data)


    end
end
