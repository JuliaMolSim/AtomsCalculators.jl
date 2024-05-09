module AtomsCalculatorsTesting

using ..AtomsCalculators
using Unitful
using Test

export test_potential_energy
export test_forces
export test_virial

export test_energy_forces
export test_energy_forces_virial


"""
    test_forces(sys, calculator; force_eltype::AbstractVector=default_force_eltype, rtol=1e8, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
forces calculation implementation works correctly.

To use this function create a `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`force_eltype` can be given to `forces!` interface testing. Default `promote_force_type`.
`rtol` can be given to control error in comparisons.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_forces(sys, calculator; force_eltype=nothing, rtol=1e8, kwargs...)
    @testset "Test forces for $(typeof(calculator))" begin
        ftype = something(
            force_eltype, 
            AtomsCalculators.promote_force_type(sys, calculator)
        )
        f = AtomsCalculators.forces(sys, calculator; kwargs...)
        @test typeof(f) == typeof(AtomsCalculators.zero_forces(sys,calculator))
        @test eltype(f) == ftype
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
        @test all( f_nonallocating .- f  ) do Δf # f_nonallocating ≈ f
            isapprox( ustrip.( zero(ftype) ), ustrip.(Δf); rtol=rtol)
        end
        AtomsCalculators.forces!(f_nonallocating, sys, calculator; dummy_kword659254=1, kwargs...)
        @test all( f_nonallocating .- 2f  ) do Δf # non-allocating is additive and called twice
            isapprox( ustrip.( zero(ftype) ), ustrip.(Δf); rtol=rtol)
        end
        fc = AtomsCalculators.calculate(AtomsCalculators.Forces(), sys, calculator; kwargs...)
        @test isa(fc, NamedTuple)
        @test haskey(fc, :forces)implements the whole interfaceftype) ), ustrip.(Δf); rtol=rtol)
        end
    end
end


"""
    test_potential_energy(sys, calculator; rtol=1e8, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
potential energy calculation implementation works correctly.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`rtol` can be given to control error in comparisons.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_potential_energy(sys, calculator; rtol=1e8, kwargs...)
    @testset "Test potential_energy for $(typeof(calculator))" begin
        e = AtomsCalculators.potential_energy(sys, calculator; kwargs...)
        @test typeof(e) <: Number
        @test dimension(e) == dimension(u"J")
        e2 = AtomsCalculators.potential_energy(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test e ≈ e2 rtol=rtol
        ec = AtomsCalculators.calculate(AtomsCalculators.Energy(), sys, calculator; kwargs...)
        @test isa(ec, NamedTuple)
        @test haskey(ec, :energy)
        @test e ≈ ec[:energy] rtol=rtol
    end
end


"""
    test_virial(sys, calculator; kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
virial calculation implementation works correctly.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_virial(sys, calculator; rtol=1e8, kwargs...)
    @testset "Test virial for $(typeof(calculator))" begin
        v = AtomsCalculators.virial(sys, calculator; kwargs...)
        @test typeof(v) <: AbstractMatrix
        @test eltype(v) <: Number
        v_cpu_array = Array(v) # Allow GPU arrays
        @test dimension(v_cpu_array[1,1]) == dimension(u"J")
        l = (length ∘ position)(sys,1) 
        @test size(v) == (l,l) # allow different dimensions than 3
        v2 = AtomsCalculators.virial(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test all( isapprox.(v, v2; rtol=rtol ) )
        vc = AtomsCalculators.calculate(AtomsCalculators.Virial(), sys, calculator; kwargs...)
        @test isa(vc, NamedTuple)
        @test haskey(vc, :virial)
        @test all( isapprox(v, vc[:virial], rtol=rtol ) )
    end
end


"""
    test_energy_forces(sys, calculator; force_eltype=nothing, rtol=1e8, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
calculator implements energy and forces interfaces correctly.

To use this function create a `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`force_eltype` can be given to `forces!` interface testing. Default `promote_force_type`.
`rtol` can be given to control error in comparisons.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_energy_forces(sys, calculator; force_eltype=nothing, rtol=1e8, kwargs...)
    test_potential_energy(sys, calculator; rtol=rtol, kwargs...)
    test_forces(sys, calculator; force_eltype=force_eltype, rtol=rtol, kwargs...)
    @testset "Test energy_forces for $(typeof(calculator))" begin
        e0 = AtomsCalculators.potential_energy(sys, calculator; kwargs...)
        f0 = AtomsCalculators.forces(sys, calculator; kwargs...)
        res = AtomsCalculators.energy_forces(sys, calculator; kwargs...)
        @test isa(res, NamedTuple)
        @test haskey(res, :energy)
        @test haskey(res, :forces)
        @test e0 ≈ res[:energy] rtol=rtol
        @test all( f0 .- res[:forces]  ) do Δf
            isapprox( ustrip.( zero(Δf) ), ustrip.(Δf); rtol=rtol)
        end
        f1 = AtomsCalculators.zero_forces(sys, calculator)
        res2 = AtomsCalculators.energy_forces!(f1, sys, calculator; kwargs...)
        @test isa(res2, NamedTuple)
        @test haskey(res2, :energy)
        @test haskey(res2, :forces)
        @test all( f1 .≈ res2[:forces] )
        @test e0 ≈ res2[:energy] rtol=rtol
        @test all( f0 .- res2[:forces]  ) do Δf
            isapprox( ustrip.( zero(Δf) ), ustrip.(Δf); rtol=rtol)
        end
    end
end


"""
    test_energy_forces_virial(sys, calculator; force_eltype=nothing, rtol=1e8, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
calculator implements energy, forces and virial interfaces correctly.

To use this function create a `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`force_eltype` can be given to `forces!` interface testing. Default `promote_force_type`.
`rtol` can be given to control error in comparisons.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_energy_forces_virial(sys, calculator; force_eltype=nothing, rtol=1e8, kwargs...)
    test_energy_forces(sys, calculator; force_eltype=force_eltype, rtol=rtol, kwargs...)
    test_virial(sys, calculator, kwargs...)
    @testset "Test energy_forces_virial for $(typeof(calculator))" begin
        e0 = AtomsCalculators.potential_energy(sys, calculator; kwargs...)
        f0 = AtomsCalculators.forces(sys, calculator; kwargs...)
        v0 = AtomsCalculators.virial(sys, calculator; kwargs...)
        res = AtomsCalculators.energy_forces_virial(sys, calculator; kwargs...)
        @test isa(res, NamedTuple)
        @test haskey(res, :energy)
        @test haskey(res, :forces)
        @test haskey(res, :virial)
        @test e0 ≈ res[:energy] rtol=rtol
        @test all( f0 .- res[:forces]  ) do Δf
            isapprox( ustrip.( zero(Δf) ), ustrip.(Δf); rtol=rtol)
        end
        @test all( isapprox(v0, res[:virial]; rtol=rtol) )

        f1 = AtomsCalculators.zero_forces(sys, calculator)
        res2 = AtomsCalculators.energy_forces_virial!(f1, sys, calculator; kwargs...)
        @test isa(res2, NamedTuple)
        @test haskey(res2, :energy)
        @test haskey(res2, :forces)
        @test all( f1 .≈ res2[:forces] )
        @test e0 ≈ res2[:energy] rtol=rtol
        @test all( f0 .- res2[:forces]  ) do Δf
            isapprox( ustrip.( zero(Δf) ), ustrip.(Δf); rtol=rtol)
        end
        @test all( isapprox(v0, res2[:virial]; rtol=rtol) )
    end
end


end