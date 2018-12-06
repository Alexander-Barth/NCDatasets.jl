fname = tempname()

# known quirks

NCDatasets.Dataset(fname,"c") do ds
    
    ds.attrib["single_element"] = [1]

    ds.attrib["vector_of_chars"] = ['a','b','c']

    ds.attrib["single_char"] = 'a'
    
    # issue 12
    str = "some_string_with_null\0"
    ccall((:nc_put_att,NCDatasets.libnetcdf),Cint,
          (Cint,Cint,Cstring,NCDatasets.nc_type,Csize_t,Ptr{Nothing}),
          ds.ncid,NCDatasets.NC_GLOBAL,"attrib",NCDatasets.NC_CHAR,length(str),pointer.(str))
    
end

NCDatasets.Dataset(fname,"r") do ds
    # same behaviour in python netCDF4 1.3.1
    @test ds.attrib["single_element"] == 1

    # no chars in python and numpy.charray are not supported
    @test ds.attrib["vector_of_chars"] == "abc"

    # all chars are strings in python
    @test ds.attrib["single_char"] == "a"

    # issue 12
    @test ds.attrib["attrib"] == "some_string_with_null"
end
