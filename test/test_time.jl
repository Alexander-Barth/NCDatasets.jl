
# test of low-level functions
@test datenum_julian(1,1,1,0,0,0) == 0

@test datenum_julian(-1,1,1)  ÷ (24*60*60*1000) == -366
@test datenum_julian(-2,1,1)  ÷ (24*60*60*1000) == -731
@test datenum_julian(-4,1,1)  ÷ (24*60*60*1000) == -1461
@test datenum_julian(-5,1,1)  ÷ (24*60*60*1000) == -1827
@test datenum_julian(-10,1,1)  ÷ (24*60*60*1000) == -3653
@test datenum_julian(-15,1,1)  ÷ (24*60*60*1000) == -5479
@test datenum_julian(-100,1,1)  ÷ (24*60*60*1000) == -36525

@test datenum_julian(-1,12,31,0,0,0) ÷ (24*60*60*1000) == -1
@test datenum_julian(-1,12,30,0,0,0) ÷ (24*60*60*1000) == -2
@test datenum_julian(-1,12,1,0,0,0) ÷ (24*60*60*1000) == -31
@test datenum_julian(-1,3,1,0,0,0) ÷ (24*60*60*1000) == -306
@test datenum_julian(-1,2,29,0,0,0) ÷ (24*60*60*1000) == -307
@test datenum_julian(-5,12,31)  ÷ (24*60*60*1000) == -1462
@test datenum_julian(-123,4,5)  ÷ (24*60*60*1000) == -44832




@test datetuple_julian(-1*24*60*60*1000) == (-1,12,31,0,0,0,0)
@test datetuple_julian(-366*24*60*60*1000) == (-1,1,1,0,0,0,0)
@test datetuple_julian(-731*24*60*60*1000) == (-2,1,1,0,0,0,0)
@test datetuple_julian(-3653*24*60*60*1000) == (-10,1,1,0,0,0,0)
@test datetuple_julian(-36525*24*60*60*1000) == (-100,1,1,0,0,0,0)
@test datetuple_julian(-367*24*60*60*1000) == (-2,12,31,0,0,0,0)
@test datetuple_julian(-44832*24*60*60*1000) == (-123,4,5,0,0,0,0)

#cftime.DatetimeJulian(01,01,01) - cftime.DatetimeJulian(-4713,1,1)
#datetime.timedelta(1721424, 0, 31)


@test datetuple_julian(-1721424*24*60*60*1000) == (-4713,1,1,0,0,0,0)
@test datenum_julian(-4713,1,1)  ÷ (24*60*60*1000) == -1721424


@test datetuple_julian(0*24*60*60*1000) == (1,1,1,0,0,0,0)
@test datetuple_julian(1*24*60*60*1000) == (1,1,2,0,0,0,0)
@test datetuple_julian(58*24*60*60*1000) == (1,2,28,0,0,0,0)
@test datetuple_julian(800000*24*60*60*1000) == (2191, 4, 14, 0, 0, 0, 0)


for n = -1000:800000
    #@show n
    y, m, d, h, mi, s, ms = datetuple_julian(n*24*60*60*1000)
    @test datenum_julian(y, m, d, h, mi, s, ms) ÷ (24*60*60*1000) == n
end

# test of DateTime structures

dt = DateTimeNoLeap(1959,12,31,23,39,59,123)
@test dt + Dates.Millisecond(7) == DateTimeNoLeap(1959,12,31,23,39,59,130)
@test dt + Dates.Second(7)      == DateTimeNoLeap(1959,12,31,23,40,6,123)
@test dt + Dates.Minute(7)      == DateTimeNoLeap(1959,12,31,23,46,59,123)
@test dt + Dates.Hour(7)        == DateTimeNoLeap(1960,1,1,6,39,59,123)
@test dt + Dates.Day(7)         == DateTimeNoLeap(1960,1,7,23,39,59,123)
@test dt + Dates.Month(7)       == DateTimeNoLeap(1960,7,31,23,39,59,123)
@test dt + Dates.Year(7)        == DateTimeNoLeap(1966,12,31,23,39,59,123)
@test dt + Dates.Month(24)      == DateTimeNoLeap(1961,12,31,23,39,59,123)

@test dt - Dates.Month(0)       == DateTimeNoLeap(1959,12,31,23,39,59,123)
@test dt - Dates.Month(24)      == DateTimeNoLeap(1957,12,31,23,39,59,123)
@test dt - Dates.Year(7)        == DateTimeNoLeap(1952,12,31,23,39,59,123)

# leap day
@test DateTimeAllLeap(2001,2,28) + Dates.Day(1) == DateTimeAllLeap(2001,2,29)
@test DateTimeNoLeap(2001,2,28) + Dates.Day(1) == DateTimeNoLeap(2001,3,1)
@test DateTimeJulian(2001,2,28) + Dates.Day(1) == DateTimeJulian(2001,3,1)
@test DateTimeJulian(1900,2,28) + Dates.Day(1) == DateTimeJulian(1900,2,29)
@test DateTime360(2001,2,28) + Dates.Day(1) == DateTime360(2001,2,29)
@test DateTime360(2001,2,29) + Dates.Day(1) == DateTime360(2001,2,30)

# reference values from python's cftime
@test DateTimeJulian(2000,1,1) + Dates.Day(1) == DateTimeJulian(2000,01,02)
@test DateTimeJulian(2000,1,1) + Dates.Day(12) == DateTimeJulian(2000,01,13)
@test DateTimeJulian(2000,1,1) + Dates.Day(123) == DateTimeJulian(2000,05,03)
@test DateTimeJulian(2000,1,1) + Dates.Day(1234) == DateTimeJulian(2003,05,19)
@test DateTimeJulian(2000,1,1) + Dates.Day(12345) == DateTimeJulian(2033,10,19)
@test DateTimeJulian(2000,1,1) + Dates.Day(12346) == DateTimeJulian(2033,10,20)
@test DateTimeJulian(1,1,1) + Dates.Day(1234678) == DateTimeJulian(3381,05,14)


#@test_broken DateTimeJulian(-4713,01,011) + Dates.Hour(58932297) == DateTimeJulian(2010,10,29,9,0,0)


# generic tests
function stresstest(::Type{DT}) where DT
    t0 = DT(1,1,1)
    @time for n = 1:800000
        #@show n
        t = t0 + Dates.Day(n)
        y, m, d, h, mi, s, ms = datetuple(t)
        @test DT(y, m, d, h, mi, s, ms) == t
    end
end

for DT in [
    DateTimeAllLeap,
    DateTimeNoLeap,
    DateTime360,
    DateTimeJulian]

    #stresstest(DT)

    dt = DT(1959,12,30, 23,39,59,123)
    @test year(dt) == 1959
    @test month(dt) == 12
    @test day(dt) == 30
    @test hour(dt) == 23
    @test minute(dt) == 39
    @test second(dt) == 59
    @test millisecond(dt) == 123

    @test string(DT(2001,2,20)) == "2001-02-20T00:00:00"

    @test datetuple(DT(1959,12,30,23,39,59,123)) == (1959,12,30,23,39,59,123)
end




t0,plength = timeunits("days since 1950-01-02T03:04:05Z")
@test t0 == DateTime(1950,1,2, 3,4,5)
@test plength == 86400000


t0,plength = timeunits("days since -4713-01-01T00:00:00Z")
@test t0 == DateTime(-4713,1,1)
@test plength == 86400000


t0,plength = timeunits("days since -4713-01-01")
@test t0 == DateTime(-4713,1,1)
@test plength == 86400000


t0,plength = timeunits("days since 2000-01-01 0:0:0")
@test t0 == DateTime(2000,1,1)
@test plength == 86400000

t0,plength = timeunits("days since 2000-1-1 0:0:0")
@test t0 == DateTime(2000,1,1)
@test plength == 86400000


# values from
# https://web.archive.org/web/20171129142108/https://www.hermetic.ch/cal_stud/chron_jdate.htm
# rounded to 3 hour

#@test_broken timedecode([2454142.125],"days since -4713-01-01T00:00:00","julian") ==
#    [DateTime(2007,02,10,03,0,0)]

# values from
# http://www.julian-date.com/ (setting GMT offset to zero)
# https://web.archive.org/web/20180212213256/http://www.julian-date.com/
#@test_broken timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian") ==
#    [DateTime(2010,11,11,9,0,0)]

# value from python's cftime
# print(cftime.DatetimeJulian(-4713,1,1) + datetime.timedelta(2455512,.375 * 24*60*60))
# 2010-10-29 09:00:00

@test timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian") ==
    [DateTimeJulian(2010,10,29,9,0,0)]

# values from
# https://web.archive.org/web/20180212214229/https://en.wikipedia.org/wiki/Julian_day

# Modified JD
@test timedecode([58160.6875],"days since 1858-11-17","standard") ==
    [DateTime(2018,2,11,16,30,0)]

# CNES JD
@test timedecode([24878.6875],"days since 1950-01-01","standard") ==
    [DateTime(2018,2,11,16,30,0)]

# Unix time
# wikipedia pages reports 1518366603 but it should be 1518366600
@test timedecode([1518366600],"seconds since 1970-01-01","standard") ==
    [DateTime(2018,2,11,16,30,0)]


#=
In [11]: cftime.DatetimeGregorian(1582,10,4) + datetime.timedelta(1)
Out[11]: cftime.DatetimeGregorian(1582, 10, 15, 0, 0, 0, 0, -1, 1)

In [12]: cftime.DatetimeProlepticGregorian(1582,10,4) + datetime.timedelta(1)
Out[12]: cftime.DatetimeProlepticGregorian(1582, 10, 5, 0, 0, 0, 0, -1, 1)

In [13]: cftime.DatetimeJulian(1582,10,4) + datetime.timedelta(1)
Out[13]: cftime.DatetimeJulian(1582, 10, 5, 0, 0, 0, 0, -1, 1)


=#
