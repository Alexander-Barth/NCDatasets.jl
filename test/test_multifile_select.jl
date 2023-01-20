using NCDatasets, Dates

function gen_file(time)
    fname = tempname()
    NCDataset(fname,"c") do ds
        defVar(ds,"time",time,("time",));
    end
    return fname
end

fnames = [
    gen_file(DateTime(2000,1,1):Day(1):DateTime(2009,12,31)),
    gen_file(DateTime(2010,1,1):Day(1):DateTime(2012,12,31))
]

mfds = NCDataset(fnames; aggdim="time")
mfds2 = NCDatasets.@select(mfds, 2005 ≤ Dates.year(time) ≤ 2011)

@test all(y -> 2005 <= y <= 2011, Dates.year.(mfds2["time"][:]))

close(mfds)
