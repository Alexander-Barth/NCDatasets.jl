using NCDatasets

sz = (40,10)
filename = tempname()
#filename = "/tmp/test-7.nc"
# The mode "c" stands for creating a new file (clobber)

NCDataset(filename,"c") do ds

    # define the dimension "lon" and "lat"
    defDim(ds,"lon",sz[1])
    defDim(ds,"lat",sz[2])


    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [Float32]
        local data
        data = fill(T(123),sz)

        v = defVar(ds,"var-$T",T,("lon","lat");
                              shuffle = true,
                              chunksizes = [20,5],
                              deflatelevel = 9,
                              checksum = :nochecksum
                              )
        # check checksum method
        checksummethod = checksum(v)
        @test checksummethod == :nochecksum

        # change checksum method
        checksum(v,:fletcher32)
        checksummethod = checksum(v)
        @test checksummethod == :fletcher32

        # check chunking
        storage,chunksizes = chunking(v)
        @test storage == :chunked
        @test chunksizes[1] == 20

        # change chunking
        chunking(v,:chunked,[3,3])
        storage,chunksizes = chunking(v)
        @test storage == :chunked
        #@show chunksizes
        @test chunksizes[1] == 3

        # check compression
        isshuffled,isdeflated,deflate_level = deflate(v)
        @test isshuffled == true
        @test isdeflated == true
        @test deflate_level == 9


        if VERSION >= v"1.6"
            # change compression
            # Note: shuffling cannot be disabled once applied
            # https://github.com/Unidata/netcdf-c/issues/1713#issuecomment-625462059
            # Behaviour changed in NetCDF 4.7 and 4.8
            deflate(v,true,true,4)
            isshuffled,isdeflated,deflate_level = deflate(v)
            @test isshuffled == true
            @test isdeflated == true
            @test deflate_level == 4
        end

        # write an array
        v[:,:] = data
        @test all(v[:,:] .== data)


        v = defVar(ds,"var2-$T",T,("lon","lat");
                              shuffle = true,
                              chunksizes = [20,5],
                              deflatelevel = 9,
                              checksum = :fletcher32
                              )
        checksummethod = checksum(v)
        @test checksummethod == :fletcher32

    end
end
