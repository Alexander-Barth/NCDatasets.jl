using Documenter, NCDatasets

makedocs(modules = [NCDatasets], sitename = "NCDatasets.jl")

deploydocs(
    repo = "github.com/Alexander-Barth/NCDatasets.jl.git",
)
