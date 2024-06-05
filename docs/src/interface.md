```@meta
CurrentModule = AtomsCalculators
```

# Interface Definition

The `AtomsCalculator` interface is designed to provide easy to use and easy to read high level functions for standard molecular mechanics, while at the same time being flexible and extensible. Moreover the flexible low-level interface is designed to be compatible with [`Lux.jl`](https://lux.csail.mit.edu/stable/) to enable training of parameterized models. Due to this tension (ease of use vs flexibility) there are two alternative ways to call and implement the interface, which are described in separate sections below. 

A new calculator need not implement the entire interface, or indeed both interfaces to be useful. Moreover, `AtomsCalculators` provides [various utilities](utilities.md) to help with the implementation.

Most interface functions have two common inputs: an `AtomsBase.AbstractSystem{D}` compatible structure and a "calculator" that specifies details of the calculation method. Throughout this documentation: 
- `sys` : always specifies a system, usually an `AtomsBase.AbstractSystem{D}`
- `calc` : always specifies a calculator implementing (part of) the `AtomsCalculators` interface. 

## [High-Level Interface](@id highlevelinterface)

The high-level interface provides function prototypes for potential energy, forces and [virial](https://en.wikipedia.org/wiki/Virial_stress) calculations.

### Minimal high-level interface

A minimal implementation of an `AtomsCalculators` calculator should provide (however, see alternatives below)
- [`energy_unit(calc)`](@ref) : return energy unit used by the calculator
- [`length_unit(calc)`](@ref) : return length unit used by the calculator
- [`potential_energy(sys, calc; kwargs...)`](@ref) : return potential energy of the system as a `Unitful.Energy`
- [`forces(sys, calc; kwargs...)`](@ref) return forces as an `AbstractVector{SVector{D, <: Unitful.Force}}`
- [`virial(sys, calc; kwargs...)`](@ref) return virial (not stress!) as a `SMatrix{D, D, Unitful.Energy}`

#### Remarks 

- Methods must accept keyword arguments, but they can be ignored. For a discussion of some standard keyword arguments that a calculator may wish to support see [Reserved Keyword Arguments](@ref keywordargs). 
- If a calculator does not implement a function, then it can simply choose to provide that method. A simulator that relies on that function will then simply fail. For example a QM/MM force mixing scheme may be unable to provide `potential_energy`. 

### Extended high-level interface 

The extended interface can be automatically generated from the minimal interface, but for various reasons (in particular performance), some calculators may prefer to implement their own methods for the following functions.

Several utility functions are derived from `energy_unit` and `length_unit` which can be overloaded by a calculator implementation: 

- [`force_unit(calc)`](@ref) : compute force unit (default from energy and length units)
- [`promote_force_type(sys, calc)`](@ref) : determine type of force
- [`zero_energy(sys, calc)`](@ref) : initialize potential energy 
- [`zero_forces(sys, calc)`](@ref) : initilize a force vector 
- [`zero_virial(sys, calc)`](@ref) : initialize a virial matrix 

A calculator may provide non-allocating and or combined calculations that can sometimes be preferred for performance reasons. All of these return results as a `NamedTuple`.

- [`energy_forces(sys, calc)`](@ref)
- [`energy_forces!(f, sys, calc)`](@ref)
- [`energy_forces_virial(sys, calc)`](@ref)
- [`energy_forces_virial!(f, sys, calc)`](@ref)

To avoid writing too much boiler-plate code to support the full interface, see the [utilities section](utilities.md) of the docs. 


## Low-Level Interface 

All high-level functionality listed above can also be accessed via "low-level" calls with user-specifiable parameters through `calculate` methods. The low-level `calculate` interface follows the [Lux](https://lux.csail.mit.edu/stable/) model for parameters and state. This means that when calculations are performed with the `calculate` interface calculators **must act as immutable** structs that are passed 
to the `calculate` function together with `parameters` and `state`. All calculations then return an output and a state. Note we only require calculators **act** immutable but not to be technically immutable. For example the same calculator can implement the high-level interface and then mutate an internal state.

### General structure of the low-level interface 

The low level interface is built around a `calculate` function 
- [`calculate(property, sys, calc, ps, st; kwargs...)`](@ref)
where,
- `property` is the property to be computed e.g. `PotentialEnergy()`,
- `sys` is an system, 
- `calc` is a calculator, 
- `ps` either `nothing` or a nested `NamedTuple` storing the calculator parameters,
- `st` either `nothing` or a nested `NamedTuple` storing the calculator state
- `kwargs...` must be allowed but can be ignored; with caveats - see [Reserved Keyword Arguments](@ref keywordargs)

Irrespective of which property is required, the return type is *always* a `NamedTuple` with keys indicating the name of properties being computed. The content of this `NamedTuple` is not required to be restricted to the requested property (or, properties - more on this below). 

To manage parameters and state, `AtomsCalculators` provides prototypes that must be overloaded:
- [`get_state(calc)`](@ref)
- [`set_state!(calc)`](@ref)
- [`get_parameters(calc)`](@ref)
- [`set_parameters!(calc)`](@ref)
This functionality is somewhat separate from Lux' 
```julia
ps, st = Lux.setup(rng, model)
ps = LuxCore.initparameters(rng, model)
```
The difference is that `Lux.setup` initializes parameters, whereas, `*_state` and `*_parameters` is intended to read and write existing (already fitted) parameters. 
In addition, a calculator need not implement `LuxCore.initparams` and `LuxCore.initstate`, but it has the option to do so. 

### Molecular mechanics with the low-level interface 

The three basic properties to perform molecular mechanics simulations are energy, forces and virials, defined through
- [`Energy()`](@ref)
- [`Forces()`](@ref)
- [`Virial()`](@ref)

With these properties, the following calling conventions are analogous: 
- `calculate(Energy(), sys, calc, ps, st)` is analogous to `potential_energy(sys, calc)`
- `calculate(Forces(), sys, calc, ps, st)` is analogous to `forces(sys, calc)`
- `calculate(Virial(), sys, calc, ps, st)` is analogous to `virial(sys, calc)`

Energies, forces and virials can be obtained from the output `NamedTuple` via 
```julia 
out = calculate(Energy(), sys, calc, ps, st)
out.energy 
out = calculate(Forces(), sys, calc, ps, st)
out.forces
out = calculate(Virial(), sys, calc, ps, st)
out.virial 
```

### Multiple properties 

Multiple properties can be requested from a calculator by bundling them into a tuple. For example, 
```julia
efv = calculate( (Energy(), Forces(), Virial()), sys, calc, ps, st)
efv.energy 
efv.forces 
efv.virial 
```

### Extensions 

A calculator can extend the `calculate` interface without having to make a pull request to `AtomsCalculators`. For example, a site potential could supply the possibility of returning site energies, which could be implemented as follows. 
```julia
struct SiteEnergies end 
out = calculate(SiteEnergies(), sys, calc, ps, st)
out.siteenergies::AbstractVector{<: Unitful.Energy}
```
If such an extension could be of value to a broader developer or user base, then an issue and/or PR to AtomsCalculators would be very welcome. 


## [Reserved Keyword Arguments](@id keywordargs)

The following keyword arguments are used consistently throughout the AtomsBase / AtomsCalculators ecosystem. 

- `domain` : the domain over which to evaluate an energy, normally used for site potentials where partial energies can be evaluated. Calculators that do not provide this functionality may wish to throw an error is a partial energy is requested to avoid silent bugs. 
- `executor` : a label or type specifying how to execute the calcualtor (e.g. in serial, multi-threaded, distributed)
- `nlist` : a possibly precomputed neighbourlist
