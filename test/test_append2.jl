import NCDatasets
filename = tempname()

lons = 9.:30.
lats = 54.:66.
times = 0:10

# generate a NetCDF file

NCDatasets.Dataset(filename,"c") do ds
    NCDatasets.defDim(ds,"lonc",length(lons))
    NCDatasets.defDim(ds,"latc",length(lats))
    NCDatasets.defDim(ds,"time",Inf)

    tempvar = NCDatasets.defVar(ds,"temp",Float32,("lonc","latc","time"))
    timevar = NCDatasets.defVar(ds,"time",Float64,("time",))

    for itime = 1:length(times)
        timevar[itime] = itime * 3600.0
    end
end


# append data

NCDatasets.Dataset(filename,"a") do ds
    tempvar = ds["temp"]

    for itime = 1:length(times)
        tempvar[:,:,itime] = [i+j for i = 1:length(lons), j = 1:length(lats)]
    end
end

rm(filename)
