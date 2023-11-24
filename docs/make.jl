using ACDC_OPF_Belgium
using Documenter

DocMeta.setdocmeta!(ACDC_OPF_Belgium, :DocTestSetup, :(using ACDC_OPF_Belgium); recursive=true)

makedocs(;
    modules=[ACDC_OPF_Belgium],
    authors="Giacomo Bastianel, KU Leuven",
    repo="https://github.com/GiacomoBastianel/ACDC_OPF_Belgium.jl/blob/{commit}{path}#{line}",
    sitename="ACDC_OPF_Belgium.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://GiacomoBastianel.github.io/ACDC_OPF_Belgium.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/GiacomoBastianel/ACDC_OPF_Belgium.jl",
    devbranch="main",
)
