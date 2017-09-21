sz = (4,5)
filename = tempname()

Dataset(filename,"c") do ds

    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    v = defVar(ds,"temperature",Float32,("lon","lat"))

    # write attributes
    v.attrib["units"] = "degree Celsius"
    v.attrib["comment"] = "this is a string attribute with unicode Ω ∈ ∑ ∫ f(x) dx "

    # check presence of attribute
    @test haskey(v.attrib,"comment")
    @test "comment" in v.attrib

    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
        # scalar attribute
        name = "scalar-attrib-$T"
        #@show name
        v.attrib[name] = T(123)

        if T == Int64
            # not supported in NetCDF, converted as Int32
            @test typeof(v.attrib[name]) == Int32
        else
            @test typeof(v.attrib[name]) == T
        end

        @test v.attrib[name] == 123


        # vector attribute
        name = "vector-attrib-$T"
        #@show name
        v.attrib[name] = T[1,2,3,4]

        if T == Int64
            # not supported in NetCDF, converted as Int32
            @test eltype(v.attrib[name]) == Int32
        else
            @test eltype(v.attrib[name]) == T
        end

        @test v.attrib[name] == [1,2,3,4]        
    end

    # arrays cannot be attributes
    @test_throws ErrorException v.attrib["error_attrib"] = zeros(2,2)
    
end

