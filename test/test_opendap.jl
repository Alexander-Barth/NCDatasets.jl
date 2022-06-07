using NCDatasets
using Test


@show get(ENV,"TEMP","not defined")

ENV["TEMP"] = "."
ds = NCDataset("https://erddap.ifremer.fr/erddap/griddap/SDC_GLO_CLIM_TS_V2_1")

time = ds["time"][:]
@test length(time) > 0
