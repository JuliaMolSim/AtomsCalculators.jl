
struct Energy end
struct Force end
struct Virial end

function potential_energy end 

function forces end 

function forces! end 

function virial end 

promote_force_type(::Any, ::Any) = SVector(1., 1., 1.) * u"eV/Å" |> typeof

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


## Macro call to generate "forces!" from "forces" and viseversa


"""
    @generate_complement

Generate complementary function for given function expression.
This is intended to generate non-allocating force call from
allocating force call and viseversa.

# Example

Generate `forces!` call from `forces` definition

```julia
AtomsCalculators.@generate_complement function AtomsCalculators.forces(system, calculator::Main.MyType; kwargs...)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    return zeros(AtomsCalculators.default_force_eltype, length(system)) 
end
```

Generate `forces` call from `forces!` definition

```julia
AtomsCalculators.@generate_complement function AtomsCalculators.forces!(f::AbstractVector, system, calculator::Main.MyOtherType; kwargs...)
    @assert length(f) == length(system)
    # we can ignore kwargs... or use them to tune the calculation
    # or give extra information like pairlist

    # add your own definition
    for i in eachindex(f)
        f[i] = zero(AtomsCalculators.default_force_eltype)
    end

    return f
end
```
"""
macro generate_complement(expr)
    type_of_calculation = nothing
    try
        type_of_calculation = expr.args[1].args[1].args[2].value
        if !( type_of_calculation in [:calculator, :potential_energy, :forces, :forces!, :virial] )
            error("Not supported calculator type")
        end
    catch er
        @error "Error in solving calculator type"
        rethrow(er)
    end

    try
        # check that has kwargs... support
        has_kwargs = any( [ Symbol("...") == x.head  for x in expr.args[1].args[2].args ] )
        !has_kwargs && error()
    catch _
        error("Call does not catch kwargs...")
    end

    calc_type = nothing
    try
        # expr.args[1].args[4] for "forces"
        # and expr.args[1].args[5] for "forces!"
        # is calculator based on definition.
        # we can leave it to be the end now.
        # But this needs to change, if we allow extra arguments.
        calc_type = expr.args[1].args[end].args[2]
    catch _
        throw(error("Calculator does not have defined type"))
    end

    if type_of_calculation == :forces!
        # generate "forces"
        length(expr.args[1].args) != 5 && error("Number of inputs does not match the call")
        name = "AtomsCalculators." * String(type_of_calculation)[begin:end-1] 
        q = Meta.parse(
            "function $name(system, calculator::$calc_type; kwargs...)
                final_data = zeros( AtomsCalculators.promote_force_type(system, calculator), length(system) )
                AtomsCalculators.$type_of_calculation(final_data, system, calculator; kwargs...)
                return final_data
            end"
        )  
    elseif  type_of_calculation == :forces
        # generate "forces!"
        length(expr.args[1].args) != 4 && error("Number of inputs does not match the call")
        name = "AtomsCalculators." * String( type_of_calculation ) * "!"
        q = Meta.parse(
            "function $name(final_data::AbstractVector, system, calculator::$calc_type; kwargs...)
                @assert length(final_data) == length(system)
                final_data .= AtomsCalculators.$type_of_calculation(system, calculator; kwargs...)
                return final_data
            end"
        )
    end
    return quote
        $expr
        $q
    end
end


