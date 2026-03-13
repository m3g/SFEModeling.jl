using Documenter
using SFEModeling
using Documenter.Remotes: GitHub

ENV["LINES"] = 10
ENV["COLUMNS"] = 120

makedocs(;
    modules=[SFEModeling],
    sitename="SFEModeling.jl",
    repo=GitHub("m3g", "SFEModeling.jl"),
    pages=[
        "Home" => "index.md",
        "Installation" => "installation.md",
        "GUI" => "gui.md",
        "Advanced usage" => "usage.md",
        "Model" => "model.md",
        "API Reference" => "api.md",
    ],
    warnonly=true,
)

deploydocs(;
    repo="github.com/m3g/SFEModeling.jl",
    devbranch="main",
    push_preview=true,
)
