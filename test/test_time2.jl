import Base.Dates: UTInstant, Millisecond
import Base:+, -, string, show
using Base.Test

# Introduction of the Gregorian Calendar 1582-10-15
const GREGORIAN_CALENDAR = (1582,10,15)

# Introduction of the Gregorian Calendar 1582-10-15
# expressed in MJD (modified Julian day)
# MJD is the number of days since midnight on 1858-11-17)


#const MJD_OFFSET = 2_400_000.5 # for Julian Days
const MJD_OFFSET = 0 # for Modified Julian Days


const MJD_GREGORIAN_CALENDAR = -100840 + MJD_OFFSET


function MJDFromDate(year,month,day,gregorian::Bool)
    # turn year equal to -1 (1 BC) into year = 0
    if year < 0
        year = year+1
    end

    if gregorian
        # bring year in range of 1601 to 2000
        ncycles = (2000 - year) ÷ 400
        year = year + 400 * ncycles
        return MJDFromDate_optim(year,month,day,gregorian) - ncycles*146_097
    else
        return MJDFromDate_optim(year,month,day,gregorian)
    end

end


# the algorithm does not work for -100:03:01 and before in
# the proleptic Gregorian Calendar

function MJDFromDate_(year,month,day,gregorian::Bool)

    if month <= 2
        # if the date is January or February, it is considered
        # the 13rth or 14th month of the preceeding year
        year = year - 1
        month = month + 12
    end


    B =
        if gregorian
            A = year ÷ 100
            #@show A
            2 - A + A ÷ 4
        else
            0
        end

    #@show year,B,trunc(Int,365.25 * (year + 4716))
    #@show trunc(Int,30.6001 * (month+1)), B
    #@show day, B
    Z = trunc(Int,365.25 * (year + 4716)) + trunc(Int,30.6001 * (month+1)) + day + B - 2401525
    return Z + MJD_OFFSET
end


function MJDFromDate_optim(year,month,day,gregorian::Bool)

    if month <= 2
        # if the date is January or February, it is considered
        # the 13rth or 14th month of the preceeding year
        year = year - 1
        month = month + 12
    end

    B =
        if gregorian
            A = year ÷ 100
            2 - A + A ÷ 4
        else
            0
        end


    # benchmark shows that it is 40% faster replacing
    # trunc(Int,365.25 * (year + 4716))
    # by
    # (1461 * (year + 4716)) ÷ 4
    #
    # and other floating point divisions

    # Z is the Julian Day plus 0.5
    # 1461/4 is 365.25
    # 153/5 is 30.6

    Z = (1461 * (year + 4716)) ÷ 4 + (153 * (month+1)) ÷ 5 + day + B - 2401525
    # Modified Julan Day
    return Z + MJD_OFFSET
end

# Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,  Virginia. p. 63


JD = 2_400_000.5
# 1858 November 17 00:00:00

JD = 2436_116.31
# 1957 October 4

"""
    year, month, day = DateFromJD_trunc(Z::Integer,gregorian::Bool)

Compyte year, month and day from Z which is the Julian Day plus 0.5,
for the gregorian (true) or Julian (false) calendar.

For example:
Z = 2400_001 for the 1858 November 17 00:00:00

Algorithm:

Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,
Virginia. p. 63
"""
function DateFromMJD(Z,gregorian::Bool)
    # Z is Julian Day plus 0.5
    Z = Z + 2_400_001 - MJD_OFFSET

    A =
        if gregorian
            # lets magic happen
            α = trunc(Int, (Z - 1867_216.25)/36524.25)
            #@show α,Z - 1867_216.25
            Z + 1 + α - (α ÷ 4)
        else
            Z
        end

    # even more magic...
    B = A + 1524
    C = trunc(Int, (B - 122.1) / 365.25)
    D = trunc(Int, 365.25 * C)
    E = trunc(Int, (B-D)/30.6001)

    day = B - D - trunc(Int,30.6001 * E)
    month = (E < 14 ? E-1 : E-13)
    y = (month > 2 ? C - 4716 : C - 4715)

    # turn year 0 into year -1 (1 BC)
    if y <= 0
        y = y-1
    end
    return y,month,day
end






"""
time is in milliseconds
"""
function timetuplefrac(time::Number)
    days = time ÷ (24*60*60*1000)
    ms = time % (24*60*60*1000)
    h = ms ÷ (60*60*1000)
    ms = ms % (60*60*1000)

    mi = ms ÷ (60*1000)
    ms = ms % (60*1000)

    s = ms ÷ 1000
    ms = ms % 1000
    return (days,h,mi,s,ms)
end

function datenumfrac(days,h,mi,s,ms)
    ms = 60*60*1000 * h +  60*1000 * mi + 1000*s + ms
    return (24*60*60*1000) * days + ms
end


DateFromMJD_PGregorian(Z) = DateFromMJD(Z,true)
DateFromMJD_Julian(Z) = DateFromMJD(Z,false)
DateFromMJD_Standard(Z) = DateFromMJD(Z,Z >= MJD_GREGORIAN_CALENDAR)


MJDFromDate_PGregorian(y,m,d) = MJDFromDate(y,m,d,true)
MJDFromDate_Julian(y,m,d) = MJDFromDate(y,m,d,false)
MJDFromDate_Standard(y,m,d) = MJDFromDate(y,m,d,(y,m,d) >= GREGORIAN_CALENDAR)


function datenum_cal(cm, y, m, d)
    if m < 1 || m > 12
        error("invalid month $(m)")
    end

    if d < 1 || d > (cm[m+1] - cm[m])
        error("invalid day $(d) in $(@sprintf("%04d-%02d-%02dT%02d:%02d:%02d",y,m,d,h,mi,s))")
    end

    return cm[end] * (y-1) + cm[m] + (d-1)
end

# Calendar with regular month-length

function findmonth(cm,t2)
    mo = length(cm)
    while cm[mo] > t2
        mo -= 1
    end
    return mo
end

function datetuple_cal(cm,timed_::Number)
    y = fld(timed_, cm[end])
    t2 = timed_ - cm[end]*y

    # find month
    mo = findmonth(cm,t2)
    d = t2 - cm[mo]

    # day and year start at 1 (not zero)
    d = d+1
    y = y+1

    return (y,mo,d)
end


for (calendar,cmm) in [
    ("AllLeap", (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366)),
    ("NoLeap",  (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)),
    ("360",    (0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360)),
]
    @eval begin
        $(Symbol(:MJDFromDate_,calendar))(y, m, d) = datenum_cal($cmm, y, m, d)
        $(Symbol(:DateFromMJD_,calendar))(days) = datetuple_cal($cmm,days)
    end
end


abstract type AbstractCFDateTime end

const RegTime = Union{Dates.Millisecond,Dates.Second,Dates.Minute,Dates.Hour,Dates.Day}


for calendar in ["Standard","Julian","PGregorian","AllLeap","NoLeap","360"]
    CFDateTime = Symbol(:DateTime,calendar)
    symdatetuple = Symbol(:datetuple_,calendar)
    symdatenum = Symbol(:datenum_,calendar)

    @eval begin

        # function $(datenum)(y, m, d, h = 0, mi = 0, s = 0, ms = 0)
        #     return datenumfrac($(Symbol(:MJDFromDate_,calendar))(y,m,d),h,mi,s,ms)
        # end

        # function $(datetuple)(time::Number)
        #     days,h,mi,s,ms = timetuplefrac(time)
        #     y, m, d = $(Symbol(:DateFromMJD_,calendar))(days)
        #     return y, m, d, h, mi, s, ms
        # end

        struct $CFDateTime <: AbstractCFDateTime
            instant::UTInstant{Millisecond}
            $CFDateTime(instant::UTInstant{Millisecond}) = new(instant)
        end

        function $CFDateTime(y::Int64, m::Int64=1, d::Int64=1,
                             h::Int64=0, mi::Int64=0, s::Int64=0, ms::Int64=0)

            days = $(Symbol(:MJDFromDate_,calendar))(y,m,d)
            totalms = datenumfrac(days,h,mi,s,ms)
            return $CFDateTime(UTInstant(Millisecond(totalms)))
        end

        function datetuple(dt::$CFDateTime)
            time = Dates.value(dt.instant.periods)
            days,h,mi,s,ms = timetuplefrac(time)
            y, m, d = $(Symbol(:DateFromMJD_,calendar))(days)
            return y, m, d, h, mi, s, ms
        end

        function string(dt::$CFDateTime)
            y,mo,d,h,mi,s,ms = datetuple(dt)
            return @sprintf("%04d-%02d-%02dT%02d:%02d:%02d",y,mo,d,h,mi,s)
        end

        function show(io::IO,dt::$CFDateTime)
            write(io, string(typeof(dt)), "(",string(dt),")")
        end



        function +(dt::$CFDateTime,Δ::Dates.Year)
            y,mo,d,h,mi,s,ms = datetuple(dt)
            return $CFDateTime(y+Dates.value(Δ), mo, d, h, mi, s, ms)
        end

        function +(dt::$CFDateTime,Δ::Dates.Month)
            y,mo,d,h,mi,s,ms = datetuple(dt)
            mo = mo + Dates.value(Δ)
            mo2 = mod(mo - 1, 12) + 1
            y = y + (mo-mo2) ÷ 12
            return $CFDateTime(y, mo2, d,h, mi, s, ms)
        end

        +(dt::$CFDateTime,Δ::RegTime) = $CFDateTime(UTInstant(dt.instant.periods + Dates.Millisecond(Δ)))
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


function parseDT(::Type{DT},str) where DT <: Union{DateTime,AbstractCFDateTime}
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

    y,m,d,h,mi,s,ms =
        if contains(str," ")
            datestr,timestr = split(str,' ')
            y,m,d = parse.(Int,split(datestr,'-'))
            h,mi,s = parse.(Int,split(timestr,':'))
            (y,m,d,h,mi,s,0)
        else
            y,m,d = parse.(Int,split(str,'-'))
            (y,m,d,0,0,0,0)
        end

    if negativeyear
        y = -y
    end

    return DT(y,m,d,h,mi,s,ms)
end


"""
    t0,plength = timeunits(units,calendar = "standard")

Parse time units and returns the start time `t0` and the scaling factor
`plength` in milliseconds.
"""
function timeunits(::Type{DT},units) where DT
    tunit_mixedcase,starttime = strip.(split(units," since "))
    tunit = lowercase(tunit_mixedcase)

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
        else
            error("unknown units $(tunit)")
        end

    return t0,plength
end


function timetype(calendar = "standard")
    DT =
        if (calendar == "standard") || (calendar == "gregorian")
            DateTime
        elseif calendar == "proleptic_gregorian"
            DateTimePGregorian
        elseif calendar == "julian"
            DateTimeJulian
        elseif (calendar == "noleap") || (calendar == "365_day")
            DateTimeNoLeap
        elseif (calendar == "all_leap") || (calendar == "366_day")
            DateTimeAllLeap
        elseif calendar == "360_day"
            DateTime360
        else
            error("Unsupported calendar: $(calendar)")
        end

    return DT
end

"""
    t0,plength = timeunits(units,calendar = "standard")

Parse time units and returns the start time `t0` and the scaling factor
`plength` in milliseconds.
"""
function timeunits(units, calendar = "standard")
    DT = timetype(calendar)
    return timeunits(DT,units)
end

function timedecode(::Type{DT},data,units) where DT
    const t0,plength = timeunits(DT,units)
    convert(x) = t0 + Dates.Millisecond(round(Int64,plength * x))
    return convert.(data)
end


timedecode(data,units,calendar = "standard") =
    timedecode(timetype(calendar),data,units)


function timeencode(data::Array{DT,N},units,calendar = "standard") where N where DT <: Union{DateTime,AbstractCFDateTime}
    @assert timetype(calendar) == DT

    const t0,plength = timeunits(DT,units)
    convert(dt) = Dates.value(dt - t0) / plength
    return convert.(data)
end

# do not transform data is not a vector of DateTime
timeencode(data,units,calendar = "standard") = data





# reference value from Meeus, Jean (1998)
# launch of Sputnik 1

@test DateFromMJD_Standard(2_436_116 - 2_400_001) == (1957, 10, 4)
@test MJDFromDate(1957,10,4,true) == 36115

@test MJDFromDate(333,1,27,false) == -557288

# function testcal(tonum,totuple)
#     num = 1234567890123

#     @test tonum(totuple(num)...) == num
# end

# for (tonum,totuple) in [
#     (datenum_Standard,datetuple_Standard)
#     (datenum_Julian,datetuple_Julian)
#     (datenum_PGregorian,datetuple_PGregorian)
#     (datenum_AllLeap,datetuple_AllLeap)
#     (datenum_NoLeap,datetuple_NoLeap)
#     (datenum_360,datetuple_360)
# ]
#     testcal(tonum,totuple)
# end

@show DateFromMJD_PGregorian(-532783)
@show DateFromMJD_PGregorian(-532784)
@show DateFromMJD_PGregorian(-532785)
@show DateFromMJD_PGregorian(-532786)

@show MJDFromDate(-100, 2, 28,true)
@show MJDFromDate(-100, 3, 1,true)

function mytest()
    for (tonum,totuple) in [
        (MJDFromDate_Standard,DateFromMJD_Standard),
        (MJDFromDate_Julian,DateFromMJD_Julian),
        (MJDFromDate_PGregorian,DateFromMJD_PGregorian),
        (MJDFromDate_AllLeap,DateFromMJD_AllLeap),
        (MJDFromDate_NoLeap,DateFromMJD_NoLeap),
        (MJDFromDate_360,DateFromMJD_360),
    ]
        @time for Z = -2_400_000 + MJD_OFFSET : 11 : 600_000 + MJD_OFFSET
            y,m,d = totuple(Z)
            @test tonum(y,m,d) == Z
        end
    end
end


mytest()

#=
@time for Z = -2_400_000 + MJD_OFFSET : 600_000 + MJD_OFFSET
    y,m,d = DateFromMJD_Standard(Z)
    @test MJDFromDate_Standard(y,m,d) == Z

    y,m,d = DateFromMJD_Julian(Z)
    @test MJDFromDate_Julian(y,m,d) == Z

    y,m,d = DateFromMJD_PGregorian(Z)
    @test MJDFromDate_PGregorian(y,m,d) == Z

    #@test MJDFromDate_trunc(y,m,d,Z >= 2299161 - 2_400_001) == MJDFromDate(y,m,d,Z >= 2299161 - 2_400_001)
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
@test DateTimeNoLeap(2001,2,28) + Dates.Day(1) == DateTimeNoLeap(2001,3,1)
@test DateTimeJulian(2001,2,28) + Dates.Day(1) == DateTimeJulian(2001,3,1)
@test DateTimeJulian(1900,2,28) + Dates.Day(1) == DateTimeJulian(1900,2,29)
@test DateTime360(2001,2,28) + Dates.Day(1) == DateTime360(2001,2,29)
@test DateTime360(2001,2,29) + Dates.Day(1) == DateTime360(2001,2,30)
