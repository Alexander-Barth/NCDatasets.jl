#module Time
import Base.Dates: UTInstant, Millisecond
import Base.Dates: year,  month,  day, hour, minute, second, millisecond
import Base: +, -, isless, string, show, convert

# Introduction of the Gregorian Calendar 1582-10-15
const GREGORIAN_CALENDAR = (1582,10,15)

# Time offset in days for the time origin
# if DATENUM_OFFSET = 0, then datenum_gregjulian
# corresponds to  Modified Julian Days (MJD).
# MJD is the number of days since midnight on 1858-11-17)

#const DATENUM_OFFSET = 2_400_000.5 # for Julian Days
const DATENUM_OFFSET = 0 # for Modified Julian Days

# Introduction of the Gregorian Calendar 1582-10-15
# expressed in MJD (if DATENUM_OFFSET = 0)

const DN_GREGORIAN_CALENDAR = -100840 + DATENUM_OFFSET

# DateTime(UTInstant{Millisecond}(Dates.Millisecond(0)))
# returns 0000-12-31T00:00:00
# 678576 is the output of datenum_prolepticgregorian(-1,12,31)

const DATETIME_OFFSET = Dates.Millisecond(678576 * (24*60*60*1000))


"""
    dn = datenum_gregjulian(year,month,day,gregorian::Bool)

Days since 1858-11-17 according to the Gregorian (`gregorian` is `true`) or
Julian Calendar (`gregorian` is `false`) based on the Algorithm of
Jean Meeus [1].

The year -1, correspond to 1 BC. The year 0 does not exist in the
Gregorian or Julian Calendar.

[1] Meeus, Jean (1998) Astronomical Algorithms (2nd Edition).
Willmann-Bell,  Virginia. p. 63
"""
function datenum_gregjulian(year,month,day,gregorian::Bool)
    # turn year equal to -1 (1 BC) into year = 0
    if year < 0
        year = year+1
    end

    if gregorian
        # bring year in range of 1601 to 2000
        ncycles = (2000 - year) ÷ 400
        year = year + 400 * ncycles
        return datenum_optim(year,month,day,gregorian) - ncycles*146_097
    else
        return datenum_optim(year,month,day,gregorian)
    end

end


# the algorithm does not work for -100:03:01 and before in
# the proleptic Gregorian Calendar

function datenum_(year,month,day,gregorian::Bool)

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

    Z = trunc(Int,365.25 * (year + 4716)) + trunc(Int,30.6001 * (month+1)) + day + B - 2401525
    return Z + DATENUM_OFFSET
end

# Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,  Virginia. p. 63

function datenum_optim(year,month,day,gregorian::Bool)

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

    # why 153/5 (or 30.6001 ?)
    # month+1 varies between 4 (March), 5 (April), .. 14 (December),
    # 15 (January), 16 (February)

    # cm = 153 * (4:16) ÷ 5; cm[2:end]-cm[1:end-1]
    #
    # length of each month
    # --------------------
    # 31  March
    # 30  April
    # 31  May
    # 30  June
    # 31  July
    # 31  August
    # 30  September
    # 31  October
    # 30  November
    # 31  December
    # 31  January
    # 30  February (wrong, but not used, since it is the last month)

    Z = (1461 * (year + 4716)) ÷ 4 + (153 * (month+1)) ÷ 5 + day + B - 2401525
    # Modified Julan Day
    return Z + DATENUM_OFFSET
end



"""
    year, month, day = datetuple_gregjulian(Z::Integer,gregorian::Bool)

Compute year, month and day from Z which is the Modified Julian Day
for the Gregorian (true) or Julian (false) calendar.

For example:
Z = 0 for the 1858 November 17 00:00:00

Algorithm:

Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,
Virginia. p. 63
"""
function datetuple_gregjulian(Z,gregorian::Bool)
    # Z is Julian Day plus 0.5
    Z = Z + 2_400_001 - DATENUM_OFFSET

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
    days,h,mi,s,ms = timetuplefrac(time::Number)

Return the number of whole days, hours (`h`), minutes (`mi`), seconds (`s`) and
millisecods (`ms`) from `time` expressed in milliseconds.
"""

function timetuplefrac(time::Number)
    # time can be negative, use fld instead of ÷
    days = fld(time, (24*60*60*1000))
    ms = time - days * (24*60*60*1000)

    h = ms ÷ (60*60*1000)
    ms = ms - h * (60*60*1000)

    mi = ms ÷ (60*1000)
    ms = ms - mi * (60*1000)

    s = ms ÷ 1000
    ms = ms - s * 1000
    return (days,h,mi,s,ms)
end

function datenumfrac(days,h,mi,s,ms)
    ms = 60*60*1000 * h +  60*1000 * mi + 1000*s + ms
    return (24*60*60*1000) * days + ms
end


datetuple_prolepticgregorian(Z) = datetuple_gregjulian(Z,true)
datetuple_julian(Z) = datetuple_gregjulian(Z,false)
datetuple_standard(Z) = datetuple_gregjulian(Z,Z >= DN_GREGORIAN_CALENDAR)


datenum_prolepticgregorian(y,m,d) = datenum_gregjulian(y,m,d,true)
datenum_julian(y,m,d) = datenum_gregjulian(y,m,d,false)
datenum_standard(y,m,d) = datenum_gregjulian(y,m,d,(y,m,d) >= GREGORIAN_CALENDAR)


function datenum_cal(cm, y, m, d)
    # turn year equal to -1 (1 BC) into year = 0
    if y < 0
        y = y+1
    end

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

    if y <= 0
        y = y-1
    end

    return (y,mo,d)
end


for (calendar,cmm) in [
    ("allleap", (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366)),
    ("noleap",  (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)),
    ("360day",    (0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360)),
]
    @eval begin
        $(Symbol(:datenum_,calendar))(y, m, d) = datenum_cal($cmm, y, m, d)
        $(Symbol(:datetuple_,calendar))(days) = datetuple_cal($cmm,days)
    end
end


abstract type AbstractCFDateTime <: Dates.TimeType
end

const RegTime = Union{Dates.Millisecond,Dates.Second,Dates.Minute,Dates.Hour,Dates.Day}


for (Calendar,calendar) in [("Standard","standard"),
                            ("Julian","julian"),
                            ("ProlepticGregorian","prolepticgregorian"),
                            ("AllLeap","allleap"),
                            ("NoLeap","noleap"),
                            ("360Day","360day")]
    CFDateTime = Symbol(:DateTime,Calendar)
    @eval begin
        struct $CFDateTime <: AbstractCFDateTime
            instant::UTInstant{Millisecond}
             #$CFDateTime(instant::UTInstant{Millisecond}) = new(instant)
        end

        function $CFDateTime(y::Int64, m::Int64=1, d::Int64=1,
                             h::Int64=0, mi::Int64=0, s::Int64=0, ms::Int64=0)

            days = $(Symbol(:datenum_,calendar))(y,m,d)
            totalms = datenumfrac(days,h,mi,s,ms)
            return $CFDateTime(UTInstant(Millisecond(totalms)))
        end

        function datetuple(dt::$CFDateTime)
            time = Dates.value(dt.instant.periods)
            days,h,mi,s,ms = timetuplefrac(time)
            y, m, d = $(Symbol(:datetuple_,calendar))(days)
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

        -(dt1::$CFDateTime,dt2::$CFDateTime) = dt1.instant.periods - dt2.instant.periods

        isless(dt1::$CFDateTime,dt2::$CFDateTime) = dt1.instant.periods < dt2.instant.periods

    end
end


function reinterpret(::Type{T1}, dt::T2) where T1 <: Union{AbstractCFDateTime,DateTime} where T2 <: Union{AbstractCFDateTime,DateTime}
   return T1(
       Dates.year(dt),Dates.month(dt),Dates.day(dt),
       Dates.hour(dt),Dates.minute(dt),Dates.second(dt),
       Dates.millisecond(dt))
end

"""
    dt2 = convert(::Type{T}, dt)

Convert a DateTime of type `DateTimeStandard`, `DateTimeProlepticGregorian`,
`DateTimeJulian` or `DateTime` into the type `T` which can be
`DateTimeStandard`, `DateTimeProlepticGregorian`, `DateTimeJulian` or `DateTime`.

Converstion is done such that durations (difference of DateTime types) are
preserved. For dates on and after 1582-10-15, the year, month and days are the same for
the types `DateTimeStandard`, `DateTimeProlepticGregorian` and `DateTime`.

For dates before 1582-10-15, the year, month and days are the same for
the types `DateTimeStandard` and `DateTimeJulian`.
"""
function convert(::Type{T1}, dt::T2) where T1 <: Union{DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian} where T2 <: Union{DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian}
    return T1(dt.instant)
end

function convert(::Type{DateTime}, dt::T2) where T2 <: Union{DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian}
    DateTime(UTInstant{Millisecond}(dt.instant.periods + DATETIME_OFFSET))
end

function convert(::Type{T1}, dt::DateTime) where T1 <: Union{DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian}
    T1(UTInstant{Millisecond}(dt.instant.periods - DATETIME_OFFSET))
end




Dates.year(dt::AbstractCFDateTime) = datetuple(dt)[1]
Dates.month(dt::AbstractCFDateTime) = datetuple(dt)[2]
Dates.day(dt::AbstractCFDateTime) = datetuple(dt)[3]
Dates.hour(dt::AbstractCFDateTime)   = datetuple(dt)[4]
Dates.minute(dt::AbstractCFDateTime) = datetuple(dt)[5]
Dates.second(dt::AbstractCFDateTime) = datetuple(dt)[6]
Dates.millisecond(dt::AbstractCFDateTime) = datetuple(dt)[7]




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
            DateTimeStandard
        elseif calendar == "proleptic_gregorian"
            DateTimeProlepticGregorian
        elseif calendar == "julian"
            DateTimeJulian
        elseif (calendar == "noleap") || (calendar == "365_day")
            DateTimeNoLeap
        elseif (calendar == "all_leap") || (calendar == "366_day")
            DateTimeAllLeap
        elseif calendar == "360_day"
            DateTime360Day
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


"""
    dt = timedecode(data,units,calendar = "standard", prefer_datetime = true)

Decode the time information in data as given by the units `units` according to
the specified calendar. If prefer_datetime is true (default), dates are
converted to the Julia DateTime type (for the calendars
"standard", "gregorian", "proleptic_gregorian" and "julian"). Such convertion is
not possible for other calendars.
"""
function timedecode(data,units,calendar = "standard"; prefer_datetime = true)
    DT = timetype(calendar)
    dt = timedecode(DT,data,units)

    if prefer_datetime &&
        (DT in [DateTimeStandard,DateTimeProlepticGregorian,DateTimeJulian])

        return convert.(DateTime,dt)
    else
        return dt
    end
end


function timeencode(data::Array{DT,N},units,calendar = "standard") where N where DT <: Union{DateTime,AbstractCFDateTime}
    DT2 = timetype(calendar)
    #@assert timetype(calendar) == DT
    try
        data = convert.(DT2,data)
    catch
        error("It is not possible to convert between $(DT) and $(DT2)")
    end

    t0,plength = timeunits(DT2,units)
    #@show data,typeof(t0)

    encode(dt) = Dates.value(dt - t0) / plength
    return encode.(data)
end

# do not transform data is not a vector of DateTime
timeencode(data,units,calendar = "standard") = data

export timeencode, timedecode, datetuple

export DateTimeStandard, DateTimeJulian, DateTimeProlepticGregorian,
    DateTimeAllLeap, DateTimeNoLeap, DateTime360Day
