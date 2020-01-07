# Experimental features

## Multi-file support

Multiple files can also be aggregated over a given dimensions (or the record dimension). In this example, 3 sea surface temperature fields from the
1992-01-01 to 1992-01-03 are aggregated using the OpenDAP service from PODAAC.

```
using NCDatasets, Printf, Dates

function url(dt)
  doy = @sprintf("%03d",Dates.dayofyear(dt))
  y = @sprintf("%04d",Dates.year(dt))
  yyyymmdd = Dates.format(dt,"yyyymmdd")
  return "https://podaac-opendap.jpl.nasa.gov:443/opendap/allData/ghrsst/data/GDS2/L4/GLOB/CMC/CMC0.2deg/v2/$y/$doy/$(yyyymmdd)120000-CMC-L4_GHRSST-SSTfnd-CMC0.2deg-GLOB-v02.0-fv02.0.nc"
end

ds = Dataset(url.(DateTime(1992,1,1):Dates.Day(1):DateTime(1992,1,3)),aggdim = "time");
SST2 = ds["analysed_sst"][:,:,:];
close(ds)
```

If there is a network or server issue, you will see an error message like "NetCDF: I/O failure".


## Experimental functions

```@docs
NCDatasets.ancillaryvariables
NCDatasets.filter
```
