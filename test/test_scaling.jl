filename = tempname()
# The mode "c" stands for creating a new file (clobber)
ds = NCDatasets.Dataset(filename,"c")

# define the dimension "lon" and "lat" with the size 10 and 11 resp.
NCDatasets.defDim(ds,"lon",10)
NCDatasets.defDim(ds,"lat",11)

for T in [Int32,Float32]
    
    local v, data

    v = NCDatasets.defVar(ds,"scaled_var_$(T)",T,("lon","lat"))

    data = [-12.3*i + 23.4*j for i = 1:10, j = 1:11]
    offset = 20.
    factor = 0.1
    v.attrib["add_offset"] = offset
    v.attrib["scale_factor"] = factor
    
    v[:,:] = data
    @test v[:,:] ≈ data atol=1e-4
    
    # load without transformation (offset/scaling)
    @test v.var[:,:] ≈ (data .- offset)/factor atol=1e-4
    
    # write/read without transformation (offset/scaling)
    v.var[:,:] = data
    if eltype(v.var) <: Integer
        @test v.var[:,:] == round.(Int,data)
    else
        @test v.var[:,:] ≈ data
    end
end

NCDatasets.close(ds)
rm(filename)
