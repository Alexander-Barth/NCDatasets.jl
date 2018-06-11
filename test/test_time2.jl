using Base.Test

function JDFromDate_floor(year,month,day,gregorian::Bool)
    # turn year equal to -1 (1 BC) into year = 0
    if year < 0
        year = year+1
    end

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

    # Julian Day plus 0.5
    Z = floor(Int,365.25 * (year + 4716)) + floor(Int,30.6001 * (month+1)) + day + B - 1524

    return Z
end


function JDFromDate_mixed(year,month,day,gregorian::Bool)
    # turn year equal to -1 (1 BC) into year = 0
    if year < 0
        year = year+1
    end


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
    # floor(Int,365.25 * (year + 4716))
    # by
    # (1461 * (year + 4716)) ÷ 4
    #
    # and other floating point divisions

    # Z is the Julian Day plus 0.5
    # 1461/4 is 365.25
    # 153/5 is 30.6

    Z = (1461 * (year + 4716)) ÷ 4 + (153 * (month+1)) ÷ 5 + day + B - 1524

    return Z
end

# Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,  Virginia. p. 63


JD = 2400_000.5
# 1858 November 17 00:00:00

JD = 2436_116.31
# 1957 October 4

"""
    year, month, day = DateFromJD_floor(Z::Integer,gregorian::Bool)

Compyte year, month and day from Z which is the Julian Day plus 0.5,
for the gregorian (true) or julian (false) calendar.

For example:
Z = 2400_001 for the 1858 November 17 00:00:00

Algorithm:

Meeus, Jean (1998) Astronomical Algorithms (2nd Edition). Willmann-Bell,
Virginia. p. 63
"""
function DateFromJD_floor(Z::Integer,gregorian::Bool)

    A =
        if gregorian
            # lets magic happen
            α = floor(Int, (Z - 1867216.25)/36524.25 )
            Z + 1 + α - (α ÷ 4)
        else
            Z
        end

    # even more magic...
    B = A + 1524
    C = floor(Int, (B - 122.1) / 365.25)
    D = floor(Int, 365.25 * C)
    E = floor(Int, (B-D)/30.6001)

    day = B - D - floor(Int,30.6001 * E)
    month = (E < 14 ? E-1 : E-13)
    year = (month > 2 ? C - 4716 : C - 4715)

    # turn year 0 into year -1 (1 BC)
    if year <= 0
        year = year-1
    end
    return year,month,day
end




DateFromJD_gregorian(Z::Integer) = DateFromJD(Z,true)
DateFromJD_julian(Z::Integer) = DateFromJD(Z,false)
DateFromJD_mixed(Z::Integer) = DateFromJD(Z,Z >= 2299161)


# reference value from Meeus, Jean (1998)
# launch of Sputnik 1

@test DateFromJD_mixed(2_436_116) == (1957, 10, 4)


@test JDFromDate(1957,10,4,true) == 2_436_116

@test JDFromDate(333,1,27,false) == 1842713

for Z = 1:3_000_000

    year,month,day = DateFromJD_mixed(Z)
    @test JDFromDate_mixed(year,month,day,Z >= 2299161) == Z
    #@test JDFromDate_floor(year,month,day,Z >= 2299161) == JDFromDate_mixed(year,month,day,Z >= 2299161)
end
