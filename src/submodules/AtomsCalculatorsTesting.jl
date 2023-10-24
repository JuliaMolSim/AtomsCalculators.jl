module AtomsCalculatorsTesting

using ..AtomsCalculators
using Unitful
using Test

export test_potential_energy
export test_forces
export test_virial


@doc """
    test_forces(sys, calculator; force_eltype::AbstractVector=default_force_eltype, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
forces calculation.

To use this function create a `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`force_eltype` is given for `forces!` interface testing.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_forces(sys, calculator; force_eltype=nothing, kwargs...)
    @testset "Test forces for $(typeof(calculator))" begin
        ftype = something(
            force_eltype, 
            AtomsCalculators.promote_force_type(sys, calculator)
        )
        f = AtomsCalculators.forces(sys, calculator; kwargs...)
        @test typeof(f) <: AbstractVector
        @test eltype(f) <: AbstractVector
        @test length(f) == length(sys)
        T = (eltype ∘ eltype)( f )
        f_matrix = reinterpret(reshape, T, f)
        @test typeof(f_matrix) <: AbstractMatrix
        @test eltype(f_matrix) <: Number
        @test size(f_matrix) == (3, length(f))
        @test all( AtomsCalculators.forces(sys, calculator; dummy_kword659234=1, kwargs...) .≈ f )
        f_cpu_array = Array(f)  # Allow GPU output
        @test dimension(f_cpu_array[1][1]) == dimension(u"N")
        @test length(f_cpu_array[1]) == (length ∘ position)(sys,1)
        f_nonallocating = zeros(ftype, length(sys))
        AtomsCalculators.forces!(f_nonallocating, sys, calculator; kwargs...)
        @test all( f_nonallocating .≈ f  )
        AtomsCalculators.forces!(f_nonallocating, sys, calculator; dummy_kword659254=1, kwargs...)
        @test all( f_nonallocating .≈ f  )
        fc = AtomsCalculators.calculate(AtomsCalculators.Forces(), sys, calculator; kwargs...)
        @test all( f .≈ fc )
    end
end


@doc """
    test_potential_energy(sys, calculator; kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
potential energy calculation.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_potential_energy(sys, calculator; kwargs...)
    @testset "Test potential_energy for $(typeof(calculator))" begin
        e = AtomsCalculators.potential_energy(sys, calculator; kwargs...)
        @test typeof(e) <: Number
        @test dimension(e) == dimension(u"J")
        e2 = AtomsCalculators.potential_energy(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test e ≈ e2
        ec = AtomsCalculators.calculate(AtomsCalculators.Energy(), sys, calculator; kwargs...)
        @test e ≈ ec
    end
end


@doc """
    test_virial(sys, calculator; kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
virial calculation.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_virial(sys, calculator; kwargs...)
    @testset "Test virial for $(typeof(calculator))" begin
        v = AtomsCalculators.virial(sys, calculator; kwargs...)
        @test typeof(v) <: AbstractMatrix
        @test eltype(v) <: Number
        v_cpu_array = Array(v) # Allow GPU arrays
        @test dimension(v_cpu_array[1,1]) == dimension(u"J")
        l = (length ∘ position)(sys,1) 
        @test size(v) == (l,l) # allow different dimensions than 3
        v2 = AtomsCalculators.virial(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test all( v .≈ v2 )
        vc = AtomsCalculators.calculate(AtomsCalculators.Virial(), sys, calculator; kwargs...)
        @test all( v .≈ vc )
    end
end



end