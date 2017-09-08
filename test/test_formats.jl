sz = (4,5)
#filename = "/tmp/test-9.nc"
# The mode "c" stands for creating a new file (clobber)

for format in [:netcdf4, :netcdf4_classic, :netcdf3_classic, :netcdf3_64bit_offset]
    filename = tempname()
    NCDatasets.Dataset(filename,"c"; format = format) do ds

        # define the dimension "lon" and "lat"
        NCDatasets.defDim(ds,"lon",sz[1])
        NCDatasets.defDim(ds,"lat",sz[2])
        
        # variables
        v = NCDatasets.defVar(ds,"var-Float32",Float32,("lon","lat"))
        
        # write array
        v[:,:] = fill(Float32(123),size(v))
        
        # check content
        @test all(v[:,:][:] .== 123)
    end
    rm(filename)
end

@test_throws ErrorException NCDatasets.Dataset(tempname(),"c";
                                      format = :netcdf3000_perfect_format)


