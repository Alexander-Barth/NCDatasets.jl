using Pkg
Pkg.activate(@__DIR__)
CI = get(ENV, "CI", nothing) == "true"
using Documenter, NCDatasets

makedocs(modules = [NCDatasets], sitename = "NCDatasets.jl")

makedocs(modules = [NCDatasets],
sitename= "NCDatasets.jl",
doctest = false,
format = Documenter.HTML(
    prettyurls = CI,
    ),
pages = [
    "Introduction" => "index.md",
    "Datasets" => "dataset.md",
    "Dimensions" => "dimensions.md",
    "Variables" => "variables.md",
    "Attributes" => "attributes.md",
    "Performance tips" => "performance.md",
    "Known issues" => "issues.md",
    "Experimental features" => "experimental.md",

    ],
)

if CI
    deploydocs(repo = "github.com/Alexander-Barth/NCDatasets.jl.git",
               target = "build")
end
