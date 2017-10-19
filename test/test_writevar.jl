sz = (4,5)
filename = tempname()
#filename = "/tmp/test-9.nc"
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.Dataset(filename,"c")

# define the dimension "lon" and "lat"
NCDatasets.defDim(ds,"lon",sz[1])
NCDatasets.defDim(ds,"lat",sz[2])


# variables
for T in [UInt8,Int8,UInt16,Int16,UInt32,Int32,UInt64,Int64,Float32,Float64]
#for T in [Float32]
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


    # step range
    ref = zeros(sz)
    v[:,:] = 0
    
    ref[1:2:end,2:2:end] = 1
    v[1:2:end,2:2:end] = 1
    @test v[:,:] == ref
    
    # write scalar (different type)
    ref[1:2:end,2:2:end] = UInt8(2)
    v[1:2:end,2:2:end] = UInt8(2)
    @test v[:,:] == ref

    ref[1,1] = 3
    v[1,1] = 3
    
    @test v[:,:] == ref    
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

# write with StepRange
v[:,:] = 'h'
ref = fill('h',sz)

ref[1:2:end,1:2:end] = 'i'
v[1:2:end,1:2:end] = 'i'
@test v[:,:] == ref



ref = ['a'+i+2*j for i = 0:sz[1]-1, j= 0:sz[2]-1]
v[:,:] = ref

@test v.var[1:1,1:1] == ref[1:1,1:1]
@test v.var[1,1] == ref[1,1]
@test v.var[2:3,1] == ref[2:3,1]

#@test v[1,1] == ref[1,1]

@test NCDatasets.dimnames(v) == ("lon","lat")
@test NCDatasets.name(v) == "var-Char"

NCDatasets.close(ds)


