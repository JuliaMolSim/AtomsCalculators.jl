module AtomsCalculators


using AtomsBase
using StaticArrays
using Unitful

export calculator_state, update_state
include("interface.jl")
include("utils.jl")
include("submodules/AtomsCalculatorsTesting.jl")


end
