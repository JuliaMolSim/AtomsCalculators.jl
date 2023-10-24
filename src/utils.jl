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
AtomsCalculators.@generate_interface function AtomsCalculators.forces(system, calculator::Main.MyType; kwargs...)
    #definition here
end
```

Generate `forces` and  `calculate(AtomsCalculators.Forces(), ...)` calls from `forces!` definition

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.forces!(f::AbstractVector, system, calculator::Main.MyOtherType; kwargs...)
    #definition here
end
```

Generate `AtomsCalculators.potential_energy` call from `AtomsCalculators.calculate` call.

```julia
AtomsCalculators.@generate_interface function AtomsCalculators.calculate(::AtomsCalculators.Energy(), system, calculator::Main.MyType; kwargs...)
    #definition here
end
```

# Note

When using this macro, you need to define your calculator type completely - `MyPkg.MyType` is fine
but `MyType` is not!

"""
macro generate_interface(expr)
    type = nothing
    try
        type = determine_type_calculation(expr)
    catch _
        error("Could not determine the type of calculation (energy, forces or virial...)")
    end
    
    calculator_type = nothing
    try 
        calculator_type = get_calculator_type(expr)
    catch _
        error("Could not determine calculators type")
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
    return ex
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
        if expr.args[1].args[3].args[1].args[2].value in [:Energy, :Forces, :Virial]
            return (;
                :type => expr.args[1].args[3].args[1].args[2].value,
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

function get_calculator_type(expr)
    return expr.args[1].args[end].args[2]
end


## Functions to generate expressions

function generate_calculator_energy(calc_type)
    q = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Energy, system, calculator::$calc_type; kwargs...)
            e = AtomsCalculators.potential_energy(system, calculator; kwargs...)
            return ( energy = e, )
        end
    end
    return q
end

function generate_calculator_forces(calc_type)
    q = quote
        function AtomsCalculators.calculate(::AtomsCalculators.Forces, system, calculator::$calc_type; kwargs...)
            f = AtomsCalculators.forces(system, calculator; kwargs...)
            return ( forces = f, )
        end
    end
    return q
end

function generate_calculator_virial(calc_type)
    q = quote 
        function AtomsCalculators.calculate(::AtomsCalculators.Virial, system, calculator::$calc_type; kwargs...)
            v = AtomsCalculators.virial(system, calculator; kwargs...)
            return ( virial = v, )
        end
    end
    return q
end


function generate_potential_energy(calc_type)
    q = quote 
        function AtomsCalculators.potential_energy(system, calculator::$calc_type; kwargs...)
            e = AtomsCalculators.calculate(AtomsCalculators.Energy(), system, calculator; kwargs...)
            return e[:energy]
        end
    end
    return q
end

function generate_virial(calc_type)
    q = quote
        function AtomsCalculators.virial(system, calculator::$calc_type; kwargs...)
            v = AtomsCalculators.calculate(AtomsCalculators.Virial(), system, calculator; kwargs...)
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
            F .= AtomsCalculators.forces(system, calculator; kwargs...)
            return F
        end
    end
    return q
end

function generate_forces_from_calculator(calc_type)
    q1 = quote 
        function AtomsCalculators.forces(system, calculator::$calc_type; kwargs...)
            f = AtomsCalculators.calculate(AtomsCalculators.Forces(), system, calculator; kwargs...)
            return f[:forces]
        end
    end
    q2 = generate_nonallocating_forces(calc_type)
    return quote
        $q1
        $q2
    end
end