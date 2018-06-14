using Base.Test
#include("../src/time.jl")



# reference value from Meeus, Jean (1998)
# launch of Sputnik 1

@test datetuple_standard(2_436_116 - 2_400_001) == (1957, 10, 4)
@test datenum_gregjulian(1957,10,4,true) == 36115

@test datenum_gregjulian(333,1,27,false) == -557288

# function testcal(tonum,totuple)
#     num = 1234567890123

#     @test tonum(totuple(num)...) == num
# end

# for (tonum,totuple) in [
#     (datenum_standard,datetuple_standard)
#     (datenum_julian,datetuple_julian)
#     (datenum_pgregorian,datetuple_pgregorian)
#     (datenum_AllLeap,datetuple_AllLeap)
#     (datenum_NoLeap,datetuple_NoLeap)
#     (datenum_360,datetuple_360)
# ]
#     testcal(tonum,totuple)
# end

# @show datetuple_pgregorian(-532783)
# @show datetuple_pgregorian(-532784)
# @show datetuple_pgregorian(-532785)
# @show datetuple_pgregorian(-532786)

# @show datenum_gregjulian(-100, 2, 28,true)
# @show datenum_gregjulian(-100, 3, 1,true)

function mytest()
    for (tonum,totuple) in [
        (datenum_standard,datetuple_standard),
        (datenum_julian,datetuple_julian),
        (datenum_pgregorian,datetuple_pgregorian),
        (datenum_allleap,datetuple_allleap),
        (datenum_noleap,datetuple_noleap),
        (datenum_360,datetuple_360),
    ]
        @time for Z = -2_400_000 + DATENUM_OFFSET : 11 : 600_000 + DATENUM_OFFSET
            y,m,d = totuple(Z)
            @test tonum(y,m,d) == Z
        end
    end
end


#mytest()

#=
@time for Z = -2_400_000 + DATENUM_OFFSET : 600_000 + DATENUM_OFFSET
    y,m,d = datetuple_standard(Z)
    @test datenum_standard(y,m,d) == Z

    y,m,d = datetuple_julian(Z)
    @test datenum_julian(y,m,d) == Z

    y,m,d = datetuple_pgregorian(Z)
    @test datenum_pgregorian(y,m,d) == Z

    #@test datenum_trunc(y,m,d,Z >= 2299161 - 2_400_001) == datenum_gregjulian(y,m,d,Z >= 2299161 - 2_400_001)
end
=#


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
@test DateTimeNoLeap(2001,2,28)  + Dates.Day(1) == DateTimeNoLeap(2001,3,1)
@test DateTimeJulian(2001,2,28)  + Dates.Day(1) == DateTimeJulian(2001,3,1)
@test DateTimeJulian(1900,2,28)  + Dates.Day(1) == DateTimeJulian(1900,2,29)
@test DateTime360(2001,2,28)     + Dates.Day(1) == DateTime360(2001,2,29)
@test DateTime360(2001,2,29)     + Dates.Day(1) == DateTime360(2001,2,30)



@test DateTimeAllLeap(2001,2,29) - DateTimeAllLeap(2001,2,28) == Dates.Day(1)
@test DateTimeNoLeap(2001,3,1)   - DateTimeNoLeap(2001,2,28)  == Dates.Day(1)
@test DateTimeJulian(2001,3,1)   - DateTimeJulian(2001,2,28)  == Dates.Day(1)
@test DateTimeJulian(1900,2,29)  - DateTimeJulian(1900,2,28)  == Dates.Day(1)
@test DateTime360(2001,2,29)     - DateTime360(2001,2,28)     == Dates.Day(1)
@test DateTime360(2001,2,30)     - DateTime360(2001,2,29)     == Dates.Day(1)


# reference values from python's cftime
@test DateTimeJulian(2000,1,1) + Dates.Day(1) == DateTimeJulian(2000,01,02)
@test DateTimeJulian(2000,1,1) + Dates.Day(12) == DateTimeJulian(2000,01,13)
@test DateTimeJulian(2000,1,1) + Dates.Day(123) == DateTimeJulian(2000,05,03)
@test DateTimeJulian(2000,1,1) + Dates.Day(1234) == DateTimeJulian(2003,05,19)
@test DateTimeJulian(2000,1,1) + Dates.Day(12345) == DateTimeJulian(2033,10,19)
@test DateTimeJulian(2000,1,1) + Dates.Day(12346) == DateTimeJulian(2033,10,20)
@test DateTimeJulian(1,1,1) + Dates.Day(1234678) == DateTimeJulian(3381,05,14)



# generic tests
function stresstest_DateTime(::Type{DT}) where DT
    t0 = DT(1,1,1)
    @time for n = -800000:800000
        #@show n
        t = t0 + Dates.Day(n)
        y, m, d, h, mi, s, ms = datetuple(t)
        @test DT(y, m, d, h, mi, s, ms) == t
    end
end

for DT in [
    DateTimeStandard,
    DateTimeJulian,
    DateTimePGregorian,
    DateTimeAllLeap,
    DateTimeNoLeap,
    DateTime360
]

    dt = DT(1959,12,30, 23,39,59,123)
    @test Dates.year(dt) == 1959
    @test Dates.month(dt) == 12
    @test Dates.day(dt) == 30
    @test Dates.hour(dt) == 23
    @test Dates.minute(dt) == 39
    @test Dates.second(dt) == 59
    @test Dates.millisecond(dt) == 123

    @test string(DT(2001,2,20)) == "2001-02-20T00:00:00"
    @test datetuple(DT(1959,12,30,23,39,59,123)) == (1959,12,30,23,39,59,123)

    #stresstest_DateTime(DT)
end




t0,plength = timeunits("days since 1950-01-02T03:04:05Z")
@test t0 == DateTimeStandard(1950,1,2, 3,4,5)
@test plength == 86400000


t0,plength = timeunits("days since -4713-01-01T00:00:00Z")
@test t0 == DateTimeStandard(-4713,1,1)
@test plength == 86400000


t0,plength = timeunits("days since -4713-01-01")
@test t0 == DateTimeStandard(-4713,1,1)
@test plength == 86400000


t0,plength = timeunits("days since 2000-01-01 0:0:0")
@test t0 == DateTimeStandard(2000,1,1)
@test plength == 86400000

t0,plength = timeunits("days since 2000-1-1 0:0:0")
@test t0 == DateTimeStandard(2000,1,1)
@test plength == 86400000

# value from python's cftime
# print(cftime.DatetimeJulian(-4713,1,1) + datetime.timedelta(2455512,.375 * 24*60*60))
# 2010-10-29 09:00:00

#@test timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian")
#   == DateTimeJulian(2010,10,29,09)

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


# The Julian Day Number (JDN) is the integer assigned to a whole solar day in
# the Julian day count starting from noon Universal time, with Julian day
# number 0 assigned to the day starting at noon on Monday, January 1, 4713 BC,
# proleptic Julian calendar (November 24, 4714 BC, in the proleptic Gregorian
# calendar),

# Julian Day Number of 12:00 UT on January 1, 2000, is 2 451 545
# https://web.archive.org/web/20180613200023/https://en.wikipedia.org/wiki/Julian_day


@test timedecode(DateTimeStandard,2_451_545,"days since -4713-01-01T12:00:00") ==
    DateTimeStandard(2000,01,01,12,00,00)

# Note for DateTime, 1 BC is the year 0!
# DateTime(1,1,1)-Dates.Day(1)
# 0000-12-31T00:00:00

@test timedecode(DateTime,2_451_545,"days since -4713-11-24T12:00:00") ==
    DateTime(2000,01,01,12,00,00)

@test timedecode(DateTimePGregorian,2_451_545,"days since -4714-11-24T12:00:00") ==
    DateTimePGregorian(2000,01,01,12,00,00)


@test timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian", prefer_datetime = false) ==
    [DateTimeJulian(2010,10,29,9,0,0)]



# Transition between Julian and Gregorian Calendar

#=
In [11]: cftime.DatetimeGregorian(1582,10,4) + datetime.timedelta(1)
Out[11]: cftime.DatetimeGregorian(1582, 10, 15, 0, 0, 0, 0, -1, 1)

In [12]: cftime.DatetimeProlepticGregorian(1582,10,4) + datetime.timedelta(1)
Out[12]: cftime.DatetimeProlepticGregorian(1582, 10, 5, 0, 0, 0, 0, -1, 1)

In [13]: cftime.DatetimeJulian(1582,10,4) + datetime.timedelta(1)
Out[13]: cftime.DatetimeJulian(1582, 10, 5, 0, 0, 0, 0, -1, 1)
=#

@test DateTimeStandard(1582,10,4) + Dates.Day(1) == DateTimeStandard(1582,10,15)
@test DateTimePGregorian(1582,10,4) + Dates.Day(1) == DateTimePGregorian(1582,10,5)
@test DateTimeJulian(1582,10,4) + Dates.Day(1) == DateTimeJulian(1582,10,5)




@test datetuple(timedecode(0,"days since -4713-01-01T12:00:00","julian", prefer_datetime = false)) ==
    (-4713, 1, 1, 12, 0, 0, 0)


dt = reinterpret(DateTimeStandard, DateTimeJulian(1900,2,28))
@test typeof(dt) == DateTimeStandard
@test datetuple(dt) == (1900,2,28,0, 0, 0, 0)

dt = reinterpret(DateTime, DateTimeJulian(1900,2,28))
@test typeof(dt) == DateTime
@test Dates.year(dt) == 1900
@test Dates.month(dt) == 2
@test Dates.day(dt) == 28

# check ordering

@test DateTimeStandard(2000,01,01) < DateTimeStandard(2000,01,02)
@test DateTimeStandard(2000,01,01) ≤ DateTimeStandard(2000,01,01)

@test DateTimeStandard(2000,01,03) > DateTimeStandard(2000,01,02)
@test DateTimeStandard(2000,01,03) ≥ DateTimeStandard(2000,01,01)

datetuple(dt::DateTime) = (Dates.year(dt),Dates.month(dt),Dates.day(dt),
                           Dates.hour(dt),Dates.minute(dt),Dates.second(dt),
                           Dates.millisecond(dt))


# check convertion

for T1 in [DateTimePGregorian,DateTimeStandard,DateTime]
    for T2 in [DateTimePGregorian,DateTimeStandard,DateTime]
        # datetuple should not change after 1582-10-15
        # for Gregorian Calendars
        dt1 = T1(2000,01,03)
        dt2 = convert(T2,dt1)

        @test datetuple(dt1) == datetuple(dt2)
    end
end


for T1 in [DateTimeStandard,DateTimeJulian]
    for T2 in [DateTimeStandard,DateTimeJulian]
        # datetuple should not change before 1582-10-15
        # for Julian Calendars
        dt1 = T1(200,01,03)
        dt2 = convert(T2,dt1)

        @test datetuple(dt1) == datetuple(dt2)
    end
end

for T1 in [DateTimePGregorian,DateTimeJulian,DateTimeStandard,DateTime]
    for T2 in [DateTimePGregorian,DateTimeJulian,DateTimeStandard,DateTime]
        # verify that durations (even accross 1582-10-15) are maintained
        # after convert
        dt1 = [T1(2000,01,03), T1(-100,2,20)]
        dt2 = convert.(T2,dt1)
        @test dt1[2]-dt1[1] == dt2[2]-dt2[1]
    end
end
