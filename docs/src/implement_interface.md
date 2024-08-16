# Implementing the Interface

!!! note This describes how to implement interface based on the new `complete_interface` function. The old style used `@generate_interface` macro.

The main interface has two level high and low. You only need to implement
one of these

The interface consist of two parts the main interface functions [`potential_energy`](@ref), [`forces`](@ref) etc.
and utility functions that are needed to get the interface working.

When you make an interface you need to tell it, what is the energy unit of your calculator output and what length unit is used for forces.
These are done by extending [`energy_unit`](@ref) and [`lenght_unit`](@ref) functions.

To implement these for your calculator you can do in example following

```julia
using AtomsCalculators
using Unitful

struct MyCalc end

AtomsCalculators.energy_unit(::MyCalc) = u"eV"
AtomsCalculators.length_unit(::MyCalc) = u"Å"
```

Third important utility function is [`complete_interface`](@ref) function.
This function will inspect what methods you have implemented and implements
the missing calls. You should call this function after you have any implementations you have done, so that the function can see what you implemented.

Here is an example of a fully working implementation for an energy calculator

```julia
using AtomsCalculators
import AtomsCalculators: energy_unit, length_unit
import AtomsCalculators: potential_energy, complete_interface
using Unitful

struct MyCalc end

energy_unit(::MyCalc) = u"eV"
length_unit(::MyCalc) = u"Å"

function potential_energy(sys, ::MyCalc; kwargs...)
    return 0.0u"eV"
end

complete_interface(MyCalc)
```

The interface defines that all functions accept all keywords.
This is done in above by adding `kwargs...`. The other inputs
are [`AtomsBase`](@ref) system structure and your calculator.

[`complete_interface`](@ref) function function generate low level interface call
for `MyCalc`.

If we would have implemented the interface using low level interface, an equivalent implentation would be

```julia
using AtomsCalculators
import AtomsCalculators: energy_unit, length_unit
import AtomsCalculators: calculate, Energy ,complete_interface
using Unitful

struct MyCalc end

energy_unit(::MyCalc) = u"eV"
length_unit(::MyCalc) = u"Å"

function calculate(
    ::Energy,
    sys, 
    ::MyCalc, 
    parameters=nothing, 
    state=nothing; 
    kwargs...
)
    return ( energy=0.0u"eV", state=nothing )
end

complete_interface(MyCalc)
```

Low level interface calls return a `NamedTuple` that has fields `:state` and `:energy`, `:forces` or `:virial` based on calculation. You are free to add additional fields also.

`state` input and output is meant to represent calculators internal state. It is up to you
to define what it means. The same is for `parameters`. The interface does require that
all calculators accept `nothing` as an input for `parameters` and `state`. It means that
default values/settings are used.

If you want to use other than `nothing` for `paramers`/`state` you will also need to extend function that allow you to get and set parameters for your calculator. There are done with functions

- `get_state`
- `set_state!`
- `get_parameters`
- `set_parameters!`

Here is an example on how to implement a calculator that counts on how many times it has been called

```julia
using AtomsCalculators
import AtomsCalculators: energy_unit, length_unit
import AtomsCalculators: calculate, Energy ,complete_interface
import AtomsCalculators: get_state, set_state!
using Unitful

mutable struct MyCalc
    counter::Int
    function MyCalc(n::Int=0)
        new(n)
    end
end

energy_unit(::MyCalc) = u"eV"
length_unit(::MyCalc) = u"Å"

get_state(calc::MyCalc) = calc.counter

function set_stete!(calc::MyCalc, state)
    calc.counter = state
    return calc
end

function calculate(
    ::Energy,
    sys, 
    calc::MyCalc, 
    parameters=nothing, 
    state=nothing; 
    kwargs...
)
    n = something(state, calc.counter)
    calc.counter = n+1
    return ( energy=0.0u"eV", state=calc.counter )
end

complete_interface(MyCalc)
```

You can implement `parameters` similarly.

Final part of the interface is to test that the interface is implemented correctly.
To help with this we have implement testing function that can be found from `Testing` submodule.

To test the above example energy calculator you can call

```julia
using AtomsCalculators.Testing
using AtomsBase
using Unitful

# Generate example AtomsBase system
hydrogen = isolated_system([
    :H => [0, 0, 0.]u"Å",
    :H => [0, 0, 1.]u"Å",
])

test_potential_energy(hydrogen, MyCalc())
```


## High Level Interface in Detail


## Low Level Interface in Detail


## Utilty Functions in Detail


## Testing Functions in Detail
