using AtomsBase
using AtomsCalculators
using Test
using Unitful

using AtomsCalculators.AtomsCalculatorsTesting

@testset "AtomsCalculators.jl" begin

    @testset "Interface" begin include("test_interface.jl"); end 
    @testset "FDTests" begin include("test_fdtests.jl"); end
end
