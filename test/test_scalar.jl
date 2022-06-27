using NCDatasets
using Test

# define scalar
filename = tempname()
NCDataset(filename,"c") do ds
    v = defVar(ds,"scalar",Float32,())
    v[:] = 123.f0
end

NCDataset(filename,"r") do ds
    v2 = ds["scalar"][:]
    @test typeof(v2) == Float32
    @test v2 == 123.f0

    v2 = ds["scalar"][]
    @test typeof(v2) == Float32
    @test v2 == 123.f0
end
rm(filename)

# define scalar with .=
filename = tempname()
NCDataset(filename,"c") do ds
    v = defVar(ds,"scalar",Float32,())
    v .= 1234.f0
    nothing
end

NCDataset(filename,"r") do ds
    v2 = ds["scalar"][:]
    @test v2 == 1234
end
rm(filename)
