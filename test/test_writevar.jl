sz = (4,5)
filename = tempname()
filename = "/tmp/test-9.nc"
# The mode "c" stands for creating a new file (clobber)
ds = Dataset(filename,"c")

# define the dimension "lon" and "lat"
NCDatasets.defDim(ds,"lon",sz[1])
NCDatasets.defDim(ds,"lat",sz[2])


# variables
for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
    #for T in [UInt8]
    # write array
    v = NCDatasets.defVar(ds,"var-$T",T,("lon","lat"))

    # write array
    v[:,:] = fill(T(123),size(v))
    @test all(v[:,:][:] .== 123)

    # write scalar
    v[:,:] = T(100)
    @test all(v[:,:][:] .== 100)

    # write array (different type)
    v[:,:] = fill(123,size(v))
    @test all(v[:,:][:] .== 123)

    # write scalar (different type)
    v[:,:] = 100
    @test all(v[:,:][:] .== 100)

    # using StepRange as index
    # write array
    v[1:end,1:end] = fill(T(123),size(v))
    @test all(v[:,:][:] .== 123)

    # write scalar
    v[1:end,1:end] = T(100)
    @test all(v[:,:][:] .== 100)

    # write array (different type)
    v[1:end,1:end] = fill(123,size(v))
    @test all(v[:,:][:] .== 123)

    # write scalar (different type)
    v[1:end,1:end] = 100
    @test all(v[:,:][:] .== 100)
end

v = NCDatasets.defVar(ds,"var-Char",Char,("lon","lat"))

# write array (without transformation)
v.var[:,:] = fill('a',size(v))
@test all(v.var[:,:][:] .== 'a')

# write scalar
v.var[:,:] = 'b'
@test all(v.var[:,:][:] .== 'b')

# write array (with transformation)
v[:,:] = fill('c',size(v))
@test all(v[:,:][:] .== 'c')

# write scalar
v[:,:] = 'd'
@test all(v[:,:][:] .== 'd')

# using StepRange as index
# write array (without transformation)
v.var[1:end,1:end] = fill('e',size(v))
@test all(v.var[1:end,1:end][:] .== 'e')

# write scalar
v.var[1:end,1:end] = 'f'
@test all(v.var[1:end,1:end][:] .== 'f')

# write array (with transformation)
v[1:end,1:end] = fill('g',size(v))
@test all(v[1:end,1:end][:] .== 'g')

# write scalar
v[1:end,1:end] = 'h'
@test all(v[1:end,1:end][:] .== 'h')


@test dimnames(v) == ("lon","lat")
close(ds)


