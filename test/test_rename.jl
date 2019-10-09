using NCDatasets
using Test

fname = tempname()


Dataset(fname,"c") do ds
    # Dimensions

    ds.dim["xi_rho"] = 6
    ds.dim["eta_rho"] = 6
    ds.dim["N"] = 30

    # Declare variables

    nclon_rho = defVar(ds,"lon_rho", Float64, ("xi_rho", "eta_rho"))
    nclon_rho.attrib["long_name"] = "longitude of RHO-points"
    nclon_rho.attrib["units"] = "degree_east"
    nclon_rho.attrib["field"] = "lon_rho, scalar"

    nclat_rho = defVar(ds,"lat_rho", Float64, ("xi_rho", "eta_rho"))
    nclat_rho.attrib["long_name"] = "latitude of RHO-points"
    nclat_rho.attrib["units"] = "degree_north"
    nclat_rho.attrib["field"] = "lat_rho, scalar"

end


ds = Dataset(fname,"a")
@test ds.dim["N"] == 30
NCDatasets.renameDim(ds,"N","NNN")
@test ds.dim["NNN"] == 30

@test "lon_rho" in keys(ds)
renameVar(ds,"lon_rho","longitude_rho")
@test "longitude_rho" in keys(ds)
close(ds)
