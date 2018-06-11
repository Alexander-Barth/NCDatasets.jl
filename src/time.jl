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

    dd =
        if y > 0
            # number of leap years prior to current year
            nleap = (y-1) ÷ 4

            # after Feb., count current leap day
            if isleapyear_julian(y) && (m > 2)
                nleap += 1
            end

            cm[end] * (y-1) + cm[m] + (d-1) + nleap
        else
            # 1 BC, 5 BC, 9 BC,...
            nleap = (y-3) ÷ 4

            # after Feb., count current leap day
            if isleapyear_julian(y) && (m > 2)
                nleap += 1
            end

            cm[end] * y + cm[m] + (d-1) + nleap
        end

    return (24*60*60*1000) * (dd) + ms
end

"""
time is in milliseconds
"""
function datetuple_julian(time::Number)
    days = time ÷ (24*60*60*1000)
    y = 0

    if days >= 0
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
        y = 4 * (days ÷ (3*365+366))
        y = y-4
        #@show y,days
        d2 = days - (y ÷ 4) * (3*365+366)
        if d2 == 4*365
            # the 4th year is not yet over
            y += 3
        else
            y += (d2 ÷ 365)
        end
        y = y-1
        #@show y

        days = days - (365*(y+1) + (y-2)÷4)
        #@show days

    end
    cm =
        if isleapyear_julian(y+1)
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
        elseif calendar == "julian"
            DateTimeJulian
        elseif (calendar == "noleap") || (calendar == "365_day")
            DateTimeNoLeap
        elseif (calendar == "all_leap") || (calendar == "366_day")
            DateTimeAllLeap
        elseif calendar == "360_day"
            DateTimeAllLeap
        else
            error("Unsupported calendar: $(calendar). NCDatasets supports only the standard (gregorian) calendar or Chronological Julian Date")
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


