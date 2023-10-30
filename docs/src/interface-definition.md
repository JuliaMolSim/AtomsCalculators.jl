# Interface Definition

There are two alternative ways to call the interface: using functions `potential_energy`, `forces` and [virial](https://en.wikipedia.org/wiki/Virial_stress), or using `calculate`
function together with `Energy`, `Forces` and `Virial`.

Individual calls are implemented by dispatching `AtomsCalculators` functions

- `AtomsCalculators.potential_energy` for potential energy calculation
- `AtomsCalculators.forces` for allocating force calculation and/or...
- `AtomsCalculators.forces!` for non-allocating force calculation
- `AtomsCalculators.virial` for [virial](https://en.wikipedia.org/wiki/Virial_stress) calculation

The `calculate` interface is implemented by dispatching to

- `AtomsCalculators.calculate` using `AtomsCalculators.Energy()` as the first argument for energy calculation
- `AtomsCalculators.calculate` using `AtomsCalculators.Forces()` as the first argument for forces calculaton
- `AtomsCalculators.calculate` using `AtomsCalculators.Virial()` as the first argument for virial calculation

You do not need to implement all of these by yourself. There is macro that will help implement the other calls. 

Each of the individual calls have two common inputs: `AtomsBase.AbstractSystem` compatible structure and a `calculator` that incudes details of the calculation method. Calculate interface has additionally the type of calculation as the first input. You can tune calculation by passing keyword arguments, which can be ignored, but they need to be present in the function definition.

`potential_energy`, `forces`, `forces!` and `virial`:

- First input is `AtomsBase.AbstractSystem` compatible structure
- Second input is `calculator` structure
- Method has to accept keyword arguments (they can be ignored)
- Non-allocating force call `force!` has an AbstractVector as the first input, to which the evaluated force values are stored (look for more details below)

`calculate`:

- First input is either `Energy()`, `Forces()` or `Virial()`
- Second is `AtomsBase.AbstractSystem` compatible structure
- Third is `calculator` structure
- Method has to accept keyword arguments (they can be ignored)

## Output

Outputs for the functions need to have following properties

- Energy is a subtype of `Number` that has a unit with dimensions of energy (mass * length^2 / time^2)
- Force output is a subtype of `AbstractVector` with element type also a subtype of AbstractVector (length 3 in 3D) and unit with dimensions of force (mass * length / time^2). With additional property that it can be reinterpret as a matrix
- Virial is a square matrix (3x3 in 3D) that has units of force times length or energy
- Calculate methods return a [NamedTuple](https://docs.julialang.org/en/v1/base/base/#Core.NamedTuple) that uses keys `:energy`, `:forces` and `:virial` to identify the results, which have the types defined above


## Implementing the interface

You can either implement both of the calls e.g. for energy

`AtomsCalculators.potential_energy(system, calculator; kwargs...)` and
`AtomsCalculators(AtomsCalculators.Energy(), system, calculator; kwargs...)`

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
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(::AtomsCalculators.Energy, system, calculator::MyType; kwargs...)
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
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(::AtomsCalculators.Virial, system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return ( virial = zeros(3,3) * u"eV", )
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
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(::AtomsCalculators.Forces, system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    return ( forces = zeros(AtomsCalculators.promote_force_type(system, calculator), length(system)), )
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
        f[i] = zero(AtomsCalculators.promote_force_type(system, calculator))
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
```

*It is recommended that you use the test functions to test that your implementation supports the API fully!*