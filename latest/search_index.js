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
    "category": "Type",
    "text": "Dataset(filename::AbstractString,mode::AbstractString = \"r\";\n                 format::Symbol = :netcdf4)\n\nCreate (mode = \"c\") or open in read-only (mode = \"r\") a NetCDF file (or an OPeNDAP URL). Supported formats:\n\n:netcdf4 (default): HDF5-based NetCDF format\n:netcdf4_classic: Only netCDF 3 compatible API features will be used\n:netcdf3_classic: classic NetCDF format supporting only files smaller than 2GB.\n:netcdf3_64bit_offset: improved NetCDF format supporting files larger than 2GB.\n\nFiles can also be open and automatically closed with a do block.\n\nDataset(\"file.nc\") do ds\n    data = ds[\"temperature\"][:,:]\nend \n\n\n\n"
},

{
    "location": "index.html#NCDatasets.defDim",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defDim",
    "category": "Function",
    "text": "defDim(ds::Dataset,name,len)\n\nDefine a dimension in the data-set ds with the given name and length len.\n\nFor example:\n\nds = Dataset(\"/tmp/test.nc\",\"c\")\ndefDim(ds,\"lon\",100)\n\nThis defines the dimension lon with the size 100.\n\n\n\n"
},

{
    "location": "index.html#Base.keys",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "Function",
    "text": "keys(a::Attributes)\n\nReturn a list of the names of all attributes.\n\n\n\nkeys(ds::Dataset)\n\nReturn a list of all variables names in Dataset ds. \n\n\n\n"
},

{
    "location": "index.html#Base.haskey",
    "page": "NCDatasets.jl",
    "title": "Base.haskey",
    "category": "Function",
    "text": "haskey(ds::Dataset,varname)\n\nReturn true of the Dataset ds has a variable with the name varname. For example:\n\nds = Dataset(\"/tmp/test.nc\",\"r\")\nif haskey(ds,\"temperature\")\n    println(\"The file has a variable 'temperature'\")\nend\n\nThis example checks if the file /tmp/test.nc has a variable with the  name temperature.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.variable",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.variable",
    "category": "Function",
    "text": "variable(ds::Dataset,varname::String)\n\nReturn the NetCDF variable varname in the dataset ds as a  NCDataset.Variable. No scaling is applied when this variable is  indexes.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.sync",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.sync",
    "category": "Function",
    "text": "sync(ds::Dataset)\n\nWrite all changes in Dataset ds to the disk.\n\n\n\n"
},

{
    "location": "index.html#Base.close",
    "page": "NCDatasets.jl",
    "title": "Base.close",
    "category": "Function",
    "text": "close(ds::Dataset)\n\nClose the Dataset ds. All pending changes will be written  to the disk.\n\n\n\n"
},

{
    "location": "index.html#Datasets-1",
    "page": "NCDatasets.jl",
    "title": "Datasets",
    "category": "section",
    "text": "Dataset\ndefDim\nkeys\nhaskey\nvariable\nsync\nclose"
},

{
    "location": "index.html#NCDatasets.defVar",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.defVar",
    "category": "Function",
    "text": "defVar(ds::Dataset,name,vtype,dimnames; kwargs...)\n\nDefine a variable with the name name in the dataset ds.  vtype can be Julia types in the table below (with the corresponding NetCDF type).  The parameter dimnames is a tuple with the names of the dimension.  For scalar this parameter is the empty tuple ().   The variable is returned (of the type CFVariable).\n\nKeyword arguments\n\nchunksizes: Vector integers setting the chunk size. \n\nThe total size of a chunk must be less than 4 GiB.\n\ndeflatelevel: Compression level: 0 (default) means no compression\n\nand 9 means maximum compression.\n\nshuffle: If true, the shuffle filter is activated which can improve the \n\ncompression ratio.\n\nchecksum: The checksum method can be :fletcher32 \n\nor :nochecksum (checksumming is disabled, which is the default)\n\nchunksizes, deflatelevel, shuffle and checksum can only be  set on NetCDF 4 files.\n\nNetCDF data types\n\nNetCDF Type Julia Type\nNC_BYTE Int8\nNC_UBYTE UInt8\nNC_SHORT Int16\nNC_INT Int32\nNC_INT64 Int64\nNC_FLOAT Float32\nNC_DOUBLE Float64\nNC_CHAR Char\nNC_STRING String\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.dimnames",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.dimnames",
    "category": "Function",
    "text": "dimnames(v::Variable)\n\nReturn a tuple of the dimension names of the variable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.name",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.name",
    "category": "Function",
    "text": "name(v::Variable)\n\nReturn the name of the NetCDF variable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.chunking",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.chunking",
    "category": "Function",
    "text": "storage,chunksizes = chunking(v::Variable)\n\nReturn the storage type (:contiguous or :chunked) and the chunk sizes  of the varable v.\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.deflate",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.deflate",
    "category": "Function",
    "text": "shuffle,deflate,deflate_level = deflate(v::Variable)\n\nReturn compression information of the variable v. If shuffle  is true, then shuffling (byte interlacing) is activaded. If  deflate is true, then the data chunks (see chunking) are  compressed using the compression level deflate_level  (0 means no compression and 9 means maximum compression).\n\n\n\n"
},

{
    "location": "index.html#NCDatasets.checksum",
    "page": "NCDatasets.jl",
    "title": "NCDatasets.checksum",
    "category": "Function",
    "text": "checksummethod = checksum(v::Variable)\n\nReturn the checksum method of the variable v which can be either  be :fletcher32 or :nochecksum.\n\n\n\n"
},

{
    "location": "index.html#Base.start-Tuple{NCDatasets.Dataset}",
    "page": "NCDatasets.jl",
    "title": "Base.start",
    "category": "Method",
    "text": "start(ds::Dataset)\n\nfor (varname,var) in ds\n    @show (varname,size(var))\nend\n\n\n\n"
},

{
    "location": "index.html#Variables-1",
    "page": "NCDatasets.jl",
    "title": "Variables",
    "category": "section",
    "text": "defVar\ndimnames\nname\nchunking\ndeflate\nchecksum\nBase.start(ds::Dataset)"
},

{
    "location": "index.html#Base.getindex-Tuple{NCDatasets.Attributes,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.getindex",
    "category": "Method",
    "text": "getindex(a::Attributes,name::AbstractString)\n\nReturn the value of the attribute called name from the  attribute list a. Generally the attributes are loaded by  indexing, for example:\n\nds = Dataset(\"file.nc\")\ntitle = ds.attrib[\"title\"]\n\n\n\n"
},

{
    "location": "index.html#Base.setindex!-Tuple{NCDatasets.Attributes,Any,AbstractString}",
    "page": "NCDatasets.jl",
    "title": "Base.setindex!",
    "category": "Method",
    "text": "Base.setindex!(a::Attributes,data,name::AbstractString)\n\nSet the attribute called name to the value data in the  attribute list a. Generally the attributes are defined by  indexing, for example:\n\nds = Dataset(\"file.nc\",\"c\")\nds.attrib[\"title\"] = \"my title\"\n\n\n\n"
},

{
    "location": "index.html#Base.keys-Tuple{NCDatasets.Attributes}",
    "page": "NCDatasets.jl",
    "title": "Base.keys",
    "category": "Method",
    "text": "keys(a::Attributes)\n\nReturn a list of the names of all attributes.\n\n\n\n"
},

{
    "location": "index.html#Attributes-1",
    "page": "NCDatasets.jl",
    "title": "Attributes",
    "category": "section",
    "text": "The NetCDF dataset (as return by Dataset) and the NetCDF variables (as returned by getindex, variable or defVar) have the field attrib which has the type NCDatasets.Attributes and behaves like a julia dictionary.getindex(a::NCDatasets.Attributes,name::AbstractString)\nsetindex!(a::NCDatasets.Attributes,data,name::AbstractString)\nkeys(a::NCDatasets.Attributes)"
},

]}
