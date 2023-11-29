




@compile_workload begin
    function sample(sizes,types)
        fname = tempname()
        ds = NCDataset(fname,"c");

        dimnames = "dim-" .* string.(1:length(sizes))

        for (dn,len) in zip(dimnames,sizes)
            ds.dim[dn] = len
        end

        for T in [UInt8,Int8,UInt16,Int16,
                  UInt32,Int32,UInt64,Int64,
                  Float32,Float64,
                  Char,String]

            scalar_data =
                if T == String
                    "abcde"
                elseif T == Char
                    'a'
                else
                    T(100)
                end

            for nd = 1:length(sizes)
                sz = sizes[1:nd]
                data = fill(scalar_data,sz)

                v = defVar(ds,"var-$nd-$T",T,dimnames[1:nd])
                ind = ntuple(i -> :,length(sz))
                v[ind...] = data
                data2 = v[ind...]

                ind = ntuple(i -> 1,length(sz))
                v[ind...] = scalar_data
                scalar_data2 = v[ind...]

                # attributes
                v.attrib["attrib-$T"] = scalar_data
                v.attrib["attrib-vec-$T"] = [scalar_data]
                scalar_data2 = v.attrib["attrib-$T"]
                vec_data2 = v.attrib["attrib-vec-$T"]

                v2 = ds["var-$nd-$T"]
            end

            ds.attrib["attrib-vec-$T"] = [scalar_data]
            ds.attrib["attrib-$T"] = scalar_data
            scalar_data2 = ds.attrib["attrib-$T"]
            vec_data2 = ds.attrib["attrib-vec-$T"]
        end

        io = IOBuffer();
        show(io,ds);
        close(ds);

        ds = NCDataset(fname,"r");
        close(ds)
        rm(fname)
    end

    types = [
        UInt8,Int8,
        UInt16,Int16,
        UInt32,Int32,
        UInt64,Int64,
        Float32,Float64,
        Char,String
    ]

    sample((2,2,2),types)
end
