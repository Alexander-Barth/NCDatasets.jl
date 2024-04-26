# Install dependencies via the R commands:
#
# install.packages("microbenchmark")
# install.packages("ncdf4")

library(ncdf4)
library(microbenchmark)

print(R.version.string)
print(paste("ncdf4 version: ",packageVersion("ncdf4")))

fname = "filename_fv.nc"

process <- function(fname,drop_caches) {
  if (drop_caches) {
    # drop file caches; requires root
    fileConn<-file("/proc/sys/vm/drop_caches",open = "wt")
    writeLines("3", fileConn)
    close(fileConn)
  }

  nc = nc_open(fname)

  # how do you get the dimension from the file?
  nmax = 100
  tot = 0
  for (n in 1:nmax) {
      slice <- ncvar_get(nc,"v1",start=c(1,1,n),count=c(-1,-1,1))
      tot <- tot + max(slice, na.rm = TRUE)
  }

  return(tot/nmax)
}

drop_caches <- "--drop-caches" %in% commandArgs(trailingOnly=TRUE)
print(paste("drop caches: ",drop_caches))
start_time <- Sys.time()
tot = process(fname,drop_caches)
end_time <- Sys.time()
print(paste("time ",end_time - start_time))

print(paste("result ",tot))

mbm <- microbenchmark("ncdf4" = process(fname,drop_caches),times=100)

fileConn<-file("R-ncdf4.txt",open = "wt")

for (n in 1:length(mbm$time)) {
   writeLines(toString(mbm$time[n]/1e9), fileConn)
}

close(fileConn)
