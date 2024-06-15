
"""
`Energy` : a `calculate` property to calculate the potential energy
"""
struct Energy end

"""
`Forces` : a `calculate` property to calculate the forces
"""
struct Forces end

"""
`Virial` : a `calculate` property to calculate the virial 
"""
struct Virial end

"""
`potential_energy(sys, calc; kwargs...)::Unitful.Energy`
"""
function potential_energy end 

"""
`forces(sys, calc; kwargs...)::AbstractVector{SVector{D, Unitful.Force}}`
"""
function forces end 

"""
`forces(frc, sys, calc; kwargs...) -> frc`
"""
function forces! end 

"""
`virial(sys, calc; kwargs...)::SMatrix{3,3,<:Unitful.Energy}`
"""
function virial end 

"""
`calculate(properties, sys, calc; kwargs...) -> NamedTuple`
"""
function calculate end

"""
`energy_unit(calc)` : energy unit used by the calculator
"""
function energy_unit end 

"""
`length_unit(calc)` : length unit assumed and used by the calculator 
"""
function length_unit end 

"""
`force_unit(calc)` : force unit returned by the calculator
"""
force_unit(calc) = energy_unit(calc) / length_unit(calc)

"""
`_fltype(system)` : floating point type used by the calculator

This is an internal helper function and not considered part of the public API. 
"""
_fltype(system) = typeof(ustrip(position(system, 1)[1]))

"""
`promote_force_type(system, calc)` : force type (float type and unit) returned 
by the calculator
"""
function promote_force_type(system::AbstractSystem{D}, calc) where {D} 
    FT = typeof( one(_fltype(system)) * force_unit(calc) )
    return SVector{D, FT}
end

"""
`zero_forces(system, calc)` : allocate a zero forces array
"""
zero_forces(system, calc) = 
        zeros( promote_force_type(system, calc), length(system) )

"""
`zero_energy(system, calc)` : initialize a zero energy value 
"""
zero_energy(system, calc) = 
        zero(_fltype(system)) * energy_unit(calc)

"""
`zero_virial(system, calc)` : initialize a zero virial matrix 
"""         
zero_virial(system, calc) = 
        zero( SMatrix{3,3,typeof(zero_energy(system, calc))} )


"""
`get_state(calc) -> NamedTuple` or `ComponentArray`
"""
get_state(::Any) = NamedTuple()

"""
`get_parameters(calc) -> NamedTuple` or `ComponentArray`
"""
get_parameters(::Any) = NamedTuple() 

"""
`set_state!(calc, state) -> calc_new`

The returned `calc_new` may be a mutated `calc` or a new object. The caller 
should not assume that `calc_new` is the same object as `calc`. This allows 
for non-mutating implementations of `set_state!`.
"""
set_state!(calc, st) = calc 

"""
`set_parameters!(calc, parameters) -> calc_new`

The returned `calc_new` may be a mutated `calc` or a new object. The caller 
should not assume that `calc_new` is the same object as `calc`. This allows 
for non-mutating implementations of `set_parameters!`.
"""
set_parameters!(calc, ps) = calc

## Define combinations from basic calls

"""
`energy_forces(system, calculator; kwargs...) -> NamedTuple`
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
`energy_forces!(f, system, calculator; kwargs...) -> NamedTuple`
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
`energy_forces_virial(system, calculator; kwargs...) -> NamedTuple`
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
`energy_forces_virial!(f, system, calculator; kwargs...) -> NamedTuple`
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


function calculate(properties::Tuple, sys, calc, params=nothing, state=nothing; kwargs...)
    out = Dict{Symbol, Any}()
    out[:state] = state
    for property in properties
        tmp = calculate(property, sys, calc, params, out[:state]; kwargs...)
        for (k,v) in pairs(tmp)
            out[k] = v
        end
    end
    return NamedTuple(out)
end
