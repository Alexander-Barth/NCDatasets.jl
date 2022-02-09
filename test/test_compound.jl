using NCDatasets
using NCDatasets: nc_create, NC_NETCDF4, NC_CLOBBER, nc_def_dim, nc_def_compound, nc_insert_compound, nc_def_var, nc_put_var, nc_close, NC_INT, nc_unsafe_put_var, libnetcdf, check, ncType


# mutable struct are not supported
# https://discourse.julialang.org/t/passing-an-array-of-structures-through-ccall/5194

struct s8
   i1::Cint
   i2::Cint
   f1::Cfloat
   d1::Cdouble
end

sz = (2,3)

data = Array{s8,2}(undef,sz)


for j = 1:sz[2]
    for i = 1:sz[1]
        data[i,j] = s8(i,j,1.2,2.3)
    end
end


T = eltype(data)

ncid = nc_create(filename, NC_NETCDF4|NC_CLOBBER)

x_dimid = nc_def_dim(ncid, "x", sz[1])
y_dimid = nc_def_dim(ncid, "y", sz[2])

dimids = [x_dimid, y_dimid]

typeid = nc_def_compound(ncid, sizeof(T), "sample_compound_type")

for i = 1:fieldcount(T)
    nctype = ncType[fieldtype(T,i)]
    nc_insert_compound(
        ncid, typeid,
        fieldname(T,i),
        fieldoffset(T,i), nctype)
end

varid = nc_def_var(ncid, "data", typeid, reverse(dimids))

nc_put_var(ncid, varid, data)
nc_close(ncid)


#run(`ncdump $filename`)
