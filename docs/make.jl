using Documenter
using NCDatasets

makedocs(
    format = :html,
    modules = [NCDatasets],
    sitename = "NCDatasets",
    pages = [
        "index.md"]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

deploydocs(
           repo = "github.com/Alexander-Barth/NCDatasets.jl.git",
           target = "build",
           deps = nothing,
           make = nothing,    
)
