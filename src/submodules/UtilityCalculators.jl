module UntilityCalculators
    
using ..AtomsCalculators
using AtomsBase

export CombinationCalculator
export SubSystemCalculator

export generate_keywords


"""
    SubSystemCalculator{T, TC}

Submits subsystem to given calculator.

The purpose of this calculator is that you can split system to smaller
system that can then be calculated with e.g. with different methods.
One possible use case here is QM/MM calculations where you can split
QM system out.

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
        f[i] += val
    end
    return f
end

AtomsCalculators.@generate_interface function AtomsCalculators.virial(sys, calc::SubSystemCalculator; kwargs...)
    sub_sys = _generate_subsys(sys, calc)
    return AtomsCalculators.virial(sub_sys, calc.calculator; kwargs...)
end


## Combination Calculator

"""
    CombinationCalculator{N}

You can combine several calculators to one calculator with this.
Giving keyword argument `multithreading=true` toggles on parallel execution
calculators.

Other use case is editing keywords that are passed on the calculators.
E.g. you can generate new keyword argument that is then passed to all calculators.
This allows you to share e.g. a pairlist between calculators.

To control what keywords are passed you need to extend `generate_keywords` function.


# Fields

- calculators::NTuple{N,Any}  : NTuple that holds calculators
- multithreading::Bool        : determines where calculators are executed in parallel or not

# Creation

```julia
CombinationCalculator( calc1, calc2, ...; multithreading=false)
```

"""
struct CombinationCalculator{N}
    calculators::NTuple{N,Any}
    multithreading::Bool
    function CombinationCalculator(calculators...; multithreading=false)

        new{length(calculators)}(calculators, multithreading)
    end
end

function Base.show(io::IO, ::MIME"text/plain", calc::CombinationCalculator)
    print(io, "CombinationCalculator - ", length(calc) , " calculators")
end

"""
    generate_keywords

This function is called when `CombinationCalculator` is used.

Default implementation will only pass keywords forward.

The call type is AtomsBase system first then all calculators and kwargs.
This will allow you to extend based on calculator type.

# Example

```julia
function AtomsCalculators.UntilityCalculators.generate_keywords(sys, pp1::PairPotential, pp2::PairPotential; kwargs...)
    if cutoff_radius(pp1) ≈ cutoff_radius(pp2)
        nlist = PairList(sys, cutoff_radius(pp1))
        return (; :nlist => nlist, kwargs...)
    else
        return kwargs
    end
end
```

will check that PairPotentials have same cutoff radius.
Then calculates pairlist and passes it forward as a keyword. 
"""
generate_keywords(sys, calculators...; kwargs...) = kwargs

Base.length(cc::CombinationCalculator) = length(cc.calculators)

Base.getindex(cc::CombinationCalculator, i) = cc.calculators[i]
Base.lastindex(cc::CombinationCalculator) = length(cc)
Base.firstindex(cc::CombinationCalculator) = 1


AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = generate_keywords(sys, calc.calculators...; kwargs...)
    if calc.multithreading
        tmp = map(calc.calculators) do c
            Threads.@spawn AtomsCalculators.potential_energy(sys, c; new_kwargs...)
        end
        e = sum( x -> fetch(x),  tmp )
    else
        e = sum(calc.calculators) do c
            AtomsCalculators.potential_energy(sys, c; new_kwargs...)
        end
    end
    return e
end


function AtomsCalculators.forces(sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = generate_keywords(sys, calc.calculators...; kwargs...)
    if calc.multithreading
        tmp = map(calc.calculators) do c
            Threads.@spawn AtomsCalculators.forces(sys, c; new_kwargs...)
        end
        f = sum( x -> fetch(x),  tmp )
    else
        f = sum(calc.calculators) do c
            AtomsCalculators.forces(sys, c; new_kwargs...)
        end
    end
    return f
end


function AtomsCalculators.calculate( ::AtomsCalculators.Forces, sys, calc::CombinationCalculator; kwargs...)
    f = AtomsCalculators.forces(sys, calc; kwargs...)
    return (; :forces => f)
end


function AtomsCalculators.forces!(f, sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = generate_keywords(sys, calc.calculators...; kwargs...)

    # Non allocating forces is only truly non allocating when sequential
    foreach( calc.calculators ) do cal
        AtomsCalculators.forces!(f, sys, cal; new_kwargs...)
    end
    return f
end


AtomsCalculators.@generate_interface function AtomsCalculators.virial(sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = generate_keywords(sys, calc.calculators...; kwargs...)
    if calc.multithreading
        tmp = map(calc.calculators) do c
            Threads.@spawn AtomsCalculators.virial(sys, c; new_kwargs...)
        end
        v = sum( x -> fetch(x),  tmp )
    else
        v = sum(calc.calculators) do c
            AtomsCalculators.virial(sys, c; new_kwargs...)
        end
    end
    return v
end


end