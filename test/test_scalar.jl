using NCDatasets
using Test


for (T,data) in ((Float32,123.f0),
                 (String,"foo"))
    local filename
    # define scalar
    filename = tempname()
    NCDataset(filename,"c") do ds
        v = defVar(ds,"scalar",T,())
        v[:] = data
    end

    NCDataset(filename,"r") do ds
        v2 = ds["scalar"][:]
        @test typeof(v2) == T
        @test v2 == data

        v2 = ds["scalar"][]
        @test typeof(v2) == T
        @test v2 == data
    end
    rm(filename)

    # define scalar with .=
    filename = tempname()
    NCDataset(filename,"c") do ds
        v = defVar(ds,"scalar",T,())
        v .= data
        nothing
    end

    NCDataset(filename,"r") do ds
        v2 = ds["scalar"][:]
        @test v2 == data
    end
    rm(filename)
end
