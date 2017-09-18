using Documenter
using Arrows

makedocs(
  modules = [Arrows],
  authors = "Zenna Tavares and contributers",
  format = :html,
  sitename = "Arrows.jl",
)

deploydocs(
    repo = "github.com/zenna/Arrows.jl.git",
    julia="0.6",
    deps=nothing,
    make=nothing,
)
