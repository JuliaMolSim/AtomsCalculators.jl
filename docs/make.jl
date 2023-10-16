using AtomsCalculators
using Documenter

DocMeta.setdocmeta!(AtomsCalculators, :DocTestSetup, :(using AtomsCalculators); recursive=true)

makedocs(;
    modules=[AtomsCalculators],
    authors="JuliaMolSim contributors",
    repo="https://github.com/teemu/AtomsCalculators.jl/blob/{commit}{path}#{line}",
    sitename="AtomsCalculators.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://teemu.github.io/AtomsCalculators.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/teemu/AtomsCalculators.jl",
    devbranch="master",
)
