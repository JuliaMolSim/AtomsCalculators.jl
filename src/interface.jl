
struct Energy end
struct Forces end
struct Virial end

function potential_energy end 

function forces end 

function forces! end 

function virial end 

function calculate end

promote_force_type(::Any, ::Any) = SVector(1., 1., 1.) * u"eV/Å" |> typeof

zero_forces(system, calc) = zeros( promote_force_type(system, calc), length(system) )

get_state(::Any) = missing
get_parameters(::Any) = missing

set_state(::Any, ::Any) = nothing
set_parameters(::Any, ::Any) = nothing

## Define combinations from basic calls

function energy_forces(system, calculator; kwargs...)
    e = potential_energy(system, calculator; kwargs...)
    f = forces(system, calculator; kwargs...)
    return (;
        :energy => e,
        :forces => f
    )
end 

function energy_forces!(f::AbstractVector, system, calculator; kwargs...)
    e = potential_energy(system, calculator; kwargs...)
    forces!(f, system, calculator; kwargs...)
    return (;
        :energy => e,
        :forces => f
    )
end 

function energy_forces_virial(system, calculator; kwargs...)
    ef = energy_forces(system, calculator; kwargs...)
    v = virial(system, calculator; kwargs...)
    return (;
        :energy => ef[:energy],
        :forces => ef[:forces],
        :virial => v
    )
end 

function energy_forces_virial!(f::AbstractVector, system, calculator; kwargs...)
    ef = energy_forces!(f, system, calculator; kwargs)
    v = virial(system, calculator; kwargs...)
    return (;
        :energy => ef[:energy],
        :forces => ef[:forces],
        :virial => v
    )
end 
