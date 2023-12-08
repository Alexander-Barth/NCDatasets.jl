import NCDatasets
filename = tempname()

lons = 9.:30.
lats = 54.:66.
times = 0:10

# generate a NetCDF file

NCDataset(filename,"c") do ds
    defDim(ds,"lon",length(lons))
    defDim(ds,"lat",length(lats))
    defDim(ds,"time",Inf)

    tempvar = defVar(ds,"temp",Float32,("lon","lat","time"))
    timevar = defVar(ds,"time",Float64,("time",))

    for itime = 1:length(times)
        timevar[itime] = itime * 3600.0
    end
end


# append data

NCDataset(filename,"a") do ds
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
