using NCDatasets
using Test

sz = (4,5)
#filename = "/tmp/test-9.nc"
# The mode "c" stands for creating a new file (clobber)

for format in [:netcdf4, :netcdf4_classic,
               :netcdf3_classic, :netcdf3_64bit_offset,
               :netcdf5_64bit_data
               ]

    #https://github.com/Unidata/netcdf-c/issues/1967
    if (format == :netcdf5_64bit_data) &&
        (sizeof(Csize_t) < 8)
        continue
    end

    filenamefmt = tempname()

    NCDataset(filenamefmt,"c"; format = format) do ds

        # define the dimension "lon" and "lat"
        defDim(ds,"lon",sz[1])
        defDim(ds,"lat",sz[2])

        # variables
        vfmt = defVar(ds,"var-Float32",Float32,("lon","lat"))
        vfmt.attrib["foob"] = 1

        # write array
        vfmt[:,:] = fill(Float32(123),size(vfmt))

        ds.attrib["attrib"] = 1

        # check content
        @test all(vfmt[:,:][:] .== 123)
    end
    rm(filenamefmt)
end

@test_throws NCDatasets.NetCDFError NCDataset(
    tempname(),"c";
    format = :netcdf3000_perfect_format)
