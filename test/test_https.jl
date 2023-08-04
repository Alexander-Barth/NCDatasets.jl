using NCDatasets
using Test

sample_url = "https://rda.ucar.edu/thredds/dodsC/files/g/ds084.1/2018/20181231/gfs.0p25.2018123118.f003.grib2"

# opendal server too unreliable
# @test begin
#     NCDataset(sample_url) do ds
#         haskey(ds,"lon")
#     end
# end
