using NCDatasets

fname = tempname()

# known quirks

NCDataset(fname,"c") do ds

    ds.attrib["single_element"] = [1]

    ds.attrib["vector_of_chars"] = ['a','b','c']

    ds.attrib["single_char"] = 'a'
    ds.attrib["multiple_char"] = "abc"

    # issue 12
    str = "some_string_with_null\0"
    ccall((:nc_put_att,NCDatasets.libnetcdf),Cint,
          (Cint,Cint,Cstring,NCDatasets.nc_type,Csize_t,Ptr{Nothing}),
          ds.ncid,NCDatasets.NC_GLOBAL,"attrib",NCDatasets.NC_CHAR,length(str),pointer.(str))

end

NCDataset(fname,"r") do ds
    # same behaviour in python netCDF4 1.3.1
    @test ds.attrib["single_element"] == 1

    # no chars in python and numpy.charray are not supported
    @test ds.attrib["vector_of_chars"] == "abc"

    # all chars are strings in python
    @test ds.attrib["single_char"] == "a"
    @test ds.attrib["multiple_char"] == "abc"

    # issue 12
    @test ds.attrib["attrib"] == "some_string_with_null"
end


# issue 197

# write an array with zero dimensions

b = dropdims([1.], dims=(1,))

NCDataset(fname,"c") do ds
    time = defDim(ds,"time",Inf)
    v = defVar(ds,"temp",Float32,("time",))
    ds["temp"][1:1] = b
    @test ds["temp"][1] == 1
end


NCDataset(fname,"c") do ds
    time = defDim(ds,"time",3)
    v = defVar(ds,"temp",Float32,("time",))
    ds["temp"][1:1] = b
    @test ds["temp"][1] == 1
end
