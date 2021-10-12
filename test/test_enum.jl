using Test
using NCDatasets
import NCDatasets: nc_type, check, libnetcdf, nc_inq_user_type, NC_ENUM, ncType, jlType


function nc_def_enum(ncid::Integer,base_typeid::Integer,name)
    typeidp = Ref(NCDatasets.nc_type(0))
    check(ccall((:nc_def_enum,libnetcdf),Cint,(Cint,nc_type,Cstring,Ptr{nc_type}),ncid,base_typeid,name,typeidp))

    return typeidp[]
end

function nc_inq_enum(ncid::Integer,xtype::Integer)

    base_nc_typep = Ref(NCDatasets.nc_type(0))
    base_sizep = Ref(Csize_t(0))
    num_membersp = Ref(Csize_t(0))

    check(ccall((:nc_inq_enum,NCDatasets.libnetcdf),Cint,(Cint,nc_type,Ptr{UInt8},Ptr{NCDatasets.nc_type},Ptr{Csize_t},Ptr{Csize_t}),ncid,xtype,cname,base_nc_typep,base_sizep,num_membersp))

    type_name = unsafe_string(pointer(cname))
    base_nc_type = base_nc_typep[]
    num_members = num_membersp[]
    base_size = base_sizep[]

    return type_name,jlType[base_nc_type],base_size,num_members
end


function nc_insert_enum(ncid::Integer,xtype::Integer,name,value,
                        T = nc_inq_enum(ncid,typeid)[2])
    valuep = Ref{T}(value)
    check(ccall((:nc_insert_enum,libnetcdf),Cint,(Cint,nc_type,Cstring,Ptr{Nothing}),ncid,xtype,name,valuep))
end

function nc_inq_enum_member(ncid::Integer,xtype::Integer,idx::Integer,
                            T::Type = nc_inq_enum(ncid,typeid)[2])
    valuep = Ref{T}()
    cmember_name = zeros(UInt8,NCDatasets.NC_MAX_NAME+1)

    check(ccall((:nc_inq_enum_member,libnetcdf),Cint,(Cint,nc_type,Cint,Ptr{UInt8},Ptr{Nothing}),ncid,xtype,idx,cmember_name,valuep))

    member_name = unsafe_string(pointer(cmember_name))

    return member_name,valuep[]
end

function nc_inq_enum_ident(ncid::Integer,xtype::Integer,value)
    cidentifier = zeros(UInt8,NCDatasets.NC_MAX_NAME+1)
    check(ccall((:nc_inq_enum_ident,libnetcdf),Cint,(Cint,nc_type,Clonglong,Ptr{UInt8}),ncid,xtype,Clonglong(value),cidentifier))
    identifier = unsafe_string(pointer(cidentifier))
    return identifier
end


#=
# example from https://www.unidata.ucar.edu/software/netcdf/workshops/2011/groups-types/EnumCDL.html


ds = NCDataset("enum.nc");
name = "primary_cloud"

ncid = ds.ncid
varid = NCDatasets.nc_inq_varid(ncid,name)

ndims_ = NCDatasets.nc_inq_varndims(ncid,varid)

ndimsp = Ref(Cint(0))
cname = zeros(UInt8,NCDatasets.NC_MAX_NAME+1)
dimids = zeros(Cint,ndims_)
nattsp = Ref(Cint(0))
xtypep = Ref(NCDatasets.nc_type(0))

NCDatasets.check(ccall((:nc_inq_var,NCDatasets.libnetcdf),Cint,(Cint,Cint,Ptr{UInt8},Ptr{NCDatasets.nc_type},Ptr{Cint},Ptr{Cint},Ptr{Cint}),ncid,varid,cname,xtypep,ndimsp,dimids,nattsp))

xtype = xtypep[]

#nc_inq_enum(int ncid, nc_type xtype, char *name, nc_type *base_nc_typep,
#                 size_t *base_sizep, size_t *num_membersp);


#nc_inq_enum(int ncid, nc_type xtype, char *name, nc_type *base_nc_typep,
#                 size_t *base_sizep, size_t *num_membersp);


name,base_nc_type,base_size,num_members = nc_inq_enum(ncid,xtype)

idx = 0
T = NCDatasets.jlType[base_nc_type]

for idx = 0:num_members-1
    member_name,value = nc_inq_enum_member(ncid,xtype,T,idx)
    @show member_name,value
end
=#

# create a file with enum type

fname = tempname()
fname = "enum4.nc"
rm(fname)
ds = NCDataset(fname,"c");
ncid = ds.ncid

T = Int8

base_typeid = ncType[T]

type_name = "cloud_t"
typeid = nc_def_enum(ncid,base_typeid,type_name)


members = [
    "Clear" => 0, "Cumulonimbus" => 1, "Stratus" => 2,
    "Stratocumulus" => 3, "Cumulus" => 4, "Altostratus" => 5, "Nimbostratus" => 6,
    "Altocumulus" => 7, "Missing" => 127]


members_dict = Dict(members)

for (member_name,member_value) in members
    nc_insert_enum(ncid,typeid,member_name,member_value,T)
end

# read enum type

name2,size2,base_nc_type2,nfields2,class2 = nc_inq_user_type(ncid,typeid)

@test name2 == type_name
@test base_nc_type2 == base_typeid
@test nfields2 == length(members)
@test class2 == NC_ENUM


name2,base_nc_type2,base_size2,num_members2 = nc_inq_enum(ncid,typeid)

@test name2 == type_name
@test base_nc_type2 == T
@test base_size2 == sizeof(T)
@test num_members2 == length(members)


for idx = 0:num_members-1
    member_name,value = nc_inq_enum_member(ncid,xtype,idx,T)
    @test members_dict[member_name] == value
    identifier = nc_inq_enum_ident(ncid,xtype,value)
    @test identifier == member_name
end


close(ds)
#run(`ncdump -h $fname`)


# TODO:
# create variable and attribute with enum type
