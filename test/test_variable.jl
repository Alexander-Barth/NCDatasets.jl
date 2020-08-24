using Test
using Dates
using Printf
using NCDatasets

sz = (4,5)
filename = tempname()
#filename = "/tmp/test-6.nc"
#if isfile(filename)
#    rm(filename)
#end

# The mode "c" stands for creating a new file (clobber)
NCDatasets.NCDataset(filename,"c") do ds

    # define the dimension "lon" and "lat"
    ds.dim["lon"] = sz[1]
    ds.dim["lat"] = sz[2]

    v = NCDatasets.defVar(ds,"small",Float64,("lon","lat"))
#    @test_throws Union{NCDatasets.NetCDFError,DimensionMismatch} v[:] = zeros(sz[1]+1,sz[2])
    @test_throws NCDatasets.NetCDFError v[1:sz[1],1:sz[2]] = zeros(sz[1]+1,sz[2])
    @test_throws NCDatasets.NetCDFError v[sz[1]+1,1] = 1
    @test_throws NCDatasets.NetCDFError v[-1,1] = 1

    # variables
    for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64,
              Char,String]
    #for T in [String]
        local data
        data, scalar_data =
            if T == String
                [Char(i+60) * Char(j+60) for i = 1:sz[1], j = 1:sz[2]], "abcde"
            else
                [T(i+2*j) for i = 1:sz[1], j = 1:sz[2]], T(100)
            end

        v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))
        v[:,:] = data
        @test v[:,:] == data[:,:]

        # issue #33
        @test Array(v) == data

        @test v[2,:] == data[2,:]

        @test v[:,3] == data[:,3]

        @test v[2,3] == data[2,3]

        # ignore extra index
        @test v[2,3,1,1] == data[2,3,1,1]

        # ignore extra index
        @test v[2:3,3,1,1] == data[2:3,3,1,1]

        @test v[[1,2,3],:] == data[[1,2,3],:]

        # write scalar
        v.var[1,1] = scalar_data
        v.var[:,:] .= scalar_data
        @test all(v.var[:,:][:] .== scalar_data)

        # stridded write and read
        v[1:2:end,1:2:end] = data[1:2:end,1:2:end]
        @test all(v[1:2:end,1:2:end] .== data[1:2:end,1:2:end])
    end
end

# quick interface
NCDataset(filename,"c") do ds
    data = Int32[i+3*j for i = 1:sz[1], j = 1:sz[2]]
    defVar(ds,"temp",data,("lon","lat"), attrib = [
        "units" => "degree_Celsius",
        "long_name" => "Temperature"
    ])
    @test ds["temp"][:] == data
    @test eltype(ds["temp"].var) == Int32
    @test ds.dim["lon"] == sz[1]
    @test ds.dim["lat"] == sz[2]

    # load in-place
    data2 = similar(data)
    NCDatasets.load!(ds["temp"].var,data2,:,:)
    @test data2 == data

    data2 = zeros(eltype(data),sz[1],2)
    NCDatasets.load!(ds["temp"].var,data2,:,1:2)
    @test data2 == data[:,1:2]

    # test Union{Missing,T}
    defVar(ds,"foo",[missing,1.,2.],("dim",), fillvalue = -9999.)
    @test fillvalue(ds["foo"]) == -9999.
    @test isequal(ds["foo"][:], [missing,1.,2.])

    # test Union{Missing,T} and default fill value (issue #38)
    defVar(ds,"foo_default_fill_value",[missing,1.,2.],("dim",))
    @test fillvalue(ds["foo_default_fill_value"]) == fillvalue(Float64)
    @test isequal(ds["foo_default_fill_value"][:], [missing,1.,2.])


    for DT in [DateTime,
               DateTimeStandard,
               DateTimeJulian,
               DateTimeProlepticGregorian,
               DateTimeAllLeap,
               DateTimeNoLeap,
               DateTime360Day
               ]

        # test DateTime et al., array
        data_dt = [DT(2000,1,1),DT(2000,1,2),DT(2000,1,3)]
        defVar(ds,"foo_$(DT)",data_dt,("dim",))
        data_dt2 = ds["foo_$(DT)"][:]
        @test isequal(convert.(DT,data_dt2), data_dt)

        # test DateTime et al. with missing array
        data_dt = [missing,DT(2000,1,2),DT(2000,1,3)]
        defVar(ds,"foo_$(DT)_with_fill_value",data_dt,("dim",))

        data_dt2 = ds["foo_$(DT)_with_fill_value"][:]
        @test ismissing(data_dt2[1])

        @test isequal(convert.(DT,data_dt2[2:end]), data_dt[2:end])
    end

    defVar(ds,"scalar",123.)
    @test ds["scalar"][:] == 123.
end
rm(filename)

# check bounds error
filename = tempname()
NCDataset(filename,"c") do ds
    defVar(ds,"temp",randn(10,11),("lon","lat"))
    @test_throws NCDatasets.NetCDFError defVar(ds,"salt",randn(10,12),("lon","lat"))
end
rm(filename)

# check error for unknown variable
filename = tempname()
NCDataset(filename,"c") do ds
    @test_throws NCDatasets.NetCDFError ds["does_not_exist"]
end
rm(filename)


# issue 23
# return type using CartesianIndex

filename = tempname()
ds = NCDataset(filename, "c");
ds.dim["lon"] = 5;
ds.dim["lat"] = 10;
ds.dim["time"] = Inf;

ncvar = defVar(ds, "var", Int64, ("lon", "lat", "time"));

nt = 25;
data = reshape(1:5*10*nt, 5, 10, nt);
ncvar[:,:,1:nt] = data;
close(ds);

ds = NCDataset(filename);
start = 1;
all(data[CartesianIndex(1, 1), start:end] .== ds["var"][CartesianIndex(1, 1), start:end])
data11 = ds["var"][CartesianIndex(1, 1), start:end]
close(ds)

@test typeof(data11[1]) == Int64
rm(filename)

# issue #36

x, y = collect(1:10), collect(10:18)

NCDataset("temp1.nc", "c") do ds
      defDim(ds, "x", length(x))
      defVar(ds, "x", x, ("x",))
      defDim(ds, "y", length(y))
      defVar(ds, "y", y, ("y",))
end

rm("temp1.nc")
