module UntilityCalculators
    
using ..AtomsCalculators
using AtomsBase

export SubSystemCalculator


"""
    SubSystemCalculator{T, TC}

Submits subsystem to given calculator.

The structrure is mutable to allow mutable calculators.

# Fields
- `calculator::T`  :  calculator which is used for the subsystem calculation
- `subsys::TC`     :  definition of subsystem like array of indices - has to be iterable
"""
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
    sub_atoms = [ sys[i] for i in calc.subsys  ]
    sub_sys = FlexibleSystem(
        sub_atoms;
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
    #TODO this wont work for GPU Arrays
    for (i, val) in zip(calc.subsys, tmp_f)
        f[i] = val
    end
    return f
end

AtomsCalculators.@generate_interface function AtomsCalculators.virial(sys, calc::SubSystemCalculator; kwargs...)
    sub_sys = _generate_subsys(sys, calc)
    return AtomsCalculators.virial(sub_sys, calc.calculator; kwargs...)
end

end