# install.packages("rbenchmark")

library(RNetCDF)
library(microbenchmark)

print(paste("RNetCDF version: ",packageVersion("RNetCDF")))

fname = "filename_fv.nc"

process <- function(fname) {
  nc = open.nc(fname)

  # how do you get the dimension from the file?
  nmax = 31
  tot = 0
  for (n in 1:nmax){
      slice <- var.get.nc(nc,"v1",start=c(1,1,n),count=c(-1,-1,1))
      tot <- tot + max(slice, na.rm = TRUE)
  }

  return(tot/nmax)
}

start_time <- Sys.time()
tot = process(fname)
end_time <- Sys.time()
print(paste("time ",end_time - start_time))

print(paste("result ",tot))

mbm <- microbenchmark("RNetCDF" = process(fname),times=100)

fileConn<-file("R-RNetCDF.txt",open = "wt")
for (n in 1:length(mbm$time)) {
   writeLines(toString(mbm$time[n]/1e9), fileConn)
}
close(fileConn)


#print(paste("R  ",median(mbm$time/1e6), min(mbm$time/1e6),mean(mbm$time/1e6),sd(mbm$time/1e6)))
