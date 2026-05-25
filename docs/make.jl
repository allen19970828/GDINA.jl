using Documenter
using GDINA

makedocs(
    sitename = "GDINA.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = String[],
    ),
    modules = [GDINA],
    remotes = nothing,
    checkdocs = :none,
    warnonly = true,
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md"
    ]
)
