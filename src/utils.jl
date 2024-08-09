## Macros to help implement calculators


"""
    @generate_interface

Generate complementary function for given function expression.
This is mean to help defining the interface, so that you only need
to define one of the interface methods for a given type of calculation
(energy, forces, virial).

# Example

Generate `forces!` and `calculate(AtomsCalculators.Forces(), ...)` calls from `forces` definition

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::MyType; kwargs...)
    #definition here
end
```

Generate `forces` and  `calculate(AtomsCalculators.Forces(), ...)` calls from `forces!` definition

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::MyOtherType; kwargs...)
    #definition here
end
```

Generate `AtomsCalculators.potential_energy` call from `AtomsCalculators.calculate` call.

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(::AtomsCalculators.Energy(), system, calculator::MyType; kwargs...)
    #definition here
end
```
"""
macro generate_interface(expr)
    type = nothing
    try
        type = determine_type_calculation(expr)
    catch _
        error("Possible typo (or other issue) in function definition. Could not determine the type of calculation (energy, forces or virial...).")
    end
    
    calculator_type = nothing
    try 
        calculator_type = get_calculator_type(expr, type)
    catch _
        error("Possible typo (or other issue) in function definition. Could not determine the calculators type.")
    end
    q = Expr(:nothing)
    if type[:calculator]
        if type[:type] == :Energy
            q = generate_potential_energy( calculator_type )
        elseif type[:type] == :Forces
            q = generate_forces_from_calculator( calculator_type )
        elseif type[:type] == :Virial
            q = generate_virial( calculator_type )
        end
    else
        if type[:type] == :potential_energy
            q = generate_calculator_energy( calculator_type )
        elseif type[:type] == :forces
            q1 = generate_nonallocating_forces( calculator_type )
            q2 = generate_calculator_forces( calculator_type )
            q = quote
                $q1
                $q2
            end
        elseif type[:type] == :forces!
            q1 = generate_allocating_forces( calculator_type )
            q2 = generate_calculator_forces( calculator_type )
            q = quote
                $q1
                $q2
            end
        elseif type[:type] == :virial
            q = generate_calculator_virial( calculator_type )
        end
    end
    ex = quote
        $expr
        $q
    end
    # We need to excape macro hygiene to get correct type information
    return esc(ex)
end


## Helper functions for macros

# Determine calculation type
function determine_type_calculation(expr)
    # Definition should start with something like:
    #  function AtomsCalculators.forces(system, calculator::MyType; kwargs...)
    # meaning that:
    # expr.head = :function
    # expr.args[1] = :(AtomsCalculators.forces(system, calculator::MyType; kwargs...))
    # expr.args[1].head = :call
    # expr.args[1].args[1] = :(AtomsCalculators.potential_energy)
    # expr.args[1].args[1].head = :.
    # expr.args[1].args[1].args[1] = :AtomsCalculators
    # the above can change based on how AtomsCalculators is imported
    # e.g.  using AtomsCalculators as AC, leads to value :AC
    # so don't test this
    # expr.args[1].args[1].args[2] = :forces   # or some of the others.
    # But the call can be also
    # function SomePkg.AtomsCalculators.forces(....)
    # then it would be 3rd argument, so using "end" is the best option.
    #
    # for calculator interface the calculation type is defined 
    # in expr.args[1].args[3] that should be :Energy, :Forces, or :Virial
    if expr.args[1].args[1].head != :.
        error("function definition is not correct")
    end
    type_of_calculation = expr.args[1].args[1].args[end].value
    if type_of_calculation in [:potential_energy, :forces, :forces!, :virial]
        return (;
            :type => type_of_calculation,
            :calculator => false
        )
    elseif type_of_calculation == :calculate # calculator interface -> find calc type too
        # Need to have definition of AtomsCalculators.Energy() etc.
        if expr.args[1].args[3].args[end].args[end].value in [:Energy, :Forces, :Virial]
            return (;
                :type => expr.args[1].args[3].args[end].args[end].value,
                :calculator => true
            )
        end
    else
        return error("typeof calculation is not known")
    end
end

function check_for_keywords(expr)
    return any( [ Symbol("...") == x.head  for x in expr.args[1].args[2].args ] )
end

function get_calculator_type(expr, type)
    if type[:type] in [:Energy, :Forces, :Virial]
        return expr.args[1].args[end - 2].args[2]
    else
        return expr.args[1].args[end].args[2]
    end
end


## Functions to generate expressions

# Generate low level calls from high-level ones.
# ----------------------------------------------
# calculate call generated from the high-level call return empty state.

function generate_calculator_energy(calc_type)
    q = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Energy, system,
                                            calculator::$calc_type,
                                            parameters=nothing,
                                            state=nothing;
                                            kwargs...)
            e = AtomsCalculators.potential_energy(system, calculator; kwargs...)
            return ( energy = e, state = nothing )
        end
    end
    return q
end

function generate_calculator_forces(calc_type)
    q = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Forces, system,
                                            calculator::$calc_type,
                                            parameters=nothing,
                                            state=nothing;
                                            kwargs...)
            f = AtomsCalculators.forces(system, calculator; kwargs...)
            return ( forces = f, state = nothing )
        end
    end
    return q
end

function generate_calculator_virial(calc_type)
    q = quote 
        function AtomsCalculators.calculate(::AtomsCalculators.Virial, system,
                                            calculator::$calc_type,
                                            parameters=nothing,
                                            state=nothing;
                                            kwargs...)
            v = AtomsCalculators.virial(system, calculator; kwargs...)
            return ( virial = v, state = nothing)
        end
    end
    return q
end


# Generate high level calls from low-level ones.
# -----------------------------------------------
# High level calls use the low level one with default parameters and state.

function generate_potential_energy(calc_type)
    q = quote 
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            e = AtomsCalculators.calculate(AtomsCalculators.Energy(), system, calculator,
                                           nothing, nothing; kwargs...)
            return e[:energy]
        end
    end
    return q
end

function generate_virial(calc_type)
    q = quote
        function AtomsCalculators.virial(system, calculator::$calc_type; kwargs...)
            v = AtomsCalculators.calculate(AtomsCalculators.Virial(), system, calculator,
                                           nothing, nothing; kwargs...)
            return v[:virial]
        end
    end
    return q
end

function generate_allocating_forces(calc_type)
    q = quote
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            AtomsCalculators.forces!(F, system, calculator; kwargs...)
            return F
        end
    end
    return q
end

function generate_nonallocating_forces(calc_type)
    q = quote
            function AtomsCalculators.forces!(F, system, calculator::$calc_type; kwargs...)
            @assert length(F) == length(system)
            F .+= AtomsCalculators.forces(system, calculator; kwargs...)
            return F
        end
    end
    return q
end

function generate_forces_from_calculator(calc_type)
    q1 = generate_only_forces_from_calculator(calc_type)
    q2 = generate_nonallocating_forces(calc_type)
    return quote
        $q1
        $q2
    end
end


function generate_only_forces_from_calculator(calc_type)
    q = quote 
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            f = AtomsCalculators.calculate(AtomsCalculators.Forces(), system, calculator,
                                           nothing, nothing; kwargs...)
            return f[:forces]
        end
    end
    return q
end

function generate_energy_from_energy_forces(calc_type)
    q = quote 
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            e = AtomsCalculators.energy_forces( system, calculator; kwargs...)
            return e[:energy]
        end
    end
    return q
end

function generate_energy_from_energy_forces_virial(calc_type)
    q = quote 
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            e = AtomsCalculators.energy_forces_virial( system, calculator; kwargs...)
            return e[:energy]
        end
    end
    return q
end

function generate_energy_from_energy_forces!(calc_type)
    q = quote
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            res = AtomsCalculators.energy_forces!(F, system, calculator; kwargs...)
            return res[:energy]
        end
    end
    return q
end

function generate_energy_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            res = AtomsCalculators.energy_forces_virial!(F, system, calculator; kwargs...)
            return res[:energy]
        end
    end
    return q
end


function generate_forces_from_energy_forces(calc_type)
    q = quote 
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            f = AtomsCalculators.energy_forces( system, calculator; kwargs...)
            return f[:forces]
        end
    end
    return q
end

function generate_forces_from_energy_forces_virial(calc_type)
    q = quote 
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            f = AtomsCalculators.energy_forces_virial( system, calculator; kwargs...)
            return f[:forces]
        end
    end
    return q
end

function generate_allocating_forces_from_energy_forces!(calc_type)
    q = quote
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            AtomsCalculators.energy_forces!(F, system, calculator; kwargs...)
            return F
        end
    end
    return q
end

function generate_allocating_forces_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            AtomsCalculators.energy_forces_virial!(F, system, calculator; kwargs...)
            return F
        end
    end
    return q
end


function generate_virial_from_energy_forces_virial(calc_type)
    q = quote 
        function AtomsCalculators.virial(system, calculator::$calc_type; kwargs...)
            res = AtomsCalculators.energy_forces_virial( system, calculator; kwargs...)
            return res[:virial]
        end
    end
    return q
end


function generate_virial_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.virial(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            res = AtomsCalculators.energy_forces_virial!(F, system, calculator; kwargs...)
            return res[:virial]
        end
    end
    return q
end


function generate_energy_forces_from_energy_forces!(calc_type)
    q = quote
        function AtomsCalculators.energy_forces(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            tmp = AtomsCalculators.energy_forces!(F, system, calculator; kwargs...)
            return tmp
        end
    end
    return q
end

function generate_energy_forces_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.energy_forces(system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            tmp = AtomsCalculators.energy_forces_virial!(F, system, calculator; kwargs...)
            return tmp
        end
    end
    return q
end

function generate_nonalloc_energy_forces_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.energy_forces!(f::AbstractVector, system, calculator::$calc_type; kwargs...)
            tmp = AtomsCalculators.energy_forces_virial!(f, system, calculator; kwargs...)
            return tmp
        end
    end
    return q
end


function generate_energy_forces_from_energy_forces_virial(calc_type)
    q = quote
        function AtomsCalculators.energy_forces(system, calculator::$calc_type; kwargs...)
            tmp = AtomsCalculators.energy_forces_virial(system, calculator; kwargs...)
            return tmp
        end
    end
    return q
end



function generate_calculate_energy_forces_virial_from_energy_forces_virial(calc_type)
    q = quote
        function AtomsCalculators.calculate( ::Tuple{Energy,Forces,Virial}, system, calculator::$calc_type; kwargs...)
            tmp = AtomsCalculators.energy_forces_virial(system, calculator; kwargs...)
            return (tmp..., state=nothing) 
        end
    end
    return q
end

function generate_calculate_energy_forces_from_energy_forces(calc_type)
    q = quote
        function AtomsCalculators.calculate( ::Tuple{Energy,Forces}, system, calculator::$calc_type; kwargs...)
            tmp = AtomsCalculators.energy_forces(system, calculator; kwargs...)
            return (tmp..., state=nothing)
        end
    end
    return q
end

function generate_nonalloc_forces_from_energy_forces!(calc_type)
    q = quote
        function AtomsCalculators.forces!(F, system, calculator::$calc_type; kwargs...)
            tmp = AtomsCalculators.energy_forces!(F, system, calculator; kwargs...)
            return tmp[:forces]
        end
    end
    return q
end


function generate_energy_forces_virial_from_energy_forces_virial!(calc_type)
    q = quote
        function AtomsCalculators.energy_forces_virial( system, calculator::$calc_type; kwargs...)
            F = AtomsCalculators.zero_forces(system, calculator) 
            tmp = AtomsCalculators.energy_forces_virial!(F, system, calculator; kwargs...)
            return tmp
        end
    end
    return q
end



## New macro


"""
    implementation_status(calc_type::Type; supertypes=true)

Checks what parts of AtomsCalculators interface has been implemented by given calculator.

Returns a `Dict{Symbol,bool}` where true means implemented part.

Keyword `supertypes=true` can be given to accept supertype implementations.
This currently applies only to combination call checks. 
"""
function implementation_status(calc_type::Type; supertypes=true)
    status = Dict{Symbol, Bool}()
    status[:calculate_energy] = hasmethod(calculate, Tuple{Energy, AtomsBase.AbstractSystem, calc_type, Nothing, Nothing}, (:random_kwarg21312, ))
    status[:calculate_forces] = hasmethod(calculate, Tuple{Forces, AtomsBase.AbstractSystem, calc_type, Nothing, Nothing}, (:random_kwarg21312, ))
    status[:calculate_virial] = hasmethod(calculate, Tuple{Virial, AtomsBase.AbstractSystem, calc_type, Nothing, Nothing}, (:random_kwarg21312, ))

    status[:potential_energy] = hasmethod(potential_energy, Tuple{AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    status[:forces] = hasmethod(forces, Tuple{AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    status[:virial] = hasmethod(virial, Tuple{AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))

    status[:forces!] = hasmethod(forces!, Tuple{AbstractVector, AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))

    # Following functions have default implementations, so we need to distinguish them out
    tmp1 = hasmethod(energy_forces, Tuple{AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    tmp = methodswith(calc_type, energy_forces; supertypes=supertypes)
    tmp2 = length(tmp) > 0 ? true : false
    status[:energy_forces] = tmp1 && tmp2 ? true : false

    tmp1 = hasmethod(energy_forces_virial, Tuple{AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    tmp = methodswith(calc_type, energy_forces_virial; supertypes=supertypes)
    tmp2 = length(tmp) > 0 ? true : false
    status[:energy_forces_virial] = tmp1 && tmp2 ? true : false

    tmp1 = hasmethod(energy_forces!, Tuple{AbstractVector, AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    tmp = methodswith(calc_type, energy_forces!; supertypes=supertypes)
    tmp2 = length(tmp) > 0 ? true : false
    status[:energy_forces!] = tmp1 && tmp2 ? true : false

    tmp1 = hasmethod(energy_forces_virial!, Tuple{AbstractVector, AtomsBase.AbstractSystem, calc_type}, (:random_kwarg21312, ))
    tmp = methodswith(calc_type, energy_forces_virial!; supertypes=supertypes)
    tmp2 = length(tmp) > 0 ? true : false
    status[:energy_forces_virial!] = tmp1 && tmp2 ? true : false

    return status
end



"""
    complete_interface(calc_type::Type)

This will implement missing parts of AtomsCalculators interface for given calculator type.

Function calls `AtomsCalculators.implementation_status` to see what has been implemented,
and adds missing parts.

There is no restrictions on where to call this. You can call it from different or module or package.
But, the recommendation is that calculator implementer calls this after implementing
something for AtomsCalculators interface.

`AtomsCalculators` needs to be in scope for this function to work.
"""
function complete_interface(calc_type::Type)
    status = implementation_status(calc_type)

    if all( x-> !x, values(status) )
        @warn "$calc_type has no detected AtomsCalculators interface implemented"
        return nothing
    end

    out = []

    # Generate only energy calculations
    if status[:potential_energy] ||  status[:calculate_energy]
        if status[:potential_energy] && ! status[:calculate_energy]
            tmp = generate_calculator_energy(calc_type)
            push!(out, tmp)
        elseif ! status[:potential_energy] && status[:calculate_energy]
            tmp = generate_potential_energy(calc_type)
            push!(out, tmp)
        end
    elseif status[:energy_forces]
        tmp = generate_energy_from_energy_forces(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_energy(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces_virial]
        tmp = generate_energy_from_energy_forces_virial(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_energy(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces!]
        tmp = generate_energy_from_energy_forces!(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_energy(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces_virial!]
        tmp = generate_energy_from_energy_forces_virial!(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_energy(calc_type)
        push!(out, tmp)
    end


    # Genrate only force calls
    if status[:forces] ||  status[:calculate_forces]
        if status[:forces] && ! status[:calculate_forces]
            tmp = generate_calculator_forces(calc_type)
            push!(out, tmp)
        elseif ! status[:forces] && status[:calculate_forces]
            tmp = generate_only_forces_from_calculator(calc_type)
            push!(out, tmp)
        end
    elseif status[:energy_forces]
        tmp = generate_forces_from_energy_forces(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_forces(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces_virial]
        tmp = generate_forces_from_energy_forces_virial(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_forces(calc_type)
        push!(out, tmp)
    elseif status[:forces!]
        tmp = generate_allocating_forces(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_forces(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces!]
        tmp = generate_allocating_forces_from_energy_forces!(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_forces(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces_virial!]
        tmp = generate_allocating_forces_from_energy_forces_virial!(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_forces(calc_type)
        push!(out, tmp)
    end

    # Nonallocating force calls
    if ! status[:forces!] && (status[:energy_forces!] ||  status[:energy_forces_virial!])
        tmp = generate_nonalloc_forces_from_energy_forces!(calc_type)
        push!(out, tmp)
    elseif ! status[:forces!] &&
            (status[:forces] ||  status[:calculate_forces] || status[:energy_forces] ||  status[:energy_forces_virial])
        tmp = generate_nonallocating_forces(calc_type)
        push!(out, tmp)
    end

    # Generate only virial calls
    if status[:virial] ||  status[:calculate_virial]
        if status[:virial] && ! status[:calculate_virial]
            tmp = generate_calculator_virial(calc_type)
            push!(out, tmp)
        elseif ! status[:virial] && status[:calculate_virial]
            tmp = generate_virial(calc_type)
            push!(out, tmp)
        end
    elseif status[:energy_forces_virial]
        tmp = generate_virial_from_energy_forces_virial(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_virial(calc_type)
        push!(out, tmp)
    elseif status[:energy_forces_virial!]
        tmp = generate_virial_from_energy_forces_virial!(calc_type)
        push!(out, tmp)
        tmp = generate_calculator_virial(calc_type)
        push!(out, tmp)
    end

    # Combination calls
    if ! status[:energy_forces] && status[:energy_forces!]
        tmp = generate_energy_forces_from_energy_forces!(calc_type)
        push!(out, tmp)
    elseif ! status[:energy_forces] && status[:energy_forces_virial]
        tmp = generate_energy_forces_from_energy_forces_virial(calc_type)
        push!(out, tmp)
    elseif ! status[:energy_forces] && status[:energy_forces_virial!]
        tmp = generate_energy_forces_from_energy_forces_virial!(calc_type)
        push!(out, tmp)
    end

    if ! status[:energy_forces!] &&  status[:energy_forces_virial!]
        tmp = generate_nonalloc_energy_forces_from_energy_forces_virial!(calc_type)
        push!(out, tmp)
    end

    if ! status[:energy_forces_virial] && status[:energy_forces_virial!]
        tmp = generate_energy_forces_virial_from_energy_forces_virial!(calc_type)
        push!(out, tmp)

    end

    if ! status[:calculate_energy] && ! status[:calculate_forces] &&
            (  status[:energy_forces] || status[:energy_forces!] ||
            status[:energy_forces_virial] || status[:energy_forces!] || status[:energy_forces_virial!] )
        # if this is true then optimized energy_forces exists
        tmp = generate_calculate_energy_forces_from_energy_forces(calc_type)
        push!(out, tmp)
    end

    if ! status[:calculate_energy] && ! status[:calculate_forces] && ! status[:calculate_virial] &&
            ( status[:energy_forces_virial] || status[:energy_forces_virial!] )
        # if this is true then optimized energy_forces_virial exists
        tmp = generate_calculate_energy_forces_virial_from_energy_forces_virial(calc_type)
        push!(out, tmp)
    end

    if length(out) > 0
        eval( Expr(:block, out...) )
    end
    return nothing
end
