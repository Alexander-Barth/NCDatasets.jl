var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.jl",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#NCDatasets.jl-1",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.jl",
    "category": "section",
    "text": "Documentation for NCDatasets.jl"
},

{
    "location": "index.html#NCDatasets.Dataset",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.Dataset",
    "category": "type",
    "text": "Dataset(filename::AbstractString,mode::AbstractString = \"r\";\n                 format::Symbol = :netcdf4)\n\nCreate a new NetCDF file if the mode is \"c\". An existing file with the same name will be overwritten. If mode is \"a\", then an existing file is open into append mode (i.e. existing data in the netCDF file is not overwritten and a variable can be added). With the mode set to \"r\", an existing netCDF file or OPeNDAP URL can be open in read-only mode.  The default mode is \"r\".\n\nSupported formats:\n\n:netcdf4 (default): HDF5-based NetCDF format.\n:netcdf4_classic: Only netCDF 3 compatible API features will be used.\n:netcdf3_classic: classic netCDF format supporting only files smaller than 2GB.\n:netcdf3_64bit_offset: improved netCDF format supporting files larger than 2GB.\n\nFiles can also be open and automatically closed with a do block.\n\nDataset(\"file.nc\") do ds\n    data = ds[\"temperature\"][:,:]\nend\n\n\n\n"
},

{
    "location": "index.html#Base.keys-Tuple{NCDatasets.Dataset}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "keys(ds::Dataset)\n\nReturn a list of all variables names in Dataset ds.\n\n\n\n"
},

{
    "location": "index.html#Base.haskey",
    "page": "NCDatasets.jl",
    "title": "Base.haskey",
    "category": "function",
    "text": "haskey(ds::Dataset,varname)\n\nReturn true of the Dataset ds has a variable with the name varname. For example:\n\nds = Dataset(\"/tmp/test.nc\",\"r\")\nif haskey(ds,\"temperature\")\n    println(\"The file has a variable \'temperature\'\")\nend\n\nThis example checks if the file /tmp/test.nc has a variable with the name temperature.\n\n\n\n"
},

{
    "location": "index.html#Base.getindex-Tuple{NCDatasets.Dataset,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "getindex(ds::Dataset,varname::AbstractString)\n\nReturn the NetCDF variable varname in the dataset ds as a NCDataset.CFVariable. The CF convention are honored when the variable is indexed:\n\n_FillValue will be returned as missing\nscale_factor and add_offset are applied\ntime variables (recognized by the units attribute) are returned\n\nas DateTime object.\n\nA call getindex(ds,varname) is usually written as ds[varname].\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.variable",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.variable",
    "category": "function",
    "text": "variable(ds::Dataset,varname::String)\n\nReturn the NetCDF variable varname in the dataset ds as a NCDataset.Variable. No scaling is applied when this variable is indexes.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.sync",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.sync",
    "category": "function",
    "text": "sync(ds::Dataset)\n\nWrite all changes in Dataset ds to the disk.\n\n\n\n"
},

{
    "location": "index.html#Base.close",
    "page": "NCDatasets.jl",
    "title": "Base.close",
    "category": "function",
    "text": "close(ds::Dataset)\n\nClose the Dataset ds. All pending changes will be written to the disk.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.path",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.path",
    "category": "function",
    "text": "path(ds::Dataset)\n\nReturn the file path (or the opendap URL) of the Dataset ds\n\n\n\n"
},

{
    "location": "index.html#Datasets-1",
    "page": "NCDatasets.jl",
    "title": "Datasets",
    "category": "section",
    "text": "Dataset\nkeys(ds::Dataset)\nhaskey\ngetindex(ds::Dataset,varname::AbstractString)\nvariable\nsync\nclose\npath"
},

{
    "location": "index.html#NCDatasets.defVar",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defVar",
    "category": "function",
    "text": "defVar(ds::Dataset,name,vtype,dimnames; kwargs...)\n\nDefine a variable with the name name in the dataset ds.  vtype can be Julia types in the table below (with the corresponding NetCDF type).  The parameter dimnames is a tuple with the names of the dimension.  For scalar this parameter is the empty tuple (). The variable is returned (of the type CFVariable).\n\nKeyword arguments\n\nfillvalue: A value filled in the NetCDF file to indicate missing data.  It will be stored in the _FillValue attribute.\nchunksizes: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.\ndeflatelevel: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.\nshuffle: If true, the shuffle filter is activated which can improve the compression ratio.\nchecksum: The checksum method can be :fletcher32 or :nochecksum (checksumming is disabled, which is the default)\ntypename (string): The name of the NetCDF type required for vlen arrays [1]\n\nchunksizes, deflatelevel, shuffle and checksum can only be set on NetCDF 4 files.\n\nNetCDF data types\n\nNetCDF Type Julia Type\nNC_BYTE Int8\nNC_UBYTE UInt8\nNC_SHORT Int16\nNC_INT Int32\nNC_INT64 Int64\nNC_FLOAT Float32\nNC_DOUBLE Float64\nNC_CHAR Char\nNC_STRING String\n\n[1] https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc_005fdef_005fvlen.html\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.dimnames",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.dimnames",
    "category": "function",
    "text": "dimnames(v::Variable)\n\nReturn a tuple of the dimension names of the variable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.name",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.name",
    "category": "function",
    "text": "name(v::Variable)\n\nReturn the name of the NetCDF variable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.chunking",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.chunking",
    "category": "function",
    "text": "storage,chunksizes = chunking(v::Variable)\n\nReturn the storage type (:contiguous or :chunked) and the chunk sizes of the varable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.deflate",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.deflate",
    "category": "function",
    "text": "isshuffled,isdeflated,deflate_level = deflate(v::Variable)\n\nReturn compression information of the variable v. If shuffle is true, then shuffling (byte interlacing) is activaded. If deflate is true, then the data chunks (see chunking) are compressed using the compression level deflate_level (0 means no compression and 9 means maximum compression).\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.checksum",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.checksum",
    "category": "function",
    "text": "checksummethod = checksum(v::Variable)\n\nReturn the checksum method of the variable v which can be either be :fletcher32 or :nochecksum.\n\n\n\n"
},

{
    "location": "index.html#Variables-1",
    "page": "NCDatasets.jl",
    "title": "Variables",
    "category": "section",
    "text": "defVar\ndimnames\nname\nchunking\ndeflate\nchecksumDifferent type of arrays are involved when working with NCDatasets. For instance assume that test.nc is a file with a Float32 variable called var. Assume that we open this data set in append mode (\"a\"):using NCDatasets\nds = Dataset(\"test.nc\",\"a\")\nv_cf = ds[\"var\"]The variable v_cf has the type CFVariable. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, ... by the functions size, ndims, length as ordinary Julia arrays. Once you index, the variable v_cf, then the data is loaded and stored into a DataArray:v_da = v_cf[:,:]"
},

{
    "location": "index.html#Base.getindex-Tuple{NCDatasets.Attributes,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "getindex(a::Attributes,name::AbstractString)\n\nReturn the value of the attribute called name from the attribute list a. Generally the attributes are loaded by indexing, for example:\n\nds = Dataset(\"file.nc\")\ntitle = ds.attrib[\"title\"]\n\n\n\n"
},

{
    "location": "index.html#Base.setindex!-Tuple{NCDatasets.Attributes,Any,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(a::Attributes,data,name::AbstractString)\n\nSet the attribute called name to the value data in the attribute list a. Generally the attributes are defined by indexing, for example:\n\nds = Dataset(\"file.nc\",\"c\")\nds.attrib[\"title\"] = \"my title\"\n\n\n\n"
},

{
    "location": "index.html#Base.keys-Tuple{NCDatasets.Attributes}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "Base.keys(a::Attributes)\n\nReturn a list of the names of all attributes.\n\n\n\n"
},

{
    "location": "index.html#Attributes-1",
    "page": "NCDatasets.jl",
    "title": "Attributes",
    "category": "section",
    "text": "The NetCDF dataset (as return by Dataset or NetCDF groups) and the NetCDF variables (as returned by getindex, variable or defVar) have the field attrib which has the type NCDatasets.Attributes and behaves like a julia dictionary.getindex(a::NCDatasets.Attributes,name::AbstractString)\nsetindex!(a::NCDatasets.Attributes,data,name::AbstractString)\nkeys(a::NCDatasets.Attributes)"
},

{
    "location": "index.html#NCDatasets.defDim",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defDim",
    "category": "function",
    "text": "defDim(ds::Dataset,name,len)\n\nDefine a dimension in the data set ds with the given name and length len. If len is the special value Inf, then the dimension is considered as unlimited, i.e. it will grow as data is added to the NetCDF file.\n\nFor example:\n\nds = Dataset(\"/tmp/test.nc\",\"c\")\ndefDim(ds,\"lon\",100)\n\nThis defines the dimension lon with the size 100.\n\n\n\n"
},

{
    "location": "index.html#Base.setindex!-Tuple{NCDatasets.Dimensions,Any,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(d::Dimensions,len,name::AbstractString)\n\nDefines the dimension called name to the length len. Generally dimension are defined by indexing, for example:\n\nds = Dataset(\"file.nc\",\"c\")\nds.dim[\"longitude\"] = 100\n\nIf len is the special value Inf, then the dimension is considered as unlimited, i.e. it will grow as data is added to the NetCDF file.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.dimnames-Tuple{NCDatasets.Variable}",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.dimnames",
    "category": "method",
    "text": "dimnames(v::Variable)\n\nReturn a tuple of the dimension names of the variable v.\n\n\n\n"
},

{
    "location": "index.html#Dimensions-1",
    "page": "NCDatasets.jl",
    "title": "Dimensions",
    "category": "section",
    "text": "defDim\nsetindex!(d::NCDatasets.Dimensions,len,name::AbstractString)\ndimnames(v::NCDatasets.Variable)"
},

{
    "location": "index.html#NCDatasets.defGroup-Tuple{NCDatasets.Dataset,Any}",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defGroup",
    "category": "method",
    "text": "defGroup(ds::Dataset,groupname)\n\nCreate the group with the name groupname in the dataset ds.\n\n\n\n"
},

{
    "location": "index.html#Base.getindex-Tuple{NCDatasets.Groups,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "group = getindex(g::NCDatasets.Groups,groupname::AbstractString)\n\nReturn the NetCDF group with the name groupname. For example:\n\njulia> ds = Dataset(\"results.nc\", \"r\");\njulia> forecast_group = ds.group[\"forecast\"]\njulia> forecast_temp = forecast_group[\"temperature\"]\n\n\n\n"
},

{
    "location": "index.html#Base.keys-Tuple{NCDatasets.Groups}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "Base.keys(g::NCDatasets.Groups)\n\nReturn the names of all subgroubs of the group g.\n\n\n\n"
},

{
    "location": "index.html#Groups-1",
    "page": "NCDatasets.jl",
    "title": "Groups",
    "category": "section",
    "text": "defGroup(ds::Dataset,groupname)\ngetindex(g::NCDatasets.Groups,groupname::AbstractString)\nBase.keys(g::NCDatasets.Groups)"
},

{
    "location": "index.html#Common-methods-1",
    "page": "NCDatasets.jl",
    "title": "Common methods",
    "category": "section",
    "text": "One can iterate over a dataset, attribute list, dimensions and NetCDF groups.for (varname,var) in ds\n    # all variables\n    @show (varname,size(var))\nend\n\nfor (dimname,dim) in ds.dims\n    # all dimensions\n    @show (dimname,dim)\nend\n\nfor (attribname,attrib) in ds.attrib\n    # all attributes\n    @show (attribname,attrib)\nend\n\nfor (groupname,group) in ds.groups\n    # all groups\n    @show (groupname,group)\nend"
},

{
    "location": "index.html#NCDatasets.DateTimeStandard",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTimeStandard",
    "category": "type",
    "text": "NCDatasets.DateTimeStandard(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTimeStandard\n\nConstruct a NCDatasets.DateTimeStandard type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTimeStandard is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.DateTimeJulian",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTimeJulian",
    "category": "type",
    "text": "NCDatasets.DateTimeJulian(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTimeJulian\n\nConstruct a NCDatasets.DateTimeJulian type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTimeJulian is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.DateTimeProlepticGregorian",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTimeProlepticGregorian",
    "category": "type",
    "text": "NCDatasets.DateTimeProlepticGregorian(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTimeProlepticGregorian\n\nConstruct a NCDatasets.DateTimeProlepticGregorian type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTimeProlepticGregorian is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.DateTimeAllLeap",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTimeAllLeap",
    "category": "type",
    "text": "NCDatasets.DateTimeAllLeap(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTimeAllLeap\n\nConstruct a NCDatasets.DateTimeAllLeap type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTimeAllLeap is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.DateTimeNoLeap",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTimeNoLeap",
    "category": "type",
    "text": "NCDatasets.DateTimeNoLeap(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTimeNoLeap\n\nConstruct a NCDatasets.DateTimeNoLeap type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTimeNoLeap is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.DateTime360Day",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.DateTime360Day",
    "category": "type",
    "text": "NCDatasets.DateTime360Day(y, [m, d, h, mi, s, ms]) -> NCDatasets.DateTime360Day\n\nConstruct a NCDatasets.DateTime360Day type by year (y), month (m, default 1), day (d, default 1), hour (h, default 0), minute (mi, default 0), second (s, default 0), millisecond (ms, default 0). All arguments must be convertible to Int64. NCDatasets.DateTime360Day is a subtype of AbstractCFDateTime.\n\nThe netCDF CF calendars are defined at [1].\n\n[1] https://web.archive.org/web/20180622080424/http://cfconventions.org/cf-conventions/cf-conventions.html#calendar\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.year-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.year",
    "category": "method",
    "text": "Dates.year(dt::AbstractCFDateTime) -> Int64\n\nExtract the year-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.month-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.month",
    "category": "method",
    "text": "Dates.month(dt::AbstractCFDateTime) -> Int64\n\nExtract the month-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.day-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.day",
    "category": "method",
    "text": "Dates.day(dt::AbstractCFDateTime) -> Int64\n\nExtract the day-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.hour-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.hour",
    "category": "method",
    "text": "Dates.hour(dt::AbstractCFDateTime) -> Int64\n\nExtract the hour-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.minute-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.minute",
    "category": "method",
    "text": "Dates.minute(dt::AbstractCFDateTime) -> Int64\n\nExtract the minute-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.second-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.second",
    "category": "method",
    "text": "Dates.second(dt::AbstractCFDateTime) -> Int64\n\nExtract the second-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.millisecond-Tuple{NCDatasets.AbstractCFDateTime}",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.millisecond",
    "category": "method",
    "text": "Dates.millisecond(dt::AbstractCFDateTime) -> Int64\n\nExtract the millisecond-part of a AbstractCFDateTime as an Int64.\n\n\n\n"
},

{
    "location": "index.html#Base.convert",
    "page": "NCDatasets.jl",
    "title": "Base.convert",
    "category": "function",
    "text": "dt2 = convert(::Type{T}, dt)\n\nConvert a DateTime of type DateTimeStandard, DateTimeProlepticGregorian, DateTimeJulian or DateTime into the type T which can also be either DateTimeStandard, DateTimeProlepticGregorian, DateTimeJulian or DateTime.\n\nConverstion is done such that durations (difference of DateTime types) are preserved. For dates on and after 1582-10-15, the year, month and days are the same for the types DateTimeStandard, DateTimeProlepticGregorian and DateTime.\n\nFor dates before 1582-10-15, the year, month and days are the same for the types DateTimeStandard and DateTimeJulian.\n\n\n\n"
},

{
    "location": "index.html#Base.reinterpret",
    "page": "NCDatasets.jl",
    "title": "Base.reinterpret",
    "category": "function",
    "text": "dt2 = reinterpret(::Type{T}, dt)\n\nConvert a variable dt of type DateTime, DateTimeStandard, DateTimeJulian, DateTimeProlepticGregorian, DateTimeAllLeap, DateTimeNoLeap or DateTime360Day into the date time type T using the same values for year, month, day, minute, second and millisecond. The convertion might fail if a particular date does not exist in the target calendar.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.timedecode",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.timedecode",
    "category": "function",
    "text": "dt = timedecode(data,units,calendar = \"standard\", prefer_datetime = true)\n\nDecode the time information in data as given by the units units according to the specified calendar. Valid values for calendar are \"standard\", \"gregorian\", \"proleptic_gregorian\", \"julian\", \"noleap\", \"365_day\", \"all_leap\", \"366_day\" and \"360_day\".\n\nIf prefer_datetime is true (default), dates are converted to the DateTime type (for the calendars \"standard\", \"gregorian\", \"proleptic_gregorian\" and \"julian\"). Such convertion is not possible for the other calendars.\n\nCalendar Type (prefer_datetime=true) Type (prefer_datetime=false)\nstandard, gregorian DateTime DateTimeStandard\nproleptic_gregorian DateTime DateTimeProlepticGregorian\njulian DateTime DateTimeJulian\nnoleap, 365_day DateTimeNoLeap DateTimeNoLeap\nall_leap, 366_day DateTimeAllLeap DateTimeAllLeap\n360_day DateTime360Day DateTime360Day\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.timeencode",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.timeencode",
    "category": "function",
    "text": "data = timeencode(dt,units,calendar = \"standard\")\n\nConvert a vector or array of DateTime (or DateTimeStandard, DateTimeProlepticGregorian, DateTimeJulian, DateTimeNoLeap, DateTimeAllLeap, DateTime360Day) accoring to the specified units (e.g. \"days since 2000-01-01 00:00:00\") using the calendar calendar.  Valid values for calendar are: \"standard\", \"gregorian\", \"proleptic_gregorian\", \"julian\", \"noleap\", \"365_day\", \"all_leap\", \"366_day\", \"360_day\".\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.daysinmonth",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.daysinmonth",
    "category": "function",
    "text": "monthlength = daysinmonth(::Type{DT},y,m)\n\nReturns the number of days in a month for the year y and the month m according to the calenar given by the type DT.\n\nExample\n\njulia> daysinmonth(DateTimeAllLeap,2001,2)\n29\n\n\n\nmonthlength = daysinmonth(t)\n\nReturns the number of days in a month containing the date t\n\nExample\n\njulia> daysinmonth(DateTimeAllLeap(2001,2,1))\n29\n\n\n\n"
},

{
    "location": "index.html#Base.Dates.daysinyear",
    "page": "NCDatasets.jl",
    "title": "Base.Dates.daysinyear",
    "category": "function",
    "text": "yearlength = daysinyear(::Type{DT},y)\n\nReturns the number of days in a year for the year y according to the calenar given by the type DT.\n\nExample\n\njulia> daysinyear(DateTimeAllLeap,2001,2)\n366\n\n\n\nyearlength = daysinyear(t)\n\nReturns the number of days in a year containing the date t\n\nExample\n\njulia> daysinyear(DateTimeAllLeap(2001,2,1))\n366\n\n\n\n"
},

{
    "location": "index.html#Time-functions-1",
    "page": "NCDatasets.jl",
    "title": "Time functions",
    "category": "section",
    "text": "DateTimeStandard\nDateTimeJulian\nDateTimeProlepticGregorian\nDateTimeAllLeap\nDateTimeNoLeap\nDateTime360Day\nDates.year(dt::AbstractCFDateTime)\nDates.month(dt::AbstractCFDateTime)\nDates.day(dt::AbstractCFDateTime)\nDates.hour(dt::AbstractCFDateTime)\nDates.minute(dt::AbstractCFDateTime)\nDates.second(dt::AbstractCFDateTime)\nDates.millisecond(dt::AbstractCFDateTime)\nconvert\nreinterpret\ntimedecode\ntimeencode\ndaysinmonth\ndaysinyear"
},

{
    "location": "index.html#NCDatasets.ncgen",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.ncgen",
    "category": "function",
    "text": "ncgen(fname; ...)\nncgen(fname,jlname; ...)\n\nGenerate the Julia code that would produce a NetCDF file with the same metadata as the NetCDF file fname. The code is placed in the file jlname or printed to the standard output. By default the new NetCDF file is called filename.nc. This can be changed with the optional parameter newfname.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.nomissing",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.nomissing",
    "category": "function",
    "text": "a = nomissing(da)\n\nRetun the values of the array da of type Array{Union{T,Missing},N} (potentially containing missing values) as a regular Julia array a of the same element type and checks that no missing values are present.\n\n\n\na = nomissing(da,value)\n\nRetun the values of the array da of type Array{Union{T,Missing},N} as a regular Julia array a by replacing all missing value by value.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.varbyattrib",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.varbyattrib",
    "category": "function",
    "text": "varbyattrib(ds, attname = attval)\n\nReturns a list of variable(s) which has the attribute attname matching the value attval in the dataset ds. The list is empty if the none of the variables has the match. The output is a list of CFVariables.\n\nExamples\n\nLoad all the data of the first variable with standard name \"longitude\" from the NetCDF file results.nc.\n\njulia> ds = Dataset(\"results.nc\", \"r\");\njulia> data = varbyattrib(ds, standard_name = \"longitude\")[1][:]\n\n\n\n"
},

{
    "location": "index.html#Utility-functions-1",
    "page": "NCDatasets.jl",
    "title": "Utility functions",
    "category": "section",
    "text": "ncgen\nnomissing\nvarbyattrib"
},

{
    "location": "index.html#Issues-1",
    "page": "NCDatasets.jl",
    "title": "Issues",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#libnetcdf-not-properly-installed-1",
    "page": "NCDatasets.jl",
    "title": "libnetcdf not properly installed",
    "category": "section",
    "text": "If you see the following error,ERROR: LoadError: LoadError: libnetcdf not properly installed. Please run Pkg.build(\"NCDatasets\")you can try to install netcdf explicitly with Conda:using Conda\nConda.add(\"libnetcdf\")"
},

{
    "location": "index.html#NetCDF:-Not-a-valid-data-type-or-_FillValue-type-mismatch-1",
    "page": "NCDatasets.jl",
    "title": "NetCDF: Not a valid data type or _FillValue type mismatch",
    "category": "section",
    "text": "Trying to define the _FillValue, procudes the following error:ERROR: LoadError: NCDatasets.NetCDFError(-45, \"NetCDF: Not a valid data type or _FillValue type mismatch\")The error could be generated by a code like this:using NCDatasets\n# ...\ntempvar = defVar(ds,\"temp\",Float32,(\"lonc\",\"latc\",\"time\"))\ntempvar.attrib[\"_FillValue\"] = -9999.In fact, _FillValue must have the same data type as the corresponding variable. In the case above, tempvar is a 32-bit float and the number -9999. is a 64-bit float (aka double, which is the default floating point type in Julia). It is sufficient to convert the value -9999. to a 32-bit float:tempvar.attrib[\"_FillValue\"] = Float32(-9999.)"
},

{
    "location": "index.html#Corner-cases-1",
    "page": "NCDatasets.jl",
    "title": "Corner cases",
    "category": "section",
    "text": "An attribute representing a vector with a single value (e.g. [1]) will be read back as a scalar (1) (same behavior in python netCDF4 1.3.1).\nNetCDF and Julia distinguishes between a vector of chars and a string, but both are returned as string for ease of use, in particularan attribute representing a vector of chars [\'u\',\'n\',\'i\',\'t\',\'s\'] will be read back as the string \"units\".An attribute representing a vector of chars [\'u\',\'n\',\'i\',\'t\',\'s\',\'\\0\'] will also be read back as the string \"units\" (issue #12).<!–  LocalWords:  NCDatasets jl Datasets Dataset netCDF  –>"
},

]}
