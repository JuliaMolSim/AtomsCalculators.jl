using AtomsBase
using AtomsCalculators
using Test
using Unitful
using UnitfulAtomic

using AtomsCalculators.Testing

@testset "Interface Generation" begin
    abstract type MyCalc end
    function AtomsCalculators.energy_unit(::MyCalc)
        u"hartree"
    end 
    function AtomsCalculators.length_unit(::MyCalc)
        u"bohr"
    end
    hydrogen = isolated_system([
            :H => [0, 0, 0.]u"Å",
            :H => [0, 0, 1.]u"Å"
        ])
    
    @testset "potential energy" begin
        struct MyCalc1 <: MyCalc end
        function AtomsCalculators.potential_energy(system, calculator::MyCalc1; kwargs...)
            return 0.0u"hartree"
        end 
        AtomsCalculators.generate_missing_interface(MyCalc1)
        test_potential_energy(hydrogen, MyCalc1())
    end

    @testset "calculate energy" begin
        struct MyCalc2 <: MyCalc end
        function AtomsCalculators.calculate(
            ::AtomsCalculators.Energy,
            system, calculator::MyCalc2,
            parameters=nothing, state=nothing;
            kwargs...)
            return (; :energy => 0.0u"hartree", :state => nothing)
        end
        AtomsCalculators.generate_missing_interface(MyCalc2)
        test_potential_energy(hydrogen, MyCalc2())
    end

    @testset "forces" begin
        struct MyCalc3 <: MyCalc end
        function AtomsCalculators.forces(system, calculator::MyCalc3; kwargs...)
            return AtomsCalculators.zero_forces(system, calculator)
        end
        AtomsCalculators.generate_missing_interface(MyCalc3)
        test_forces(hydrogen, MyCalc3())
    end

    @testset "forces!" begin
        struct MyCalc4 <: MyCalc end
        function AtomsCalculators.forces!(f::AbstractVector, system, calculator::MyCalc4; kwargs...)
            @assert length(f) == length(system)
            for i in eachindex(f)
                # forces! adds to the force array
                f[i] += zero(AtomsCalculators.promote_force_type(system, calculator))
            end
            return f
        end
        AtomsCalculators.generate_missing_interface(MyCalc4)
        test_forces(hydrogen, MyCalc4())
    end

    @testset "calculate forces" begin
        struct MyCalc5 <: MyCalc end
        function AtomsCalculators.calculate(
                ::AtomsCalculators.Forces,
                system, calculator::MyCalc5,
                parameters=nothing, state=nothing;
                kwargs...)
            return (; :forces => AtomsCalculators.zero_forces(system, calculator), :state => nothing)
        end
        AtomsCalculators.generate_missing_interface(MyCalc5)
        test_forces(hydrogen, MyCalc5())
    end


    @testset "virial" begin
        struct MyCalc6 <: MyCalc end
        function AtomsCalculators.virial(system, calculator::MyCalc6; kwargs...)
            return zeros(3,3) * u"hartree"
        end 
        AtomsCalculators.generate_missing_interface(MyCalc6)
        test_virial(hydrogen, MyCalc6())
    end

    @testset "calculate virial" begin
        struct MyCalc7 <: MyCalc end
        function AtomsCalculators.calculate(
                v::AtomsCalculators.Virial,
                system, calculator::MyCalc7,
                parameters=nothing, state=nothing;
                kwargs...)
            return (; :virial => zeros(3,3) * u"hartree", :state => nothing)
        end
        AtomsCalculators.generate_missing_interface(MyCalc7)
        test_virial(hydrogen, MyCalc7())
    end

    @testset "energy_forces" begin
        struct MyCalc8 <: MyCalc end
        function AtomsCalculators.energy_forces(system, calculator::MyCalc8; kwargs...)
            f = AtomsCalculators.zero_forces(system, calculator)
            return (energy=0.0u"hartree", forces=f)
        end
        AtomsCalculators.generate_missing_interface(MyCalc8)
        test_energy_forces(hydrogen, MyCalc8())
    end

    @testset "energy_forces_virial" begin
        struct MyCalc9 <: MyCalc end
        function AtomsCalculators.energy_forces_virial(system, calculator::MyCalc9; kwargs...)
            f = AtomsCalculators.zero_forces(system, calculator)
            v = zeros(3,3) * u"hartree"
            return (energy=0.0u"hartree", forces=f, virial=v)
        end
        AtomsCalculators.generate_missing_interface(MyCalc9)
        test_energy_forces_virial(hydrogen, MyCalc9())
    end

    @testset "energy_forces!" begin
        struct MyCalc10 <: MyCalc end
        function AtomsCalculators.energy_forces!(f::AbstractVector, system, calculator::MyCalc10; kwargs...)
            @assert length(f) == length(system)
            for i in eachindex(f)
                # forces! adds to the force array
                f[i] += zero(AtomsCalculators.promote_force_type(system, calculator))
            end
            return (energy=0.0u"hartree", forces=f)
        end
        AtomsCalculators.generate_missing_interface(MyCalc10)
        test_potential_energy(hydrogen, MyCalc10())
    end

    @testset "energy_forces_virial!" begin
        struct MyCalc11 <: MyCalc end
        function AtomsCalculators.energy_forces_virial!(f::AbstractVector, system, calculator::MyCalc11; kwargs...)
            @assert length(f) == length(system)
            for i in eachindex(f)
                # forces! adds to the force array
                f[i] += zero(AtomsCalculators.promote_force_type(system, calculator))
            end
            v = zeros(3,3) * u"hartree"
            return (energy=0.0u"hartree", forces=f, virial=v)
        end
        AtomsCalculators.generate_missing_interface(MyCalc11)
        test_energy_forces_virial(hydrogen, MyCalc11())
    end

    @testset "calculate energy and energy_forces_virial" begin
        struct MyCalc12 <: MyCalc end
        function AtomsCalculators.energy_forces_virial(system, calculator::MyCalc12; kwargs...)
            f = AtomsCalculators.zero_forces(system, calculator)
            v = zeros(3,3) * u"hartree"
            return (energy=0.0u"hartree", forces=f, virial=v)
        end
        function AtomsCalculators.calculate(
            ::AtomsCalculators.Energy,
            system, calculator::MyCalc12,
            parameters=nothing, state=nothing;
            kwargs...)
            return (; :energy => 0.0u"hartree", :state => nothing)
        end
        AtomsCalculators.generate_missing_interface(MyCalc12)
        test_energy_forces_virial(hydrogen, MyCalc12())
    end

    @testset "calculate forces and energy_forces" begin
        struct MyCalc13 <: MyCalc end
        function AtomsCalculators.energy_forces(system, calculator::MyCalc13; kwargs...)
            f = AtomsCalculators.zero_forces(system, calculator)
            return (energy=0.0u"hartree", forces=f)
        end
        function AtomsCalculators.calculate(
            ::AtomsCalculators.Forces,
            system, calculator::MyCalc13,
            parameters=nothing, state=nothing;
            kwargs...)
        return (; :forces => AtomsCalculators.zero_forces(system, calculator), :state => nothing)
    end
        AtomsCalculators.generate_missing_interface(MyCalc13)
        test_energy_forces(hydrogen, MyCalc13())
    end

end

