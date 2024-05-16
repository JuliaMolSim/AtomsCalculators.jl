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

    AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return 0.0u"eV"
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.virial(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return zeros(3,3) * u"eV"
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        return AtomsCalculators.zero_forces(system, calculator)
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::MyOtherType; kwargs...)
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
        calculator::MyTypeC,
        parameters=nothing,
        state=nothing;
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return ( energy = 0.0u"eV", state = nothing )
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Virial, 
        system, 
        calculator::MyTypeC,
        parameters=nothing,
        state=nothing;
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return ( virial = zeros(3,3) * u"eV", state = nothing )
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Forces, 
        system, 
        calculator::MyTypeC,
        parameters=nothing,
        state=nothing;
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        f = AtomsCalculators.zero_forces(system, calculator)
        return ( forces = f, state = nothing )
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

@testset "Parsing macro" begin
    expr_low_level_energy = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Energy, system::AbstractSystem,
                                            calculator::LowLevelCalculator,
                                            parameters=nothing, state=nothing;
                                            kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_low_level_energy).args[1])[:type] == :Energy
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_low_level_energy).args[1])[:calculator] == true

    expr_low_level_forces = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Forces, system::AbstractSystem,
                                            calculator::LowLevelCalculator,
                                            parameters=nothing, state=nothing;
                                            kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_low_level_forces).args[1])[:type] == :Forces
    
    expr_low_level_virial = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Virial, system::AbstractSystem,
                                            calculator::LowLevelCalculator,
                                            parameters=nothing, state=nothing;
                                            kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_low_level_virial).args[1])[:type] == :Virial

    expr_high_level_energy = quote
        function AtomsCalculators.potential_energy(system::AbstractSystem,
                                                   calculator::HighLevelCalculator;
                                                   kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_high_level_energy).args[1])[:type] == :potential_energy
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_high_level_energy).args[1])[:calculator] == false
    
    expr_high_level_forces = quote
        function AtomsCalculators.forces(system::AbstractSystem,
                                                   calculator::HighLevelCalculator;
                                                   kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_high_level_forces).args[1])[:type] == :forces
    
    expr_high_level_forces! = quote
        function AtomsCalculators.forces!(system::AbstractSystem,
                                                   calculator::HighLevelCalculator;
                                                   kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_high_level_forces!).args[1])[:type] == :forces!
    
    expr_high_level_virial = quote
        function AtomsCalculators.virial(system::AbstractSystem,
                                                   calculator::HighLevelCalculator;
                                                   kwargs...)
        end
    end
    @test AtomsCalculators.determine_type_calculation(
        Base.remove_linenums!(expr_high_level_virial).args[1])[:type] == :virial
end
