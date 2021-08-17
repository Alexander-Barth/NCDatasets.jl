import NCDatasets
filename = tempname()

lons = 9.:30.
lats = 54.:66.
times = 0:10

# generate a NetCDF file

NCDatasets.NCDataset(filename,"c") do ds
    NCDatasets.defDim(ds,"lon",length(lons))
    NCDatasets.defDim(ds,"lat",length(lats))
    NCDatasets.defDim(ds,"time",Inf)

    tempvar = NCDatasets.defVar(ds,"temp",Float32,("lon","lat","time"))
    timevar = NCDatasets.defVar(ds,"time",Float64,("time",))

    for itime = 1:length(times)
        timevar[itime] = itime * 3600.0
    end
end


# append data

NCDatasets.NCDataset(filename,"a") do ds
    tempvar = ds["temp"]

    for itime = 1:length(times)
        #@show size(tempvar)
        #@show size(tempvar[:,:,itime])
        data = [i+j for i = 1:length(lons), j = 1:length(lats)]
        #tempvar[:,:,itime] = data
        tempvar[:,:,itime] = data[:,:,1:1]
    end
end

rm(filename)
