module UntilityCalculators
    
using ..AtomsCalculators
using AtomsBase

export SubSystemCalculator


mutable struct SubSystemCalculator{T, TC}
    calculator::T
    subsys::TC
    function SubSystemCalculator(calc, subsys)
        @assert applicable(first, subsys) "subsys is not iterable"
        new{typeof(calc), typeof(subsys)}(calc, subsys)
    end
end

function Base.show(io::IO, ::MIME"text/plain", calc::SubSystemCalculator)
    print(io, "SubSystemCalculator - subsystem size = ", length(calc.subsys))
end

AtomsCalculators.zero_forces(sys, calc::SubSystemCalculator) = AtomsCalculators.zero_forces(sys, calc.calculator)
AtomsCalculators.promote_force_type(sys, calc::SubSystemCalculator) = AtomsCalculators.promote_force_type(sys, calc.calculator)


function _generate_subsys(sys, calc::SubSystemCalculator)
    @assert length(sys) >= length(calc.subsys)
    sub_sys = FlexibleSystem(
        sys[calc.subsys];
        [ k => sys[k] for k in keys(sys) ]...
    )
    return sub_sys
end


AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(sys, calc::SubSystemCalculator; kwargs...)
    sub_sys = _generate_subsys(sys, calc)
    return AtomsCalculators.potential_energy(sub_sys, calc.calculator; kwargs...)
end


AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f, sys, calc::SubSystemCalculator; kwargs...)
    @assert length(f) == length(sys)
    sub_sys = _generate_subsys(sys, calc)
    tmp_f = AtomsCalculators.zero_forces(sub_sys, calc)
    AtomsCalculators.forces!(tmp_f, sub_sys, calc.calculator; kwargs...)
    f[calc.subsys] .= tmp_f
    return f
end

AtomsCalculators.@generate_interface function AtomsCalculators.virial(sys, calc::SubSystemCalculator; kwargs...)
    sub_sys = _generate_subsys(sys, calc)
    return AtomsCalculators.virial(sub_sys, calc.calculator; kwargs...)
end

end