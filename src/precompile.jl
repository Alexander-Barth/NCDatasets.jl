@compile_workload begin
    println("Precompile NCDatasets 4");

    fname = tempname()
    ds = NCDataset(fname,"c");
    sz = (2,2)

    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    for T in [UInt8,Int8,UInt16,Int16,
              UInt32,Int32,UInt64,Int64,
              Float32,Float64,
              Char,String]
        local data, scalar_data
        data, scalar_data =
            if T == String
                [Char(i+60) * Char(j+60) for i = 1:sz[1], j = 1:sz[2]], "abcde"
            else
                [T(i+2*j) for i = 1:sz[1], j = 1:sz[2]], T(100)
            end

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = data
        v[1,1] = scalar_data
        data2 = data[:,:]
        scalar_data2 = data[1,1]

        v.attrib["attrib-$T"] = scalar_data
        ds.attrib["attrib-$T"] = scalar_data

        scalar_data2 = v.attrib["attrib-$T"]
        scalar_data2 = ds.attrib["attrib-$T"]
    end

    io = IOBuffer();
    show(io,ds);
    close(ds);

end

