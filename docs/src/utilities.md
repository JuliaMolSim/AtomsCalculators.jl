
```@meta
CurrentModule = AtomsCalculators
```

# Utilities

The main AtomsCalculators packgage has utilities that help creating calculators and testing functions that help to test that your calculator implement the interface correctly.

In additionally there is [AtomsCalculatorsUtilities](https://github.com/JuliaMolSim/AtomsCalculatorsUtilities.jl) package that has utility calculators and other helpful utilities.

## Interface generating macro

AtomsCalculator provide a macro [`@generate_inferface`](@ref) that generate other interfaces from the input.

In example, if you only provide high level interface you can just implement

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces(
    sys,
    calc::MyCalc;
    kwords...
)
   #definition
end
```

This also creates low level calls for your calculator and also non-allocating high level call. So, you will get:

- The call you implemented - here high level `forces` call
- Non-allocating `forces!` call
- Low level `calculate(::Forces(), sys, calc::MyCalc, ps=nothing, st=nothing; kwargs...)`

You would get the same calls generated, if you defined any of the above calls and wrapped it in the macro. Thus all of the following produce the same interface

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces(
    sys,
    calc::MyCalc; 
    kwords...
)
   #definition
end

AtomsCalculators.@generate_interface function AtomsCalculators.forces!(
    f, 
    sys, 
    calc::MyCalc; 
    kwords...
)
   #definition
end

AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Force,
    sys,
    calc::MyCalc,
    ps=nothing,
    st=nothing;
    kwords...
)
   #definition
end
```

and you only need to define one of them.

### Example macro use

To implement complite interface by only defining high level call you can define

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(
    sys,
    calc::MyCalc; 
    kwords...
)
   #definition
end

# or alternatively forces! call
AtomsCalculators.@generate_interface function AtomsCalculators.forces(
    sys,
    calc::MyCalc; 
    kwords...
)
   #definition
end

AtomsCalculators.@generate_interface function AtomsCalculators.virial(
    sys,
    calc::MyCalc; 
    kwords...
)
   #definition
end
```

With low level call you can implement

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Energy,
    sys,
    calc::MyCalc,
    ps=nothing,
    st=nothing;
    kwords...
)
   #definition
end

AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Force,
    sys,
    calc::MyCalc,
    ps=nothing,
    st=nothing;
    kwords...
)
   #definition
end

AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Virial,
    sys,
    calc::MyCalc,
    ps=nothing,
    st=nothing;
    kwords...
)
   #definition
end

```

Both of these methods create fully working implementation.


## Testing functions

AtomsCalculators has a submodule `Testing` that includes testing functions

- [`test_potential_energy(sys, calc)`](@ref) that test the interface for potential energy calculation
- [`test_forces(sys, calc)`](@ref) that test the interface for forces calculation
- [`test_virial(sys, calc)`](@ref) that test the interface for forces calculation

There is also test functions that combine the above calls

- [`test_energy_forces(sys, calc)`](@ref) that test the interface for potential energy and forces
- [`test_energy_forces_virial(sys, calc)`](@ref) that test the interface for potential energy, forces and virial

It is recommended to use appropriate combined call, if your calculator has implemented more than one of the methods.

Passing the testing set confirms that your calculator implements the interface correctly.

### Testing example

```julia
using AtomsCalculators.Testing

sys = # create/load a AtomsBase system structure, which the calculator is expected to calculate
mycalc = # Create your calculator

# Test potential energy calculation
test_potential_energy(sys, mycalc)
# Test forces calculation
test_forces(sys, calc)

# Same as the two above commands together
test_energy_forces(sys, calc)
```
