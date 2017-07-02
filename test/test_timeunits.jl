# time

for (timeunit,factor) in [("days",1),("hours",24),("minutes",24*60),("seconds",24*60*60)]
    filename = tempname()

    Dataset(filename,"c") do ds
        defDim(ds,"time",3)            
        v = defVar(ds,"time",Float64,("time",))
        v.attrib["units"] = "$(timeunit) since 2000-01-01 00:00:00"
        v[:] = [DateTime(2000,1,2), DateTime(2000,1,3), DateTime(2000,1,4)]
        #v.var[:] = [1.,2.,3.]
    end

    Dataset(filename,"r") do ds
        v2 = ds["time"].var[:]
        @test v2[1] == 1. * factor
        
        v2 = ds["time"][:]
        @test v2[1] == DateTime(2000,1,2)
    end
    rm(filename)

end
