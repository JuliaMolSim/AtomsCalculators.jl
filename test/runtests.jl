using AtomsBase
using AtomsCalculators
using Test
using Unitful
using UnitfulAtomic

using AtomsCalculators.Testing


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

@testset "High-level calculator interface" begin
    struct HighLevelCalculator end
    struct HighLevelCalculatorAllocating end

    function AtomsCalculators.energy_unit(::Union{HighLevelCalculator,HighLevelCalculatorAllocating})
        u"hartree"
    end 
    function AtomsCalculators.length_unit(::Union{HighLevelCalculator,HighLevelCalculatorAllocating})
        u"bohr"
    end 
    
    AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(system, calculator::HighLevelCalculator; kwargs...)
        return 0.0u"hartree"
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.virial(system, calculator::HighLevelCalculator; kwargs...)
        return zeros(3,3) * u"hartree"
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::HighLevelCalculator; kwargs...)
        return AtomsCalculators.zero_forces(system, calculator)
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::HighLevelCalculatorAllocating; kwargs...)
        @assert length(f) == length(system)
        for i in eachindex(f)
            # forces! adds to the force array
            f[i] += zero(AtomsCalculators.promote_force_type(system, calculator))
        end
    
        return f
    end
    
    hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å"
    ])

    test_energy_forces_virial(hydrogen, HighLevelCalculator())
end

@testset "Low-level calculator interface" begin
    struct LowLevelCalculator end

    function AtomsCalculators.energy_unit(::LowLevelCalculator)
        u"hartree"
    end 
    function AtomsCalculators.length_unit(::LowLevelCalculator)
        u"bohr"
    end 

    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
            ::AtomsCalculators.Energy,
            system, calculator::LowLevelCalculator,
            parameters=nothing, state=nothing;
            kwargs...)
        return (; :energy => 0.0u"hartree", :state => nothing)
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
            ::AtomsCalculators.Virial,
            system, calculator::LowLevelCalculator,
            parameters=nothing, state=nothing;
            kwargs...)
        return (; :virial => zeros(3,3) * u"hartree", :state => nothing)
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
            ::AtomsCalculators.Forces,
            system, calculator::LowLevelCalculator,
            parameters=nothing, state=nothing;
            kwargs...)
        return (; :forces => AtomsCalculators.zero_forces(system, calculator), :state => nothing)
    end
    
    hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å"
    ])

    test_energy_forces_virial(hydrogen, LowLevelCalculator())

    efv = AtomsCalculators.energy_forces_virial(hydrogen, LowLevelCalculator())
    @test haskey(efv, :energy)
    @test haskey(efv, :forces)
    @test haskey(efv, :virial)
    
    # Test Combined calculator call
    combined = (
        AtomsCalculators.Energy(),
        AtomsCalculators.Forces(),
        AtomsCalculators.Virial()
    )

    com = AtomsCalculators.calculate(combined, hydrogen, LowLevelCalculator())
    @test isa(com, NamedTuple)
    @test haskey(com, :energy)
    @test haskey(com, :forces)
    @test haskey(com, :virial)
    @test haskey(com, :state)
end
