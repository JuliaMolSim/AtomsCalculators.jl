
struct Energy end
struct Forces end
struct Virial end


"""
    potential_energy(system, calculator; kwargs...)

Calculate potential energy for the given system with the given calculator.

Return type is a number with units of energy.

All calculators accept all keywords, but are not requred to use any of them.
"""
function potential_energy end 


"""
    forces(system, calculator; kwargs...)

Calculate forces for the given system with the given calculator. See also `forces!`.

Return type is an array of vectors. `zero_forces` gives array of zero forces
and `promote_force_type` gives the type of the element in the array.
If you implement your own force calculator, you need to make sure these
calls give correct outputs for your calculator.

The default force array element is `SVector{3, Float64}` with unit `eV/Å`.

All calculators accept all keywords, but are not requred to use any of them.
"""
function forces end 

"""
    AtomsCalculators.forces!(f, system, calculator; kwargs...)

Calculate forces for the given system with the given calculator. See also `forces!`.

Forces are **added** to `f` array. You must remember to fill it with zeros

```julia
fill!(f, zero(AtomsCalculators.promote_force_type(system, calculator)))
```

All calculators accept all keywords, but are not requred to use any of them.
"""
function forces! end 

"""
    virial(system, calculator; kwargs...)

Calculate virial for the given system with the given calculator.

Return type is square matrix with unit of energy. In 3D case this is 3x3 matrix.

All calculators accept all keywords, but are not requred to use any of them.
"""
function virial end 


"""
    calculate(calculation_type, system, calculator; kwargs...)


Output is a `NamedTuple`, with keywords either `:energy`, `:forces` or `:virial`.

At this moment calculate call is equal to `potential_energy`, `forces` and `virial`
calls. But this can change in future, when extra properties are added.

See also `potential_energy`, `forces` and `virial`

All calculators accept all keywords, but are not requred to use any of them.

`calculation_type` can be:
- `AtomsCalculators.Energy()`   - for energy
- `AtomsCalculators.Forces()`   - for forces
- `AtomsCalculators.Virial()`   - for virial
"""
function calculate end


"""
    promote_force_type(system, calculator)

Returns force type for the given calculator and the system.

Default is `SVector{3, Float64}` with unit `eV/Å`.

If your calculator does not use the default typo, you need
to extend this.
"""
promote_force_type(::Any, ::Any) = SVector(1., 1., 1.) * u"eV/Å" |> typeof


"""
    zero_forces(system, calculator)

Returns zero forces array for the given calculator and the system. See also `promote_force_type`.

Default is `Vector` with `eltype``given by `promote_force_type`.

You need to make sure that `zero_forces` gives the correct return forces type for your calculator.
"""
zero_forces(system, calc) = zeros( promote_force_type(system, calc), length(system) )

## Define combinations from basic calls


"""
    energy_forces(system, calculator; kwargs...)

Combines energy and forces calls to a single call.

If you need both potential energy and forces, it is recommended to
use this call over individual calls, as some calculators have optimised
combination calls.

The output is `NamedTuple` with keywords `:energy` and `:forces` in that order.

All calculators accept all keywords, but are not requred to use any of them.

See also `potential_energy`, `forces`, `energy_forces!`, `energy_forces_virial` and `energy_forces_virial!`.
"""
function energy_forces(system, calculator; kwargs...)
    e = potential_energy(system, calculator; kwargs...)
    f = forces(system, calculator; kwargs...)
    return (;
        :energy => e,
        :forces => f
    )
end 


"""
    energy_forces!(f, system, calculator; kwargs...)

Same as `energy_forces` but does not allocate forces.

Forces are added, not overwritten. 

If you need both potential energy and forces, it is recommended to
use this call over individual calls, as some calculators have optimised
combination calls.

The output is `NamedTuple` with keywords `:energy` and `:forces` in that order.

All calculators accept all keywords, but are not requred to use any of them.

See also `potential_energy`, `forces`, `forces!` `energy_forces`, `energy_forces_virial` and `energy_forces_virial!`..
"""
function energy_forces!(f::AbstractVector, system, calculator; kwargs...)
    e = potential_energy(system, calculator; kwargs...)
    forces!(f, system, calculator; kwargs...)
    return (;
        :energy => e,
        :forces => f
    )
end 


"""
    energy_forces_virial(system, calculator; kwargs...)

Combines energy, forces and virial calls to a single call.

If you need potential energy, forces and virial, it is recommended to
use this call over individual calls, as some calculators have optimised
combination calls.

The output is `NamedTuple` with keywords `:energy`, `:forces` and `virial` in that order.

All calculators accept all keywords, but are not requred to use any of them.

See also `potential_energy`, `forces`, `energy_forces!`, `energy_forces` and `energy_forces_virial!`.
"""
function energy_forces_virial(system, calculator; kwargs...)
    ef = energy_forces(system, calculator; kwargs...)
    v = virial(system, calculator; kwargs...)
    return (;
        :energy => ef[:energy],
        :forces => ef[:forces],
        :virial => v
    )
end 


"""
    energy_forces_virial!(system, calculator; kwargs...)

Same as `energy_forces_virial` but does not allocate forces.

Forces are added, not overwritten.

If you need potential energy, forces and virial, it is recommended to
use this call over individual calls, as some calculators have optimised
combination calls.

The output is `NamedTuple` with keywords `:energy`, `:forces` and `virial` in that order.

All calculators accept all keywords, but are not requred to use any of them.

See also `potential_energy`, `forces`, `energy_forces!`, `energy_forces` and `energy_forces_virial`.
"""
function energy_forces_virial!(f::AbstractVector, system, calculator; kwargs...)
    ef = energy_forces!(f, system, calculator; kwargs)
    v = virial(system, calculator; kwargs...)
    return (;
        :energy => ef[:energy],
        :forces => ef[:forces],
        :virial => v
    )
end 
