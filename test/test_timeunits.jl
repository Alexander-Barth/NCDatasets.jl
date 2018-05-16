using Dates

# time

for (timeunit,factor) in [("days",1),("hours",24),("minutes",24*60),("seconds",24*60*60)]
    filename = tempname()

    NCDatasets.Dataset(filename,"c") do ds
        NCDatasets.defDim(ds,"time",3)
        v = NCDatasets.defVar(ds,"time",Float64,("time",))
        v.attrib["units"] = "$(timeunit) since 2000-01-01 00:00:00"
        v[:] = [DateTime(2000,1,2), DateTime(2000,1,3), DateTime(2000,1,4)]
        #v.var[:] = [1.,2.,3.]

        # write "scalar" value
        v[3] = DateTime(2000,1,5)
        @test v[3] == DateTime(2000,1,5)

        # time origin
        v[3] = 0
        @test v[3] == DateTime(2000,1,1)

    end

    NCDatasets.Dataset(filename,"r") do ds
        v2 = ds["time"].var[:]
        @test v2[1] == 1. * factor

        v2 = ds["time"][:]
        @test v2[1] == DateTime(2000,1,2)
    end
    rm(filename)

end


t0,plength = NCDatasets.timeunits("days since 1950-01-02T03:04:05Z")
@test t0 == DateTime(1950,1,2, 3,4,5)
@test plength == 86400000


t0,plength = NCDatasets.timeunits("days since -4713-01-01T00:00:00Z")
@test t0 == DateTime(-4713,1,1)
@test plength == 86400000


t0,plength = NCDatasets.timeunits("days since -4713-01-01")
@test t0 == DateTime(-4713,1,1)
@test plength == 86400000


t0,plength = NCDatasets.timeunits("days since 2000-01-01 0:0:0")
@test t0 == DateTime(2000,1,1)
@test plength == 86400000

t0,plength = NCDatasets.timeunits("days since 2000-1-1 0:0:0")
@test t0 == DateTime(2000,1,1)
@test plength == 86400000


# values from
# https://web.archive.org/web/20171129142108/https://www.hermetic.ch/cal_stud/chron_jdate.htm
# rounded to 3 hour

@test NCDatasets.timedecode([2454142.125],"days since -4713-01-01T00:00:00","julian") ==
    [DateTime(2007,02,10,03,0,0)]

# values from
# http://www.julian-date.com/ (setting GMT offset to zero)
# https://web.archive.org/web/20180212213256/http://www.julian-date.com/

@test NCDatasets.timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian") ==
    [DateTime(2010,11,11,9,0,0)]

# values from
# https://web.archive.org/web/20180212214229/https://en.wikipedia.org/wiki/Julian_day

# Modified JD
@test NCDatasets.timedecode([58160.6875],"days since 1858-11-17","standard") ==
    [DateTime(2018,2,11,16,30,0)]

# CNES JD
@test NCDatasets.timedecode([24878.6875],"days since 1950-01-01","standard") ==
    [DateTime(2018,2,11,16,30,0)]

# Unix time
# wikipedia pages reports 1518366603 but it should be 1518366600
@test NCDatasets.timedecode([1518366600],"seconds since 1970-01-01","standard") ==
    [DateTime(2018,2,11,16,30,0)]
