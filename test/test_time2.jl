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
for the gregorian (true) or julian (false) calendar.

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
    year = (month > 2 ? C - 4716 : C - 4715)

    # turn year 0 into year -1 (1 BC)
    if year <= 0
        year = year-1
    end
    return year,month,day
end




DateFromMJD_gregorian(Z) = DateFromMJD(Z,true)
DateFromMJD_julian(Z) = DateFromMJD(Z,false)
DateFromMJD_mixed(Z) = DateFromMJD(Z,Z >= MJD_GREGORIAN_CALENDAR)


MJDFromDate_gregorian(year,month,day) = MJDFromDate(year,month,day,true)
MJDFromDate_julian(year,month,day) = MJDFromDate(year,month,day,false)
MJDFromDate_mixed(year,month,day) = MJDFromDate(year,month,day,(year,month,day) >= GREGORIAN_CALENDAR)

# reference value from Meeus, Jean (1998)
# launch of Sputnik 1

@test DateFromMJD_mixed(2_436_116 - 2_400_001) == (1957, 10, 4)
@test MJDFromDate(1957,10,4,true) == 36115

@test MJDFromDate(333,1,27,false) == -557288

@show DateFromMJD_gregorian(-532783)
@show DateFromMJD_gregorian(-532784)
@show DateFromMJD_gregorian(-532785)
@show DateFromMJD_gregorian(-532786)

@show MJDFromDate(-100, 2, 28,true)
@show MJDFromDate(-100, 3, 1,true)


#for Z = 1:3_000_000
#for Z = 2_000_000:3_000_000

for Z = -2_400_000 + MJD_OFFSET : 600_000 + MJD_OFFSET
    year,month,day = DateFromMJD_mixed(Z)
    @test MJDFromDate_mixed(year,month,day) == Z

    year,month,day = DateFromMJD_julian(Z)
    @test MJDFromDate_julian(year,month,day) == Z

    year,month,day = DateFromMJD_gregorian(Z)
    @test MJDFromDate_gregorian(year,month,day) == Z

    #@test MJDFromDate_trunc(year,month,day,Z >= 2299161 - 2_400_001) == MJDFromDate(year,month,day,Z >= 2299161 - 2_400_001)
end
