using AtomsBase
using AtomsCalculators
using Test
using Unitful

using AtomsCalculators.AtomsCalculatorsTesting

@testset "AtomsCalculators.jl" begin
    # Write your tests here.
    struct MyType
    end

    struct MyOtherType
    end

    struct MyTypeC
    end

    AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(system, calculator::Main.MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return 0.0u"eV"
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.virial(system, calculator::Main.MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return zeros(3,3) * u"eV"
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::Main.MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        return zeros(AtomsCalculators.promote_force_type(system, calculator), length(system)) 
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::Main.MyOtherType; kwargs...)
        @assert length(f) == length(system)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        for i in eachindex(f)
            f[i] = zero(AtomsCalculators.promote_force_type(system, calculator))
        end
    
        return f
    end

    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Energy, 
        system, 
        calculator::Main.MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return 0.0u"eV"
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Virial, 
        system, 
        calculator::Main.MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return zeros(3,3) * u"eV"
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Forces, 
        system, 
        calculator::Main.MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        return zeros(AtomsCalculators.promote_force_type(system, calculator), length(system)) 
    end

    hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å"
    ])

    test_potential_energy(hydrogen, MyType())
    test_forces(hydrogen, MyType())
    test_virial(hydrogen, MyType())
    test_forces(hydrogen, MyOtherType())
    
    test_potential_energy(hydrogen, MyTypeC())
    test_forces(hydrogen, MyTypeC())
    test_virial(hydrogen, MyTypeC())

    efv = AtomsCalculators.energy_forces_virial(hydrogen, MyType())
    @test haskey(efv, :energy)
    @test haskey(efv, :forces)
    @test haskey(efv, :virial)
end
