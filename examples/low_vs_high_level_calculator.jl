""" 
We here demonstrate the two different ways of implementing a new calculator type, 
namely the: 

1. low-level one, that goes through the implementation of `calculate` and in which 
one has to explicitly handle state and parameters using the Lux model, and provide 
sensible defaults as well 

and 

2. the high-level one, in which one implements `potential_energy` and/or `forces` and virial, 
whith no explicit handling of state, and parameters bundled inside the calculator.

"""

using AtomsCalculators
using AtomsBase
using Unitful
using UnitfulAtomic

struct HighLevelCalculator end

AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(
        system::AbstractSystem, calculator::HighLevelCalculator;
        kwargs...)
	0.0u"hartree"
end

struct LowLevelCalculator
        parameters # We here choose to allow bundling parameters inside the calculator.
end

AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
        ::AtomsCalculators.Energy,
        system::AbstractSystem,
        calculator::LowLevelCalculator,
        parameters=nothing,
        state=nothing;
        kwargs...)

        if isnothing(state)
                # default initialization
        end
        if isnothing(parameters)
                # We use the bundled parameters in the default implementation.
                parameters = calculator.parameters
        end

        # Return input state.
        return ( energy = 0.0u"hartree", state)
end

hydrogen = isolated_system([
:H => [0, 0, 0.]u"Å",
:H => [0, 0, 1.]u"Å"
])

# High-level call, implemented by the user.
AtomsCalculators.potential_energy(hydrogen, HighLevelCalculator())

# Low-level call, automaticall generated from the high-level one.
AtomsCalculators.calculate(AtomsCalculators.Energy(), hydrogen, HighLevelCalculator())

# High-level call, automaticall generated from the low-level one.
AtomsCalculators.potential_energy(hydrogen, LowLevelCalculator(nothing))

# Low-level call, implemented by the user.
AtomsCalculators.calculate(AtomsCalculators.Energy(), hydrogen, LowLevelCalculator(nothing),
                          state = 1.0)
