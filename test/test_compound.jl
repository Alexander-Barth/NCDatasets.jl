using NCDatasets
using NCDatasets: nc_create, NC_NETCDF4, NC_CLOBBER, nc_def_dim, nc_def_compound, nc_insert_compound, nc_def_var, nc_put_var, nc_close, NC_INT, nc_unsafe_put_var, libnetcdf, check, ncType


# mutable struct are not supported
# https://discourse.julialang.org/t/passing-an-array-of-structures-through-ccall/5194

struct s5
   i1::Cint
   i2::Cint
end

sz = (2,3)

compound_data = Array{s5,2}(undef,sz)


for j = 1:sz[2]
    for i = 1:sz[1]
        compound_data[i,j] = s5(i,j)
    end
end


ncid = nc_create(filename, NC_NETCDF4|NC_CLOBBER)


x_dimid = nc_def_dim(ncid, "x", sz[1])
y_dimid = nc_def_dim(ncid, "y", sz[2])

dimids = [x_dimid, y_dimid]

@assert ncType[Cint] == NC_INT

typeid = nc_def_compound(ncid, sizeof(s5), "sample_compound_type")

nc_insert_compound(ncid, typeid, "i1", fieldoffset(s5,1), NC_INT)
nc_insert_compound(ncid, typeid, "i2", fieldoffset(s5,2), NC_INT)

varid = nc_def_var(ncid, "data", typeid, reverse(dimids))

nc_put_var(ncid, varid, compound_data)
nc_close(ncid)


#run(`ncdump $filename`)
