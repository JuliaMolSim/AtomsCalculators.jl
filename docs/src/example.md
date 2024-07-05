## Implementing the interface

**Note, this section is partly outdated!**

You can either implement both of the calls e.g. for energy

`AtomsCalculators.potential_energy(system, calculator; kwargs...)` and
`AtomsCalculators.calculate(AtomsCalculators.Energy(), system, calculator, ps=nothing, st=nothing; kwargs...)`

### Example implementations

Example `potential_energy` implementation

```julia
using AtomsCalculators
using Unitful
struct MyType
end

AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return 0.0u"eV"
end
```

Completely equivalent implementation is

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Energy, 
    system, 
    calculator::MyType,
    ps=nothing,
    st=nothing; 
    kwargs...
)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return ( energy = 0.0u"eV, )
end
```

Example `virial` implementation

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.virial(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return zeros(3,3) * u"eV"
end
```

Equivalent implementation is

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Virial, 
    system, 
    calculator::MyType,
    ps=nothing,
    st=nothing;
    kwargs...
)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return ( virial = zeros(3,3) * u"eV", state=nothing)
end
```

### Implementing forces call

Basic example

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    return AtomsCalculators.zero_forces(system, calculator)
end
```

This creates both `forces` and `forces!` and `calculate` command with `Forces()` support.

`AtomsCalculators.zero_forces(system, calculator)` is a function that creates zero forces for a given calculator and system combo. You can use this function to tune your force output.

Same way `AtomsCalculators.promote_force_type(system, calculator)` creates a force type for the calculator for given input that can be used to allocate force data. You can also allocate for some other type, of your choosing or use the default one. You can overload `promote_force_type` for your force type, this is automatically used by `zero_forces` command to change the element type. If you wan to change array type overload `zero_forces` for your calculator.

Alternatively the definition could have been done with

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(
    ::AtomsCalculators.Forces, 
    system, 
    calculator::MyType,
    ps=nothing,
    st=nothing;
    kwargs...
)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    return ( forces = zeros(AtomsCalculators.promote_force_type(system, calculator), length(system)), state=nothing )
end
```

or with non-allocating forces

```julia
struct MyOtherType
end

AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::MyOtherType; kwargs...)
    @assert length(f) == length(system)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    for i in eachindex(f)
        # forces! adds to the force array
        f[i] += zero(AtomsCalculators.promote_force_type(system, calculator))
    end

    return f
end
```

## Other Automatically Generated Calls

Many methods have optimized calls when energy and forces (and/or virial) are calculated together. To allow access to these calls there are also calls

- `energy_forces` for potential energy and allocating forces
- `energy_forces!` for potential energy and non-allocating forces
- `energy_forces_virial` for potential energy, allocating forces and virial
- `energy_forces_virial!` for potential energy, non-allocating forces and virial

These all are generated automatically, if you have defined the corresponding individual methods. The main idea here is that you can implement more efficient methods by yourself.

Example implementation

```julia
function AtomsCalculators.potential_energy_forces(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    E = 0.0u"eV"
    f = zeros(AtomsCalculators.default_force_eltype, length(system))
    return (;
        :energy => E,
        :forces => f
    )
end
```

Defining this does not overload the corresponding non-allocating call - you need to do that separately.

Output for the combination methods is defined to have keys `:energy`, `:forces` and `:virial`. You can access them with

- `output[:energy]` for energy
- `output[:forces]` for forces
- `output[:virial]` for viral

The type of the output can be [NamedTuple](https://docs.julialang.org/en/v1/base/base/#Core.NamedTuple), as was in the example above, or any structure that has the keys implemented and also supports splatting. The reason for this is that this allows everyone to implement the performance functions without being restricted to certain output type, and to allow using `haskey` to check the output.

## Testing Function Calls

We have implemented function calls to help you testing the API. There is one call for each type of calls

- `test_potential_energy` to test potential_energy call
- `test_forces` to test both allocating and non-allocating force calls
- `test_virial` to test virial call
- `test_energy_forces` to test both potential energy and force calls
- `test_energy_forces_virial` to test everything 

To get these access to these functions you need to call

```julia
using AtomsCalculators.AtomsCalculatorsTesting
```

To test our example potential `MyType` we can do

```julia
using AtomsBase
using AtomsCalculators.AtomsCalculatorsTesting

hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å"
])

test_potential_energy(hydrogen, MyType())
test_forces(hydrogen, MyType())
test_virial(hydrogen, MyType())

test_forces(hydrogen, MyOtherType()) # this works
test_virial(hydrogen, MyOtherType()) # this will fail

# If you have energy and forces implemented use this over others
test_energy_forces(hydrogen, MyType())

# If you have energy, forces and virial implemented use this others
test_energy_forces_virial(hydrogen, MyType())
```

*It is recommended that you use the test functions to test that your implementation supports the API fully!*
