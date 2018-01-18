using Base.Test
import NCDatasets

varname = "varname"
filename = tempname()

samples = [
    # Ints
    [1,2,3,4],

    # Floats
    [1. 2. 3.; 4. 5. 6.],
    
    # chars
    ['a','b','c'],
    ['a' 'b' 'c'; 'd' 'e' 'f'],
    
    # strings
    ["wieso","weshalb","warum"],
    ["wieso" "weshalb" "warum"; "why" "why" "whyyy"],
    map(x -> randstring(rand(3:10)), zeros(2,3,4)),    
]


for data in samples
    rm(filename;force=true)

    # write data
    ncid = NCDatasets.nc_create(filename,NCDatasets.NC_CLOBBER | NCDatasets.NC_NETCDF4)

    dimids = zeros(Cint,ndims(data))
    for i = 1:ndims(data)
        dimids[i] = NCDatasets.nc_def_dim(ncid, "dim-$(i)", size(data,i))
    end

    T = eltype(data)
    xtype = NCDatasets.ncType[T]
    varid = NCDatasets.nc_def_var(ncid, varname, xtype, dimids)
    NCDatasets.nc_put_var(ncid, varid, data)
    NCDatasets.nc_close(ncid)

    # load data

    ncid = NCDatasets.nc_open(filename,NCDatasets.NC_NOWRITE)
    varid = NCDatasets.nc_inq_varid(ncid,varname)
    xtype2 = NCDatasets.nc_inq_vartype(ncid,varid)

    @test xtype == xtype

    data2 = Array{T,ndims(data)}(size(data))
    NCDatasets.nc_get_var!(ncid,varid,data2)
    @test data == data2

    NCDatasets.nc_close(ncid)
end



# accept SubString as file name argument

ncid = NCDatasets.nc_create(filename,NCDatasets.NC_CLOBBER | NCDatasets.NC_NETCDF4)
NCDatasets.nc_close(ncid)

ncid = NCDatasets.nc_open(split("$(filename)#foo",'#')[1],NCDatasets.NC_NOWRITE)
NCDatasets.nc_close(ncid)
