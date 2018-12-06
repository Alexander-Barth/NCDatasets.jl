sz = (4,5)
#filename = "/tmp/test-9.nc"
# The mode "c" stands for creating a new file (clobber)

for format in [:netcdf4, :netcdf4_classic, :netcdf3_classic, :netcdf3_64bit_offset]
    filenamefmt = tempname()
    NCDatasets.Dataset(filenamefmt,"c"; format = format) do ds

        # define the dimension "lon" and "lat"
        NCDatasets.defDim(ds,"lon",sz[1])
        NCDatasets.defDim(ds,"lat",sz[2])

        # variables
        vfmt = NCDatasets.defVar(ds,"var-Float32",Float32,("lon","lat"))

        # write array
        vfmt[:,:] = fill(Float32(123),size(vfmt))

        # check content
        @test all(vfmt[:,:][:] .== 123)
    end
    rm(filenamefmt)
end

@test_throws NCDatasets.NetCDFError NCDatasets.Dataset(
    tempname(),"c";
    format = :netcdf3000_perfect_format)
