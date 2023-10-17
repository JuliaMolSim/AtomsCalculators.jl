using AtomsBase
using AtomsCalculators
using Test
using Unitful


@testset "AtomsCalculators.jl" begin
    # Write your tests here.
    struct MyType
    end

    struct MyOtherType
    end

    function AtomsCalculators.potential_energy(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return 0.0u"eV"
    end
    
    function AtomsCalculators.virial(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return zeros(3,3) * u"eV*Å"
    end
    
    
    AtomsCalculators.@generate_complement function AtomsCalculators.forces(system, calculator::Main.MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        return zeros(AtomsCalculators.default_force_eltype, length(system)) 
    end
    
    AtomsCalculators.@generate_complement function AtomsCalculators.forces!(f::AbstractVector, system, calculator::Main.MyOtherType; kwargs...)
        @assert length(f) == length(system)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        for i in eachindex(f)
            f[i] = zero(AtomsCalculators.default_force_eltype)
        end
    
        return f
    end

    hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å"
    ])

    AtomsCalculators.test_potential_energy(hydrogen, MyType())
    AtomsCalculators.test_forces(hydrogen, MyType())
    AtomsCalculators.test_virial(hydrogen, MyType())
    AtomsCalculators.test_forces(hydrogen, MyOtherType())

    efv = AtomsCalculators.energy_forces_virial(hydrogen, MyType())
    @test haskey(efv, :energy)
    @test haskey(efv, :forces)
    @test haskey(efv, :virial)
end
