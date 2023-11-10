@compile_workload begin
    println("Precompile NCDatasets");

    fname = tempname()
    ds = NCDataset(fname,"c");
    lon = -180:180
    lat = -90:90
    time2 = DateTime(2000,1,1):Day(1):DateTime(2000,1,3)
    SST = randn(length(lon),length(lat),length(time2))

    defVar(ds,"lon",lon,("lon",));
    defVar(ds,"lat",lat,("lat",));
    defVar(ds,"time",time2,("time",));
    defVar(ds,"SST",SST,("lon","lat","time"));

    io = IOBuffer();
    show(io,ds);
    sum(ds["SST"][:,:,:])
    close(ds);
end

