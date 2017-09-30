using Base.Test
import NCDatasets
using NCDatasets

filename = tempname()

dimlen = 10

T = Int32
data = Vector{Vector{T}}(dimlen)
for i = 1:length(data)
    data[i] = T.(collect(1:i) + 100 * i) 
end

ncdata = Vector{NCDatasets.nc_vlen_t{T}}(dimlen)

for i = 1:length(data)
    ncdata[i] = NCDatasets.nc_vlen_t{T}(length(data[i]), pointer(data[i]))
end

varname = "varname"
vlentypename = "name-vlen"

ds = NCDatasets.Dataset(filename,"c",format=:netcdf4)
ncid = ds.ncid

ds.dim["casts"] = dimlen
#dimid = NCDatasets.nc_def_dim(ncid, "casts", dimlen)

v = NCDatasets.defVar(ds,varname,Vector{T},("casts",); typename = vlentypename)
#typeid = NCDatasets.nc_def_vlen(ncid, vlentypename, NCDatasets.ncType[T])
#varid = NCDatasets.nc_def_var(ncid, varname, typeid, [dimid])

varid = v.var.varid




NCDatasets.nc_put_var(ncid, varid, ncdata)
#v[:] = data
    
typeids = NCDatasets.nc_inq_typeids(ncid)
typeid = typeids[1]
name2,datum_size2,base_nc_type2 = NCDatasets.nc_inq_vlen(ncid,typeid)

@test name2 == vlentypename
@test NCDatasets.jlType[base_nc_type2] == T

close(ds)


#      if (nc_inq_vlen(ncid, typeid, varname, &size_in, &base_nc_type_in)) ERR;
#      if (base_nc_type_in != NC_INT || (size_in != sizeof(nc_vlen_t) || strcmp(name_in, VLEN_NAME))) ERR;



ds = NCDatasets.Dataset(filename)
ncid = ds.ncid

varid = NCDatasets.nc_inq_varid(ncid,varname)

typeids = NCDatasets.nc_inq_typeids(ncid)
#@show typeids

xtype = NCDatasets.nc_inq_vartype(ncid,varid)

@test xtype == typeids[1]

if xtype >= NCDatasets.NC_FIRSTUSERTYPEID 
    #@show xtype,NCDatasets.NC_VLEN

    typename,shape,base_nc_type,nfields,class = NCDatasets.nc_inq_user_type(ncid,xtype)

    #@show typename,shape,base_nc_type,nfields,class
    @test base_nc_type == NCDatasets.NC_INT

    T2 = NCDatasets.jlType[base_nc_type]

    @test T == T2
    if class == NCDatasets.NC_VLEN
        ncdata2 = Vector{NCDatasets.nc_vlen_t{T}}(dimlen)
        

        NCDatasets.nc_get_var!(ncid,varid,ncdata2)
        
        data2 = [unsafe_wrap(Vector{T},ncdata2[i].p,(ncdata2[i].len,)) for i = 1:dimlen]
        
        @test data == data2
    end
end

close(ds)

