module UtilityCalculators
    
using ..AtomsCalculators
using AtomsBase

export CombinationCalculator
export ReportingCalculator
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
mutable struct SubSystemCalculator{T, TC} # Mutable struct so that calculator can mutate inself
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
mutable struct CombinationCalculator{N, T} # Mutable struct so that calculators can mutate themself
    calculators::NTuple{N,Any}
    multithreading::Bool
    keywords::T
    function CombinationCalculator(calculators...; multithreading=false, keyword_generator=nothing)
        kgen = something(keyword_generator, generate_keywords)
        new{length(calculators), typeof(kgen)}(calculators, multithreading, kgen)
    end
end

function Base.show(io::IO, ::MIME"text/plain", calc::CombinationCalculator)
    print(io, "CombinationCalculator - ", length(calc) , " calculators")
end

Base.length(cc::CombinationCalculator) = length(cc.calculators)

Base.getindex(cc::CombinationCalculator, i) = cc.calculators[i]
Base.lastindex(cc::CombinationCalculator) = length(cc)
Base.firstindex(cc::CombinationCalculator) = 1


AtomsCalculators.@generate_interface function AtomsCalculators.potential_energy(sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = calc.keywords(sys, calc.calculators...; kwargs...)
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
    new_kwargs = calc.keywords(sys, calc.calculators...; kwargs...)
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
    new_kwargs = calc.keywords(sys, calc.calculators...; kwargs...)

    # Non allocating forces is only truly non allocating when sequential
    foreach( calc.calculators ) do cal
        AtomsCalculators.forces!(f, sys, cal; new_kwargs...)
    end
    return f
end


AtomsCalculators.@generate_interface function AtomsCalculators.virial(sys, calc::CombinationCalculator; kwargs...)
    new_kwargs = calc.keywords(sys, calc.calculators...; kwargs...)
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


##

"""
    generate_message(sys, calculator, calc_result; kwargs...) = calc_result

This is the default function that is called when `ReportingCalculator` collects
a message. Extending this allows you to control what is reported.

This function is ment to allow setting of global stetting. If you want to
set reporting function for an individual case, give `ReportingCalculator` keyword
`message_function=my_report` where `my_report` is function that returns your message.

If function returns `nothing` the message is ignored. You can use this to control
when message is sent. 
"""
generate_message(sys, calculator, calc_result; kwargs...) = calc_result


"""
    ReportingCalculator{T, TC, TF}

`ReportingCalculator` collects information during calculation
and sent it to a `Channel` that can be read.

# Fields

- `calculator::T`          : caculator used in calculations
- `channel::Channel{TC}`   : `Channel` where message is put
- `message::TF`            : function that generates the message

# Creation

```julia
rcalc = ReportingCalculator(calculator, Channel(32))
rcalc = ReportingCalculator(calculator, Channel(32); message_function=my_message_function)
```

When `message_function` is omitted, `generate_message` function is used. See it for more details on how to control generated messages.

You can access the channel by calling calculator directly with `fetch` or `take!`.
"""
mutable struct ReportingCalculator{T, TC, TF}
    calculator::T
    channel::Channel{TC}
    message::TF
    function ReportingCalculator(
        calc, 
        channel::Channel; 
        message_function=nothing
    )
        message = something(message_function, generate_message)
        new{typeof(calc), eltype(channel), typeof(message)}(calc, channel, message)
    end
end


function Base.show(io::IO, ::MIME"text/plain", calc::ReportingCalculator)
    print(io, "ReportingCalculator")
end

Base.fetch(rcalc::ReportingCalculator) = fetch(rcalc.channel)
Base.take!(rcalc::ReportingCalculator) = take!(rcalc.channel)

AtomsCalculators.zero_forces(sys, calc::ReportingCalculator) = AtomsCalculators.zero_forces(sys, calc.calculator)
AtomsCalculators.promote_force_type(sys, calc::ReportingCalculator) = AtomsCalculators.promote_force_type(sys, calc.calculator)


function AtomsCalculators.potential_energy(
    sys, 
    calc::ReportingCalculator; 
    kwargs...
)
    e = AtomsCalculators.potential_energy(sys, calc.calculator; kwargs...)
    mess = calc.message(sys, calc.calculator, e; kwargs...)
    if ! isnothing(mess)
        put!(calc.channel, mess)
    end
    return e
end


function AtomsCalculators.virial(
    sys, 
    calc::ReportingCalculator; 
    kwargs...
)
    v = AtomsCalculators.virial(sys, calc.calculator; kwargs...)
    mess = calc.message(sys, calc.calculator, v; kwargs...)
    if ! isnothing(mess)
        put!(calc.channel, mess)
    end
    return v
end


function AtomsCalculators.forces(
    sys, 
    calc::ReportingCalculator; 
    kwargs...
)
    f = AtomsCalculators.forces(sys, calc.calculator; kwargs...)
    mess = calc.message(sys, calc.calculator, f; kwargs...)
    if ! isnothing(mess)
        put!(calc.channel, mess)
    end
    return f
end


function AtomsCalculators.forces!(
    f,
    sys, 
    calc::ReportingCalculator; 
    kwargs...
)
    fout = AtomsCalculators.forces!(f, sys, calc.calculator; kwargs...)
    mess = calc.message(sys, calc.calculator, fout; kwargs...)
    if ! isnothing(mess)
        put!(calc.channel, mess)
    end
    return fout
end


function AtomsCalculators.calculate(
    calc_method::Union{
        AtomsCalculators.Energy,
        AtomsCalculators.Forces,
        AtomsCalculators.Virial
    },
    sys, 
    calc::ReportingCalculator; 
    kwargs...
)
    tmp = AtomsCalculators.calculate(calc_method, sys, calc.calculator; kwargs...)
    mess = calc.message(sys, calc.calculator, tmp; kwargs...)
    if ! isnothing(mess)
        put!(calc.channel, mess)
    end
    return tmp
end


end