#module Time
import Base.Dates: UTInstant, Millisecond
import Base:+, -, string, show
using Base.Test


# Julian calendar
# https://web.archive.org/web/20180608122727/http://www.wwu.edu/skywise/leapyear.html
# The leap year was introduced in the Julian calendar in 46 BC. However, around 10 BC, it was found that the priests in charge of computing the calendar had been adding leap years every three years instead of the four decreed by Caesar (Vardi 1991, p. 239). As a result of this error, no more leap years were added until 8 AD. Leap years were therefore 45 BC, 42 BC, 39 BC, 36 BC, 33 BC, 30 BC, 27 BC, 24 BC, 21 BC, 18 BC, 15 BC, 12 BC, 9 BC, 8 AD, 12 AD, and every fourth year thereafter (Tøndering), until the Gregorian calendar was introduced (resulting in skipping three out of every four centuries).

isleapyear_julian(y) = (y > 0 ? y : y + 1) % 4 == 0


function datenum_julian(y, m, d, h = 0, mi = 0, s = 0, ms = 0)
    #@show y, m, d

    # days elapsed since beginning of the year for every month
    cm = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)

    if m < 1 || m > 12
        error("invalid month $(m)")
    end

    if d < 1 || d > (cm[m+1] - cm[m]) + isleapyear_julian(y)
        error("invalid day $(d) in $(@sprintf("%04d-%02d-%02dT%02d:%02d:%02d",y,m,d,h,mi,s))")
    end

    ms = 60*60*1000 * h +  60*1000 * mi + 1000*s + ms

    if y > 0
        # number of leap years prior to current year
        nleap = (y-1) ÷ 4

        # after Feb., count current leap day
        if isleapyear_julian(y) && (m > 2)
            nleap += 1
        end

        return (24*60*60*1000) * (cm[end] * (y-1) + cm[m] + (d-1) + nleap) + ms
    else
        # 1 BC, 5 BC, 9 BC,...
        nleap = (y-3) ÷ 4

        # after Feb., count current leap day
        if isleapyear_julian(y) && (m > 2)
            nleap += 1
        end
        dd = cm[end] * y + cm[m] + (d-1) + nleap
        return (24*60*60*1000) * (dd) + ms
    end
end

"""
time is in milliseconds
"""
function datetuple_julian(time::Number)
    days = time ÷ (24*60*60*1000)
    y = 0

    if days > 0
        # initially year y and days are zero-based
        y = 4 * (days ÷ (3*365+366))
        d2 = days - (y ÷ 4) * (3*365+366)
        if d2 == 4*365
            # the 4th year is not yet over
            y += 3
        else
            y += (d2 ÷ 365)
        end

        days = days - (365*y + y÷4)
    else


    end
    cm =
        if (y+1) % 4 == 0
            # leap year
            (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366)
        else
            (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)
        end

    mo = findmonth(cm,days)
    d = days  - cm[mo]

    ms = time % (24*60*60*1000)
    h = ms ÷ (60*60*1000)
    ms = ms % (60*60*1000)

    mi = ms ÷ (60*1000)
    ms = ms % (60*1000)

    s = ms ÷ 1000
    ms = ms % 1000

    # day start at 1 (not zero)
    d = d+1
    y = y+1

    #@show y,mo,d,h,mi,s,ms
    return (y,mo,d,h,mi,s,ms)
end


function datenum_cal(cm, y, m, d, h, mi, s, ms = 0)
    if m < 1 || m > 12
        error("invalid month $(m)")
    end

    if d < 1 || d > (cm[m+1] - cm[m])
        error("invalid day $(d) in $(@sprintf("%04d-%02d-%02dT%02d:%02d:%02d",y,m,d,h,mi,s))")
    end

    return 24*60*60*1000 * (cm[end] * (y-1) + cm[m] + (d-1)) + 60*60*1000 * h +  60*1000 * mi + 1000*s + ms
end

# Calendar with regular month-length

function findmonth(cm,t2)
    mo = length(cm)
    while cm[mo] > t2
        mo -= 1
    end
    return mo
end

function datetuple_cal(cm,time_::Number)
    timed_ = time_ ÷ (24*60*60*1000)

    y = timed_ ÷ cm[end]

    t2 = timed_ - cm[end]*y

    # find month
    mo = findmonth(cm,t2)

    d = t2  - cm[mo]

    ms = time_ % (24*60*60*1000)
    h = ms ÷ (60*60*1000)
    ms = ms % (60*60*1000)

    mi = ms ÷ (60*1000)
    ms = ms % (60*1000)

    s = ms ÷ (1000)
    ms = ms % (1000)

    # day and year start at 1 (not zero)
    d = d+1
    y = y+1

    return (y,mo,d,h,mi,s,ms)
end

datetuple_cal(cm,dt) = datetuple_cal(cm,Dates.value(dt.instant.periods))




abstract type AbstractCFDateTime end

const RegTime = Union{Dates.Millisecond,Dates.Second,Dates.Minute,Dates.Hour,Dates.Day}


for CFDateTime in [
    :DateTimeAllLeap,
    :DateTimeNoLeap,
    :DateTime360,
    :DateTimeJulian,
]
    @eval begin
        # adapted from
        # https://github.com/JuliaLang/julia/blob/aa301aa60bb7097182c55248572c861361a40b53/stdlib/Dates/src/types.jl
        # Licence MIT

        struct $CFDateTime <: AbstractCFDateTime
            instant::UTInstant{Millisecond}
            $CFDateTime(instant::UTInstant{Millisecond}) = new(instant)
        end
    end
end

"""
     DateTimeJulian(y, [m, d, h, mi, s, ms])
Construct a `DateTime` type by parts. Arguments must be convertible to [`Int64`](@ref).
"""
function DateTimeJulian(y::Int64, m::Int64=1, d::Int64=1,
                  h::Int64=0, mi::Int64=0, s::Int64=0, ms::Int64=0)


    return DateTimeJulian(UTInstant(Millisecond(datenum_julian(y, m, d, h, mi, s, ms))))
end

datetuple(dt::DateTimeJulian) = datetuple_julian(Dates.value(dt.instant.periods))


function +(dt::DateTimeJulian,Δ::Dates.Year)
    y,mo,d,h,mi,s,ms = datetuple(dt)
    return DateTimeJulian(y+Δ, mo, d, h, mi, s, ms)
end



for (CFDateTime,cmm) in [
    (:DateTimeAllLeap, (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366)),
    (:DateTimeNoLeap,  (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)),
    (:DateTime360,     (0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360)),
]
    @eval begin

"""
     CFDateTime(y, [m, d, h, mi, s, ms])
Construct a `DateTime` type by parts. Arguments must be convertible to [`Int64`](@ref).
"""
function $CFDateTime(y::Int64, m::Int64=1, d::Int64=1,
                  h::Int64=0, mi::Int64=0, s::Int64=0, ms::Int64=0)
    return $CFDateTime(UTInstant(Millisecond(datenum_cal($cmm,y, m, d, h, mi, s, ms))))
end

datetuple(dt::$CFDateTime) = datetuple_cal($cmm,dt)
+(dt::$CFDateTime,Δ::Dates.Year) = $CFDateTime(UTInstant(dt.instant.periods + Dates.Millisecond(Dates.value(Δ) * $cmm[end]*24*60*60*1000)))
    end
end


for CFDateTime in [
    :DateTimeAllLeap,
    :DateTimeNoLeap,
    :DateTime360,
    :DateTimeJulian,
]
    @eval begin

function string(dt::$CFDateTime)
    y,mo,d,h,mi,s,ms = datetuple(dt)
    return @sprintf("%04d-%02d-%02dT%02d:%02d:%02d",y,mo,d,h,mi,s)
end

function show(io::IO,dt::$CFDateTime)
    write(io, string(typeof(dt)), "(",string(dt),")")
end


+(dt::$CFDateTime,Δ::RegTime) = $CFDateTime(UTInstant(dt.instant.periods + Dates.Millisecond(Δ)))

function +(dt::$CFDateTime,Δ::Dates.Month)
    y,mo,d,h,mi,s,ms = datetuple(dt)
    mo = mo + Dates.value(Δ)
    mo2 = mod(mo - 1, 12) + 1

    y = y + (mo-mo2) ÷ 12
    return $CFDateTime(y, mo2, d,h, mi, s, ms)
end


end
    end


year(dt::AbstractCFDateTime) = datetuple(dt)[1]
month(dt::AbstractCFDateTime) = datetuple(dt)[2]
day(dt::AbstractCFDateTime) = datetuple(dt)[3]
hour(t::AbstractCFDateTime)   = datetuple(dt)[4]
minute(dt::AbstractCFDateTime) = datetuple(dt)[5]
second(dt::AbstractCFDateTime) = datetuple(dt)[6]
millisecond(dt::AbstractCFDateTime) = datetuple(dt)[7]


-(dt::AbstractCFDateTime,Δ) = dt + (-Δ)


function parseDT(::Type{T},str) where T
    str = replace(str,"T"," ")

    # remove Z time zone indicator
    # all times are assumed UTC anyway
    if endswith(str,"Z")
        str = str[1:end-1]
    end


    negativeyear = str[1] == '-'
    if negativeyear
        str = str[2:end]
    end

    t0 =
        if contains(str,":")
            DateTime(str,"y-m-d H:M:S")
        else
            DateTime(str,"y-m-d")
        end

    if negativeyear
        # year is negative
        t0 = DateTime(-Dates.year(t0),Dates.month(t0),Dates.day(t0),
                      Dates.hour(t0),Dates.minute(t0),Dates.second(t0))
    end

    return t0
end


"""
    t0,plength = timeunits(units,calendar = "standard")

Parse time units and returns the start time `t0` and the scaling factor
`plength` in milliseconds.
"""
function timeunits(::Type{DT},units) where DT
    tunit,starttime = strip.(split(units," since "))
    tunit = lowercase(tunit)

    t0 = parseDT(DT,starttime)

    # make sure that plength is 64-bit on 32-bit platforms
    plength =
        if (tunit == "days") || (tunit == "day")
            24*60*60*Int64(1000)
        elseif (tunit == "hours") || (tunit == "hour")
            60*60*Int64(1000)
        elseif (tunit == "minutes") || (tunit == "minute")
            60*Int64(1000)
        elseif (tunit == "seconds") || (tunit == "second")
            Int64(1000)
        end

    return t0,plength
end



"""
    t0,plength = timeunits(units,calendar = "standard")

Parse time units and returns the start time `t0` and the scaling factor
`plength` in milliseconds.
"""
function timeunits(units, calendar = "standard")
    DT =
        if (calendar == "standard") || (calendar == "gregorian")
            DateTime
        elseif calendar == "julian"
            DateTimeJulian
        else
            error("Unsupported calendar: $(calendar). NCDatasets supports only the standard (gregorian) calendar or Chronological Julian Date")
        end

    return timeunits(DT,units)
end


function timedecode(data,units,calendar = "standard")
    const t0,plength = timeunits(units,calendar)
    convert(x) = t0 + Dates.Millisecond(round(Int64,plength * x))
    return convert.(data)
end

function timeencode(data::Array{DateTime,N},units,calendar = "standard") where N
    const t0,plength = timeunits(units,calendar)
    convert(dt) = Dates.value(dt - t0) / plength
    return convert.(data)
end

# do not transform data is not a vector of DateTime
timeencode(data,units,calendar = "standard") = data



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


#@test datetuple_julian(-1*24*60*60*1000) == (1,1,2,0,0,0,0)

@test datetuple_julian(0*24*60*60*1000) == (1,1,1,0,0,0,0)
@test datetuple_julian(1*24*60*60*1000) == (1,1,2,0,0,0,0)
@test datetuple_julian(58*24*60*60*1000) == (1,2,28,0,0,0,0)
@test datetuple_julian(800000*24*60*60*1000) == (2191, 4, 14, 0, 0, 0, 0)


for n = 1:800000
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


@test_broken DateTimeJulian(-4713,01,011) + Dates.Hour(58932297) == DateTimeJulian(2010,10,29,9,0,0)


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

@test_broken timedecode([2454142.125],"days since -4713-01-01T00:00:00","julian") ==
    [DateTime(2007,02,10,03,0,0)]

# values from
# http://www.julian-date.com/ (setting GMT offset to zero)
# https://web.archive.org/web/20180212213256/http://www.julian-date.com/

@test_broken timedecode([2455512.375],"days since -4713-01-01T00:00:00","julian") ==
    [DateTime(2010,11,11,9,0,0)]

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
