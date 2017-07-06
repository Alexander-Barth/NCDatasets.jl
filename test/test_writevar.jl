    sz = (4,5)
    filename = tempname()
    #filename = "/tmp/test-8.nc"
    # The mode "c" stands for creating a new file (clobber)
    ds = Dataset(filename,"c")

    # define the dimension "lon" and "lat"
    NCDatasets.defDim(ds,"lon",sz[1])
    NCDatasets.defDim(ds,"lat",sz[2])


    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [UInt8]
        # write array
        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = fill(T(123),size(v))
        @test all(v[:,:][:] .== 123)

        # write scalar
        v[:,:] = T(100)
        @test all(v[:,:][:] .== 100)

        # write array (different type)
        v[:,:] = fill(123,size(v))
        @test all(v[:,:][:] .== 123)

        # write scalar (different type)
        v[:,:] = 100
        @test all(v[:,:][:] .== 100)

    end

    close(ds)


