
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
    oldname = nothing
    try
        # determine either "force" or "force!"
        # or fail if not present at all
        oldname = "$(expr.args[1].args[1])"
    catch _
        error("Not valid input")
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

    if oldname[end] == '!'
        # generate "forces"
        length(expr.args[1].args) != 5 && error("Number of inputs does not match the call")
        name = oldname[begin:end-1] 
        q = Meta.parse(
            "function $name(system, calculator::$calc_type; kwargs...)
                final_data = zeros( AtomsCalculators.promote_force_type(system, calculator), length(system) )
                $oldname(final_data, system, calculator; kwargs...)
                return final_data
            end"
        )  
    else
        # generate "forces!"
        length(expr.args[1].args) != 4 && error("Number of inputs does not match the call")
        name = oldname * "!"
        q = Meta.parse(
            "function $name(final_data::AbstractVector, system, calculator::$calc_type; kwargs...)
                @assert length(final_data) == length(system)
                final_data .= $oldname(system, calculator; kwargs...)
                return final_data
            end"
        )
    end
    return quote
        $expr
        $q
    end
end


## test functions to test interface


"""
    test_forces(sys, calculator; force_eltype::AbstractVector=default_force_eltype, kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
forces calculation.

To use this function create a `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`force_eltype` is given for `forces!` interface testing.
`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_forces(sys, calculator; force_eltype=nothing, kwargs...)
    @testset "Test forces for $(typeof(calculator))" begin
        ftype = something(
            force_eltype, 
            AtomsCalculators.promote_force_type(sys, calculator)
        )
        f = AtomsCalculators.forces(sys, calculator; kwargs...)
        @test typeof(f) <: AbstractVector
        @test eltype(f) <: AbstractVector
        @test length(f) == length(sys)
        T = (eltype ∘ eltype)( f )
        f_matrix = reinterpret(reshape, T, f)
        @test typeof(f_matrix) <: AbstractMatrix
        @test eltype(f_matrix) <: Number
        @test size(f_matrix) == (3, length(f))
        @test all( AtomsCalculators.forces(sys, calculator; dummy_kword659234=1, kwargs...) .≈ f )
        f_cpu_array = Array(f)  # Allow GPU output
        @test dimension(f_cpu_array[1][1]) == dimension(u"N")
        @test length(f_cpu_array[1]) == (length ∘ position)(sys,1)
        f_nonallocating = zeros(ftype, length(sys))
        AtomsCalculators.forces!(f_nonallocating, sys, calculator; kwargs...)
        @test all( f_nonallocating .≈ f  )
        AtomsCalculators.forces!(f_nonallocating, sys, calculator; dummy_kword659254=1, kwargs...)
        @test all( f_nonallocating .≈ f  )
    end
end


"""
    test_potential_energy(sys, calculator; kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
potential energy calculation.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_potential_energy(sys, calculator; kwargs...)
    @testset "Test potential_energy for $(typeof(calculator))" begin
        e = AtomsCalculators.potential_energy(sys, calculator; kwargs...)
        @test typeof(e) <: Number
        @test dimension(e) == dimension(u"J")
        e2 = AtomsCalculators.potential_energy(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test e ≈ e2
    end
end


"""
    test_virial(sys, calculator; kwargs...)

Test your calculator for AtomsCalculators interface. Passing test means that your
virial calculation.

To use this function create an `AtomsBase` system `sys` and a `calculator` for your
own calculator. Test function will then call the interface and performs checks
for the output and checks that random keywords are accepted in input. 

`kwargs` can be passed to the `calculator` for tuning during testing.

The calculator is expected to work without kwargs.
"""
function test_virial(sys, calculator; kwargs...)
    @testset "Test virial for $(typeof(calculator))" begin
        v = AtomsCalculators.virial(sys, calculator; kwargs...)
        @test typeof(v) <: AbstractMatrix
        @test eltype(v) <: Number
        v_cpu_array = Array(v) # Allow GPU arrays
        @test dimension(v_cpu_array[1,1]) == dimension(u"J")
        l = (length ∘ position)(sys,1) 
        @test size(v) == (l,l) # allow different dimensions than 3
        v2 = AtomsCalculators.virial(sys, calculator; dummy_kword6594254=1, kwargs...)
        @test all( v .≈ v2 )
    end
end
