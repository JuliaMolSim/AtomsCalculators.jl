using AtomsBase
using AtomsCalculators
using StaticArrays
using Test
using Unitful

using AtomsCalculators.AtomsCalculatorsTesting
using AtomsCalculators.UntilityCalculators

@testset "AtomsCalculators interface" begin
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
        return 1.0u"eV" * length(system)
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.virial(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return ones(3,3) * u"eV" * length(system)
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::MyType; kwargs...)
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        f0 = SVector(1.0u"eV/Å", 1.0u"eV/Å", 1.0u"eV/Å")
        return fill(f0, length(system))
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
        calculator::MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return ( energy = 1.0u"eV", )
    end
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Virial, 
        system, 
        calculator::MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition here
        return ( virial = zeros(3,3) * u"eV", )
    end
    
    
    AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Forces, 
        system, 
        calculator::MyTypeC; 
        kwargs...
    )
        # we can ignore kwargs... or use them to tune the calculation
        # or give extra information like pairlist
    
        # add your own definition
        f = AtomsCalculators.zero_forces(system, calculator)
        return ( forces = f, )
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


@testset "UntilityCalculators" begin
    hydrogen = isolated_system([
        :H => [0, 0, 0.]u"Å",
        :H => [0, 0, 1.]u"Å",
        :H => [4., 0, 0.]u"Å",
        :H => [4., 1., 0.]u"Å"
    ])

    @testset "SubSystemCalculator" begin
        
        sub_cal = SubSystemCalculator(MyType(), 1:2)

        test_potential_energy(hydrogen, sub_cal)
        test_forces(hydrogen, sub_cal)
        test_virial(hydrogen, sub_cal)

        f = AtomsCalculators.zero_forces(hydrogen, sub_cal)
        f_zero = f[1]
        f_one = (ones ∘ typeof)( ustrip.(f_zero) ) * unit(f_zero[1])
        

        @test AtomsCalculators.potential_energy(hydrogen, sub_cal) == 2.0u"eV"

        AtomsCalculators.forces!(f, hydrogen, sub_cal)
        @test f[1] == f_one
        @test f[2] == f_one
        @test f[3] == f_zero
        @test f[4] == f_zero

        v = AtomsCalculators.virial(hydrogen, sub_cal)
        @test v[1,1] == 2.0u"eV"
    end

    @testset "CombinationCalculator" begin
        
        co_calc = CombinationCalculator(MyType(), MyType())

        test_potential_energy(hydrogen, co_calc)
        test_forces(hydrogen, co_calc)
        test_virial(hydrogen, co_calc)
        
        e = AtomsCalculators.potential_energy(hydrogen, co_calc)
        f = AtomsCalculators.forces(hydrogen, co_calc)
        v = AtomsCalculators.virial(hydrogen, co_calc)
        e_ref = 2* AtomsCalculators.potential_energy(hydrogen, MyType())
        f_ref = 2* AtomsCalculators.forces(hydrogen, MyType())
        v_ref = 2* AtomsCalculators.virial(hydrogen, MyType())
        @test e ≈ e_ref
        @test all( f .≈ f_ref )
        @test all( v .≈ v_ref )
    end

    @testset "ReportingCalculator" begin
        rcalc = ReportingCalculator(MyType(), Channel(32))
        v = AtomsCalculators.calculate(AtomsCalculators.Virial(), hydrogen, rcalc)
        @test v == fetch(rcalc)
        test_potential_energy(hydrogen, rcalc)
        test_forces(hydrogen, rcalc)
        test_virial(hydrogen, rcalc)
    end

end