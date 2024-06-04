
struct Energy end
struct Forces end
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
`calculate(propertie, sys, calc; kwargs...) -> NamedTuple`
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
`get_state(calc) -> NamedTuple`
"""
get_state(::Any) = NamedTuple()

"""
`get_parameters(calc) -> NamedTuple`
"""
get_parameters(::Any) = NamedTuple() 

"""
`set_state(calc, state) -> newcalc`
"""
function set_state end

"""
`set_state!(calc, state) -> state`
"""
function set_state! end

"""
`set_parameters(calc, parameters) -> newcalc`
"""
function set_parameters end 

"""
`set_parameters!(calc, parameters) -> calc`
"""
function set_parameters! end 

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
