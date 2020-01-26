using Markdown
using Printf
using DelimitedFiles
using Statistics

table = Any[["Module","median","minimum","mean","std. dev."]]

fmt(x) = @sprintf("%4.3f",x)

for f in ["R-ncdf4.txt", "python-netCDF4.txt", "julia-NCDatasets.txt"]
    data = readdlm(f,' ',Float64)

    push!(table,[replace(f,".txt" => ""),
                 fmt(median(data)),fmt(minimum(data)),
                 fmt(mean(data)),fmt(std(data))])
end

print(Markdown.plain(Markdown.Table(table,[:l,:r,:r,:r,:r])))
