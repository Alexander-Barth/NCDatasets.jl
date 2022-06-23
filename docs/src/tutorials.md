# NASA EarthData


This example shows show to download data via OPeNDAP from the [NASA EarthData](https://www.earthdata.nasa.gov/)
which requires a username and password.

You need to be registered at [https://urs.earthdata.nasa.gov/users/new](https://urs.earthdata.nasa.gov/users/new) 
to get your credentials.

The example requires NCDatasets 0.12.5. 


Create a `.netrc` file with the following content in your home directory:

```
machine urs.earthdata.nasa.gov
    login YOUR_USERNAME
    password YOUR_PASSWORD
```

where `YOUR_USERNAME` and `YOUR_PASSWORD` is your Earth Data username and password.

Create a `.ncrc` file with  the following content in your home directory[^1]:

```
HTTP.NETRC=/home/abarth/.netrc
```

where `HTTP.NETRC` is the full path to your new `.netrc` file[^2].
You can test whether your configuration files are correct independently of NCDatasets 
by using the tool `ncdump`:

```bash
ncdump -h "https://opendap.earthdata.nasa.gov/providers/POCLOUD/collections/GHRSST%20Level%204%20MUR%20Global%20Foundation%20Sea%20Surface%20Temperature%20Analysis%20(v4.1)/granules/20190101090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1"
```

This should return the metadata of the OPeNDAP resource:

```
netcdf \20190101090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04 {
dimensions:
	lat = 17999 ;
	lon = 36000 ;
	time = 1 ;
variables:
	short analysed_sst(time, lat, lon) ;
[...]
```

This is the typically error message which is returned when the credentails are not configured properly.

```
syntax error, unexpected WORD_WORD, expecting SCAN_ATTR or SCAN_DATASET or SCAN_ERROR
context: HTTP^ Basic: Access denied.
```

Here we use the [GHRSST Level 4 MUR Global Foundation Sea Surface Temperature Analysis (v4.1)](https://podaac.jpl.nasa.gov/dataset/MUR-JPL-L4-GLOB-v4.1) dataset.
In the following example, we download the data via OPeNDAP for a chosen bounding box and given time instance.

```julia
using NCDatasets, PyPlot, Dates, Statistics

url = "https://opendap.earthdata.nasa.gov/providers/POCLOUD/collections/GHRSST%20Level%204%20MUR%20Global%20Foundation%20Sea%20Surface%20Temperature%20Analysis%20(v4.1)/granules/20190101090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1"

ds = NCDataset(url)

# range of longitude
lonr = (-6, 37.0)

# range of latitude
latr = (29, 45.875)

ds_subset = NCDatasets.@select(
    ds["analysed_sst"],
    $lonr[1] <= lon <= $lonr[2] && $latr[1] <= lat <= $latr[2])

ncvar = ds_subset["analysed_sst"]
SST = ncvar[:,:,1]
lon = ds_subset["lon"][:]
lat = ds_subset["lat"][:]
time = ds_subset["time"][1]


clf()
pcolormesh(lon,lat,nomissing(SST,NaN)');
gca().set_aspect(1/cosd(mean(lat)))

cbar = colorbar(orientation="horizontal")
cbar.set_label(ncvar.attrib["units"])

plt.title("$(ncvar.attrib["long_name"]) $time")
```

This script produces the following plot:

![example_SST.png](assets/example_SST.png)




[^1]: Windows users need to create a `.dodsrc` configuration file (instead of the `.ncrc` file) and place it in the current working directory or set the `HOME` environment variable (see [https://github.com/Unidata/netcdf-c/issues/2380](https://github.com/Unidata/netcdf-c/issues/2380)). This NetCDF bug is likely to be fixed in NetCDF version 4.9.1.

[^2]: More information is available at [https://docs.unidata.ucar.edu/netcdf-c/4.8.1/md_auth.html](https://docs.unidata.ucar.edu/netcdf-c/4.8.1/md_auth.html).

