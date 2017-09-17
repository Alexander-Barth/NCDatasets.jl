sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"
# The mode "c" stands for creating a new file (clobber)

NCDatasets.Dataset(filename,"c") do ds

    # define the dimension "lon" and "lat" 
    NCDatasets.defDim(ds,"lon",sz[1])
    NCDatasets.defDim(ds,"lat",sz[2])


    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [Float32]
        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = fill(T(123),size(v))
        @test all(v[:,:][:] .== 123)

        # write scalar, 
        v.var[:,:] = T(100)
        @test all(v.var[:,:][:] .== 100)

    end
end
