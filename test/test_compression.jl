sz = (40,40)
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
        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        data = fill(T(123),size(v))
        #@show NCDatasets.chunking(v)
        NCDatasets.chunking(v,:chunked,[3,3])
        #@show NCDatasets.chunking(v)
        @test NCDatasets.chunking(v)[1] == :chunked

        #NCDatasets.deflate(v.var,true,true,9)

        NCDatasets.deflate(v,true,true,9)
        @test NCDatasets.deflate(v) == (true,true,9)

        # write an array
        v[:,:] = data
        @test all(v[:,:] .== data)


    end
end
