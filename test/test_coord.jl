    using NCDatasets
using Test

fname = tempname()

for define_standard_name in [false,true]

    Dataset(fname,"c") do ds
        # Dimensions

        ds.dim["xi_rho"] = 6
        ds.dim["xi_u"] = 5
        ds.dim["xi_v"] = 6
        ds.dim["xi_psi"] = 5
        ds.dim["eta_rho"] = 6
        ds.dim["eta_u"] = 6
        ds.dim["eta_v"] = 5
        ds.dim["eta_psi"] = 5
        ds.dim["N"] = 30
        ds.dim["s_rho"] = 30
        ds.dim["s_w"] = 31
        ds.dim["tracer"] = 63
        ds.dim["ocean_time"] = Inf # unlimited dimension

        # Declare variables

        nclon_rho = defVar(ds,"lon_rho", Float64, ("xi_rho", "eta_rho"))
        nclon_rho.attrib["long_name"] = "longitude of RHO-points"
        nclon_rho.attrib["units"] = "degree_east"
        nclon_rho.attrib["field"] = "lon_rho, scalar"
        if define_standard_name
            nclon_rho.attrib["standard_name"] = "longitude"
        end

        nclat_rho = defVar(ds,"lat_rho", Float64, ("xi_rho", "eta_rho"))
        nclat_rho.attrib["long_name"] = "latitude of RHO-points"
        nclat_rho.attrib["units"] = "degree_north"
        nclat_rho.attrib["field"] = "lat_rho, scalar"
        if define_standard_name
            nclon_rho.attrib["standard_name"] = "latitude"
        end

        nclon_u = defVar(ds,"lon_u", Float64, ("xi_u", "eta_u"))
        nclon_u.attrib["long_name"] = "longitude of U-points"
        nclon_u.attrib["units"] = "degree_east"
        nclon_u.attrib["field"] = "lon_u, scalar"

        nclat_u = defVar(ds,"lat_u", Float64, ("xi_u", "eta_u"))
        nclat_u.attrib["long_name"] = "latitude of U-points"
        nclat_u.attrib["units"] = "degree_north"
        nclat_u.attrib["field"] = "lat_u, scalar"

        nczeta = defVar(ds,"zeta", Float32, ("xi_rho", "eta_rho", "ocean_time"))
        nczeta.attrib["long_name"] = "free-surface"
        nczeta.attrib["units"] = "meter"
        nczeta.attrib["time"] = "ocean_time"
        nczeta.attrib["coordinates"] = "lat_rho lon_rho"
        nczeta.attrib["field"] = "free-surface, scalar, series"

        ncubar = defVar(ds,"ubar", Float32, ("xi_u", "eta_u", "ocean_time"))
        ncubar.attrib["long_name"] = "vertically integrated u-momentum component"
        ncubar.attrib["units"] = "meter second-1"
        ncubar.attrib["time"] = "ocean_time"
        ncubar.attrib["coordinates"] = "lat_u lon_u"
        ncubar.attrib["field"] = "ubar-velocity, scalar, series"
    end


    ds = Dataset(fname)
    @test name(coord(ds["zeta"],"longitude")) == "lon_rho"
    @test name(coord(ds["ubar"],"longitude")) == "lon_u"
    @test coord(ds["ubar"],"foobar") == nothing
    close(ds)
end
