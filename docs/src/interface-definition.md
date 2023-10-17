# Interface Definition

There are three main targets for calculations `potential_energy`, `forces` and [virial](https://en.wikipedia.org/wiki/Virial_stress). 

Individual calls are implemented by overloading `AtomsCalculators` functions

- `AtomsCalculators.potential_energy` for potential energy calculation
- `AtomsCalculators.forces` for allocating force calculation and/or...
- `AtomsCalculators.forces!` for non-allocating force calculation
- `AtomsCalculators.virial` for [virial](https://en.wikipedia.org/wiki/Virial_stress) calculation

You do not need to implement all of these. To implement force calculation you only need to implement either allocating or non-allocating force call - see below for more details on how to implement force calculation.

Each call has two inputs: `AtomsBase.AbstractSystem` compatible structure and a `calculator` that incudes details of the calculation method. Additionally keywords can be give. These can be ignored, but they need to be present in the function definition.

- First input is `AtomsBase.AbstractSystem` compatible structure
- Second input is `calculator` structure
- Method has to accept keyword arguments (they can be ignored)
- Non-allocating force call `force!` has an AbstractVector as the first input, to which the evaluated force values are stored (look for more details below)

Outputs for the functions need to have following properties

- Energy is a subtype of `Number` that has a unit with dimensions of energy (mass * length^2 / time^2)
- Force output is a subtype of `AbstractVector` with element type also a subtype of AbstractVector (length 3 in 3D) and unit with dimensions of force (mass * length / time^2). With additional property that it can be reinterpret as a matrix
- Virial is a square matrix (3x3 in 3D) that has units of energy times length


## Example implementations

Example `potential_energy` implementation

```julia
function AtomsCalculators.potential_energy(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return 0.0u"eV"
end
```

Example `virial` implementation

```julia
function AtomsCalculators.virial(system, calculator::MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition here
    return zeros(3,3) * u"eV*Å"
end
```

### Implementing forces call

There are two optional implementations for force call allocating and non-allocating. The reason for this is that for very fast potentials allocation has noticeable effect on total evaluation time. So, in order to reduce the evaluation time, there is non-allocating option. On the other hand some expensive methods, like those in quantum chemistry, always allocate output data.

To make implementation easy for everyone, we made it so that you need only to define either allocating or non-allocating force call. The other call is generated is then generated with a macro `AtomsCalculators.@generate_complement`.

Example

```julia
struct MyType
end

AtomsCalculators.@generate_complement function AtomsCalculators.forces(system, calculator::Main.MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    return zeros(AtomsCalculators.default_force_eltype, length(system))
end
```

This creates both `forces` and `forces!`. `AtomsCalculators.default_force_eltype` is a type that can be used to allocate force data. You can also allocate for some other type.

!!! note "Type definition under @generate_complement macro"
    You need to use explicit definition of type when using
    `@generate_complement` macro. `Main.MyType` is fine `MyType` is not!

    You also need to define the type before macro call.

Alternatively the definition could have been done with

```julia
struct MyOtherType
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
```

## Other Automatically Generated Calls

Many methods have optimized calls when energy and forces (and/or virial) are calculated. To allow access to these calls there are also calls

- `energy_forces` for potential energy and allocating forces
- `energy_forces!` for potential energy and non-allocating forces
- `energy_forces_virial` for potential energy, allocating forces and virial
- `energy_forces_virial!` for potential energy, non-allocating forces and virial

These all are generated automatically, if you have defined the corresponding individual methods. The main idea here is that you can implement more efficient methods by your self.

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

The type of the output can be [NamedTuple](https://docs.julialang.org/en/v1/base/base/#Core.NamedTuple), as was in the example above, [Dictionary](https://docs.julialang.org/en/v1/base/collections/#Dictionaries) or any structure that has the keys implemented. The reason for this is that this allows everyone to implement the performance functions without being restricted to certain output type, and to allow using `haskey` to check the output.

## Testing Function Calls

We have implemented function calls to help you testing the API. There is one call for each type of calls 

- `AtomsCalculators.test_potential_energy` to test potential_energy call
- `AtomsCalculators.test_forces` to test both allocating and non-allocating force calls
- `AtomsCalculators.test_virial` to test virial call

These functions take the same (non-allocating) input than the API calls.

To test our example potential `MyType` we can do

```julia
hydrogen = isolated_system([
    :H => [0, 0, 1.]u"bohr",
    :H => [0, 0, 3.]u"bohr"
])

AtomsCalculators.test_potential_energy(hydrogen, MyType())
AtomsCalculators.test_forces(hydrogen, MyType())
AtomsCalculators.test_virial(hydrogen, MyType())

AtomsCalculators.test_forces(hydrogen, MyOtherType()) # this works
AtomsCalculators.test_virial(hydrogen, MyOtherType()) # this will fail
```

*It is recommended that you use the test functions to test that your implementation supports the API fully!*