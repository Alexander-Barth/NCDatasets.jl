var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.jl",
    "category": "page",
    "text": ""
},

{
    "location": "#NCDatasets.jl-1",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.jl",
    "category": "section",
    "text": "Documentation for NCDatasets.jl"
},

{
    "location": "#NCDatasets.Dataset",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.Dataset",
    "category": "type",
    "text": "Dataset(filename::AbstractString,mode::AbstractString = \"r\";\n                 format::Symbol = :netcdf4, attrib = [])\n\nCreate a new NetCDF file if the mode is \"c\". An existing file with the same name will be overwritten. If mode is \"a\", then an existing file is open into append mode (i.e. existing data in the netCDF file is not overwritten and a variable can be added). With the mode set to \"r\", an existing netCDF file or OPeNDAP URL can be open in read-only mode.  The default mode is \"r\". The optional parameter attrib is an iterable of attribute name and attribute value pairs, for example a Dict, DataStructures.OrderedDict or simply a vector of pairs (see example below).\n\nSupported formats:\n\n:netcdf4 (default): HDF5-based NetCDF format.\n:netcdf4_classic: Only netCDF 3 compatible API features will be used.\n:netcdf3_classic: classic netCDF format supporting only files smaller than 2GB.\n:netcdf3_64bit_offset: improved netCDF format supporting files larger than 2GB.\n\nFiles can also be open and automatically closed with a do block.\n\nDataset(\"file.nc\") do ds\n    data = ds[\"temperature\"][:,:]\nend\n\nDataset(\"file.nc\", \"c\", attrib = [\"title\" => \"my first netCDF file\"]) do ds\n   defVar(ds,\"temp\",[10.,20.,30.],(\"time\",))\nend;\n\n\n\n\n\nmfds = Dataset(fnames,mode = \"r\"; aggdim = nothing)\n\nOpens a multi-file dataset in read-only \"r\" or append mode \"a\". fnames is a vector of file names. Variables are aggregated over the first unimited dimension or over the dimension aggdim if specified.\n\nNote: all files are opened at the same time. However the operating system might limit the number of open files. In Linux, the limit can be controled with the command ulimit [1,2].\n\nAll variables containing the dimension aggdim are aggerated. The variable who do not contain the dimension aggdim are assumed constant.\n\n[1]: https://stackoverflow.com/questions/34588/how-do-i-change-the-number-of-open-files-limit-in-linux [2]: https://unix.stackexchange.com/questions/8945/how-can-i-increase-open-files-limit-for-all-processes/8949#8949\n\n\n\n\n\n"
},

{
    "location": "#Base.keys-Tuple{Dataset}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "keys(ds::Dataset)\n\nReturn a list of all variables names in Dataset ds.\n\n\n\n\n\n"
},

{
    "location": "#Base.haskey",
    "page": "NCDatasets.jl",
    "title": "Base.haskey",
    "category": "function",
    "text": "haskey(ds::Dataset,varname)\n\nReturn true of the Dataset ds has a variable with the name varname. For example:\n\nds = Dataset(\"/tmp/test.nc\",\"r\")\nif haskey(ds,\"temperature\")\n    println(\"The file has a variable \'temperature\'\")\nend\n\nThis example checks if the file /tmp/test.nc has a variable with the name temperature.\n\n\n\n\n\n"
},

{
    "location": "#Base.getindex-Tuple{Dataset,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "getindex(ds::Dataset,varname::AbstractString)\n\nReturn the NetCDF variable varname in the dataset ds as a NCDataset.CFVariable. The CF convention are honored when the variable is indexed:\n\n_FillValue will be returned as missing\nscale_factor and add_offset are applied\ntime variables (recognized by the units attribute) are returned\n\nas DateTime object.\n\nA call getindex(ds,varname) is usually written as ds[varname].\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.variable",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.variable",
    "category": "function",
    "text": "variable(ds::Dataset,varname::String)\n\nReturn the NetCDF variable varname in the dataset ds as a NCDataset.Variable. No scaling is applied when this variable is indexes.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.sync",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.sync",
    "category": "function",
    "text": "sync(ds::Dataset)\n\nWrite all changes in Dataset ds to the disk.\n\n\n\n\n\n"
},

{
    "location": "#Base.close",
    "page": "NCDatasets.jl",
    "title": "Base.close",
    "category": "function",
    "text": "close(ds::Dataset)\n\nClose the Dataset ds. All pending changes will be written to the disk.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.path",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.path",
    "category": "function",
    "text": "path(ds::Dataset)\n\nReturn the file path (or the opendap URL) of the Dataset ds\n\n\n\n\n\n"
},

{
    "location": "#Datasets-1",
    "page": "NCDatasets.jl",
    "title": "Datasets",
    "category": "section",
    "text": "Dataset\nkeys(ds::Dataset)\nhaskey\ngetindex(ds::Dataset,varname::AbstractString)\nvariable\nsync\nclose\npath"
},

{
    "location": "#NCDatasets.defVar",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defVar",
    "category": "function",
    "text": "defVar(ds::Dataset,name,vtype,dimnames; kwargs...)\ndefVar(ds::Dataset,name,data,dimnames; kwargs...)\n\nDefine a variable with the name name in the dataset ds.  vtype can be Julia types in the table below (with the corresponding NetCDF type). Instead of providing the variable type one can directly give also the data data which will be used to fill the NetCDF variable. The parameter dimnames is a tuple with the names of the dimension.  For scalar this parameter is the empty tuple (). The variable is returned (of the type CFVariable).\n\nNote if data is a vector or array of DateTime objects, then the dates are saved as double-precision floats and units \"days since 1900-00-00 00:00:00\" (unless a time unit is specifed with the attrib keyword described below)\n\nKeyword arguments\n\nfillvalue: A value filled in the NetCDF file to indicate missing data.  It will be stored in the _FillValue attribute.\nchunksizes: Vector integers setting the chunk size. The total size of a chunk must be less than 4 GiB.\ndeflatelevel: Compression level: 0 (default) means no compression and 9 means maximum compression. Each chunk will be compressed individually.\nshuffle: If true, the shuffle filter is activated which can improve the compression ratio.\nchecksum: The checksum method can be :fletcher32 or :nochecksum (checksumming is disabled, which is the default)\nattrib: An iterable of attribute name and attribute value pairs, for example a Dict, DataStructures.OrderedDict or simply a vector of pairs (see example below)\ntypename (string): The name of the NetCDF type required for vlen arrays [1]\n\nchunksizes, deflatelevel, shuffle and checksum can only be set on NetCDF 4 files.\n\nNetCDF data types\n\nNetCDF Type Julia Type\nNC_BYTE Int8\nNC_UBYTE UInt8\nNC_SHORT Int16\nNC_INT Int32\nNC_INT64 Int64\nNC_FLOAT Float32\nNC_DOUBLE Float64\nNC_CHAR Char\nNC_STRING String\n\nExample:\n\njulia> data = randn(3,5)\njulia> Dataset(\"test_file.nc\",\"c\") do ds\n          defVar(ds,\"temp\",data,(\"lon\",\"lat\"), attrib = [\n             \"units\" => \"degree_Celsius\",\n             \"long_name\" => \"Temperature\"\n          ])\n       end;\n\n\n[1]: https://web.archive.org/save/https://www.unidata.ucar.edu/software/netcdf/netcdf-4/newdocs/netcdf-c/nc005fdef005fvlen.html\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.dimnames",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.dimnames",
    "category": "function",
    "text": "dimnames(v::Variable)\n\nReturn a tuple of the dimension names of the variable v.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.name",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.name",
    "category": "function",
    "text": "name(v::Variable)\n\nReturn the name of the NetCDF variable v.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.chunking",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.chunking",
    "category": "function",
    "text": "storage,chunksizes = chunking(v::Variable)\n\nReturn the storage type (:contiguous or :chunked) and the chunk sizes of the varable v.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.deflate",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.deflate",
    "category": "function",
    "text": "isshuffled,isdeflated,deflate_level = deflate(v::Variable)\n\nReturn compression information of the variable v. If shuffle is true, then shuffling (byte interlacing) is activaded. If deflate is true, then the data chunks (see chunking) are compressed using the compression level deflate_level (0 means no compression and 9 means maximum compression).\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.checksum",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.checksum",
    "category": "function",
    "text": "checksummethod = checksum(v::Variable)\n\nReturn the checksum method of the variable v which can be either be :fletcher32 or :nochecksum.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.loadragged",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.loadragged",
    "category": "function",
    "text": " data = loadragged(ncvar,index::Colon)\n\nLoad data from ncvar in the contiguous ragged array representation [1] as a vector of vectors. It is typically used to load a list of profiles or time series of different length each.\n\nThe indexed ragged array representation [2] is currently not supported.\n\n[1]: https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#contiguousraggedarrayrepresentation [2]: https://web.archive.org/web/20190111092546/http://cfconventions.org/cf-conventions/v1.6.0/cf-conventions.html#indexedraggedarrayrepresentation\n\n\n\n\n\n"
},

{
    "location": "#Variables-1",
    "page": "NCDatasets.jl",
    "title": "Variables",
    "category": "section",
    "text": "defVar\ndimnames\nname\nchunking\ndeflate\nchecksum\nloadraggedDifferent type of arrays are involved when working with NCDatasets. For instance assume that test.nc is a file with a Float32 variable called var. Assume that we open this data set in append mode (\"a\"):using NCDatasets\nds = Dataset(\"test.nc\",\"a\")\nv_cf = ds[\"var\"]The variable v_cf has the type CFVariable. No data is actually loaded from disk, but you can query its size, number of dimensions, number elements, ... by the functions size, ndims, length as ordinary Julia arrays. Once you index, the variable v_cf, then the data is loaded and stored into a DataArray:v_da = v_cf[:,:]"
},

{
    "location": "#Base.getindex-Tuple{NCDatasets.Attributes,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "getindex(a::Attributes,name::AbstractString)\n\nReturn the value of the attribute called name from the attribute list a. Generally the attributes are loaded by indexing, for example:\n\nds = Dataset(\"file.nc\")\ntitle = ds.attrib[\"title\"]\n\n\n\n\n\n"
},

{
    "location": "#Base.setindex!-Tuple{NCDatasets.Attributes,Any,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(a::Attributes,data,name::AbstractString)\n\nSet the attribute called name to the value data in the attribute list a. Generally the attributes are defined by indexing, for example:\n\nds = Dataset(\"file.nc\",\"c\")\nds.attrib[\"title\"] = \"my title\"\n\n\n\n\n\n"
},

{
    "location": "#Base.keys-Tuple{NCDatasets.Attributes}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "Base.keys(a::Attributes)\n\nReturn a list of the names of all attributes.\n\n\n\n\n\n"
},

{
    "location": "#Attributes-1",
    "page": "NCDatasets.jl",
    "title": "Attributes",
    "category": "section",
    "text": "The NetCDF dataset (as return by Dataset or NetCDF groups) and the NetCDF variables (as returned by getindex, variable or defVar) have the field attrib which has the type NCDatasets.Attributes and behaves like a julia dictionary.getindex(a::NCDatasets.Attributes,name::AbstractString)\nsetindex!(a::NCDatasets.Attributes,data,name::AbstractString)\nkeys(a::NCDatasets.Attributes)"
},

{
    "location": "#NCDatasets.defDim",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defDim",
    "category": "function",
    "text": "defDim(ds::Dataset,name,len)\n\nDefine a dimension in the data set ds with the given name and length len. If len is the special value Inf, then the dimension is considered as unlimited, i.e. it will grow as data is added to the NetCDF file.\n\nFor example:\n\nds = Dataset(\"/tmp/test.nc\",\"c\")\ndefDim(ds,\"lon\",100)\n\nThis defines the dimension lon with the size 100.\n\n\n\n\n\n"
},

{
    "location": "#Base.setindex!-Tuple{NCDatasets.Dimensions,Any,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(d::Dimensions,len,name::AbstractString)\n\nDefines the dimension called name to the length len. Generally dimension are defined by indexing, for example:\n\nds = Dataset(\"file.nc\",\"c\")\nds.dim[\"longitude\"] = 100\n\nIf len is the special value Inf, then the dimension is considered as unlimited, i.e. it will grow as data is added to the NetCDF file.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.dimnames-Tuple{NCDatasets.Variable}",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.dimnames",
    "category": "method",
    "text": "dimnames(v::Variable)\n\nReturn a tuple of the dimension names of the variable v.\n\n\n\n\n\n"
},

{
    "location": "#Dimensions-1",
    "page": "NCDatasets.jl",
    "title": "Dimensions",
    "category": "section",
    "text": "defDim\nsetindex!(d::NCDatasets.Dimensions,len,name::AbstractString)\ndimnames(v::NCDatasets.Variable)"
},

{
    "location": "#NCDatasets.defGroup-Tuple{Dataset,Any}",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defGroup",
    "category": "method",
    "text": "defGroup(ds::Dataset,groupname, attrib = []))\n\nCreate the group with the name groupname in the dataset ds. attrib is a list of attribute name and attribute value pairs (see Dataset).\n\n\n\n\n\n"
},

{
    "location": "#Base.getindex-Tuple{NCDatasets.Groups,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "method",
    "text": "group = getindex(g::NCDatasets.Groups,groupname::AbstractString)\n\nReturn the NetCDF group with the name groupname. For example:\n\njulia> ds = Dataset(\"results.nc\", \"r\");\njulia> forecast_group = ds.group[\"forecast\"]\njulia> forecast_temp = forecast_group[\"temperature\"]\n\n\n\n\n\n"
},

{
    "location": "#Base.keys-Tuple{NCDatasets.Groups}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "method",
    "text": "Base.keys(g::NCDatasets.Groups)\n\nReturn the names of all subgroubs of the group g.\n\n\n\n\n\n"
},

{
    "location": "#Groups-1",
    "page": "NCDatasets.jl",
    "title": "Groups",
    "category": "section",
    "text": "defGroup(ds::Dataset,groupname)\ngetindex(g::NCDatasets.Groups,groupname::AbstractString)\nBase.keys(g::NCDatasets.Groups)"
},

{
    "location": "#Common-methods-1",
    "page": "NCDatasets.jl",
    "title": "Common methods",
    "category": "section",
    "text": "One can iterate over a dataset, attribute list, dimensions and NetCDF groups.for (varname,var) in ds\n    # all variables\n    @show (varname,size(var))\nend\n\nfor (dimname,dim) in ds.dims\n    # all dimensions\n    @show (dimname,dim)\nend\n\nfor (attribname,attrib) in ds.attrib\n    # all attributes\n    @show (attribname,attrib)\nend\n\nfor (groupname,group) in ds.groups\n    # all groups\n    @show (groupname,group)\nend"
},

{
    "location": "#Time-functions-1",
    "page": "NCDatasets.jl",
    "title": "Time functions",
    "category": "section",
    "text": "DateTimeStandard\nDateTimeJulian\nDateTimeProlepticGregorian\nDateTimeAllLeap\nDateTimeNoLeap\nDateTime360Day\nDates.year(dt::AbstractCFDateTime)\nDates.month(dt::AbstractCFDateTime)\nDates.day(dt::AbstractCFDateTime)\nDates.hour(dt::AbstractCFDateTime)\nDates.minute(dt::AbstractCFDateTime)\nDates.second(dt::AbstractCFDateTime)\nDates.millisecond(dt::AbstractCFDateTime)\nconvert\nreinterpret\ntimedecode\ntimeencode\ndaysinmonth\ndaysinyear"
},

{
    "location": "#NCDatasets.ncgen",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.ncgen",
    "category": "function",
    "text": "ncgen(fname; ...)\nncgen(fname,jlname; ...)\n\nGenerate the Julia code that would produce a NetCDF file with the same metadata as the NetCDF file fname. The code is placed in the file jlname or printed to the standard output. By default the new NetCDF file is called filename.nc. This can be changed with the optional parameter newfname.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.nomissing",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.nomissing",
    "category": "function",
    "text": "a = nomissing(da)\n\nRetun the values of the array da of type Array{Union{T,Missing},N} (potentially containing missing values) as a regular Julia array a of the same element type and checks that no missing values are present.\n\n\n\n\n\na = nomissing(da,value)\n\nRetun the values of the array da of type Array{Union{T,Missing},N} as a regular Julia array a by replacing all missing value by value.\n\n\n\n\n\n"
},

{
    "location": "#NCDatasets.varbyattrib",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.varbyattrib",
    "category": "function",
    "text": "varbyattrib(ds, attname = attval)\n\nReturns a list of variable(s) which has the attribute attname matching the value attval in the dataset ds. The list is empty if the none of the variables has the match. The output is a list of CFVariables.\n\nExamples\n\nLoad all the data of the first variable with standard name \"longitude\" from the NetCDF file results.nc.\n\njulia> ds = Dataset(\"results.nc\", \"r\");\njulia> data = varbyattrib(ds, standard_name = \"longitude\")[1][:]\n\n\n\n\n\n"
},

{
    "location": "#Utility-functions-1",
    "page": "NCDatasets.jl",
    "title": "Utility functions",
    "category": "section",
    "text": "ncgen\nnomissing\nvarbyattrib"
},

{
    "location": "#Experimental-functions-1",
    "page": "NCDatasets.jl",
    "title": "Experimental functions",
    "category": "section",
    "text": "NCDatasets.ancillaryvariables\nNCDatasets.filter"
},

{
    "location": "#Issues-1",
    "page": "NCDatasets.jl",
    "title": "Issues",
    "category": "section",
    "text": ""
},

{
    "location": "#libnetcdf-not-properly-installed-1",
    "page": "NCDatasets.jl",
    "title": "libnetcdf not properly installed",
    "category": "section",
    "text": "If you see the following error,ERROR: LoadError: LoadError: libnetcdf not properly installed. Please run Pkg.build(\"NCDatasets\")you can try to install netcdf explicitly with Conda:using Conda\nConda.add(\"libnetcdf\")"
},

{
    "location": "#NetCDF:-Not-a-valid-data-type-or-_FillValue-type-mismatch-1",
    "page": "NCDatasets.jl",
    "title": "NetCDF: Not a valid data type or _FillValue type mismatch",
    "category": "section",
    "text": "Trying to define the _FillValue, procudes the following error:ERROR: LoadError: NCDatasets.NetCDFError(-45, \"NetCDF: Not a valid data type or _FillValue type mismatch\")The error could be generated by a code like this:using NCDatasets\n# ...\ntempvar = defVar(ds,\"temp\",Float32,(\"lonc\",\"latc\",\"time\"))\ntempvar.attrib[\"_FillValue\"] = -9999.In fact, _FillValue must have the same data type as the corresponding variable. In the case above, tempvar is a 32-bit float and the number -9999. is a 64-bit float (aka double, which is the default floating point type in Julia). It is sufficient to convert the value -9999. to a 32-bit float:tempvar.attrib[\"_FillValue\"] = Float32(-9999.)"
},

{
    "location": "#Corner-cases-1",
    "page": "NCDatasets.jl",
    "title": "Corner cases",
    "category": "section",
    "text": "An attribute representing a vector with a single value (e.g. [1]) will be read back as a scalar (1) (same behavior in python netCDF4 1.3.1).\nNetCDF and Julia distinguishes between a vector of chars and a string, but both are returned as string for ease of use, in particularan attribute representing a vector of chars [\'u\',\'n\',\'i\',\'t\',\'s\'] will be read back as the string \"units\".An attribute representing a vector of chars [\'u\',\'n\',\'i\',\'t\',\'s\',\'\\0\'] will also be read back as the string \"units\" (issue #12).<!–  LocalWords:  NCDatasets jl Datasets Dataset netCDF  –>"
},

]}
