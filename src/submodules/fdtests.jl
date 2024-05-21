
using Printf, StaticArrays, Unitful, AtomsBase
using LinearAlgebra: norm 
using AtomsBase: AbstractSystem, FastSystem, position, 
                 FlexibleSystem
using AtomsCalculators: potential_energy, forces

"""
Basic first-order finite-difference test for scalar F
```julia
fdtest(F, dF, x; h0 = 1.0, verbose=true)
```
- `F` is a scalar-valued function 
- `dF` is the gradient of `F`
- `x` is the point at which to test the gradient, it can be a `Number`, 
   `AbstractVector{<: Real}` or a `AbstractVector{SVector{D, T}}`.


"""
function fdtest(F, dF, x::AbstractVector{<: Real}; h0 = 1.0, verbose=true)
   E = F(x)
   dE = dF(x)
   errors = typeof(E)[]

   # loop through finite-difference step-lengths
   verbose && @printf("---------|----------- \n")
   verbose && @printf("    h    | error \n")
   verbose && @printf("---------|----------- \n")
   for p = 2:11
      h = 0.1^p
      dEh = copy(dE)
      for n = 1:length(dE)
         x[n] += h
         dEh[n] = (F(x) - E) / h
         x[n] -= h
      end
      push!(errors, norm(dE - dEh, Inf))
      verbose && @printf(" %1.1e | %4.2e  \n", h, errors[end])
   end
   verbose && @printf("---------|----------- \n")
   if minimum(errors) <= 1e-3 * maximum(errors)
      verbose && println("passed")
      return true
   else
      @warn("""It seems the finite-difference test has failed, which indicates
      that there is an inconsistency between the function and gradient
      evaluation. Please double-check this manually / visually. (It is
      also possible that the function being tested is poorly scaled.)""")
      return false
   end
end

_svecs2(v::AbstractVector{SVector{D, T}}) where {D, T} = reinterpret(T, v)

_2svecs(v::AbstractVector{T}, D) where {T} = reinterpret(SVector{D, T}, v)


function fdtest(F, dF, X::AbstractVector{SVector{D, TL}}; 
                kwargs...) where {D, TL <: Unitful.Quantity}  
   X1 = ustrip.(X) 
   uL = unit(TL)
   F1 = X1 -> ustrip( F( X1 * uL ) )
   dF1 = X1 -> ustrip.( dF( X1 * uL ) )
   fdtest( F1, dF1, X1; kwargs... )
end


fdtest(F, dF, X::AbstractVector{SVector{D, T}}; kwargs...) where {D, T <: Real} = 
      fdtest( x -> F(_2svecs(x, D)), 
              x -> _svecs2(dF(_2svecs(x, D))), 
              _svecs2(X); kwargs... )

fdtest(F, dF, X::Real; kwargs...) = 
      fdtest( x -> F(x[1]), 
              x -> [dF(x[1])], 
              [X]; kwargs... )


dirfdtest(F, dF, x, u; kwargs...) =
      fdtest(t -> F(x + t * u),
             t -> dot(dF(x + t * u), u),
             0.0; kwargs...)



# --------------------------- 

function fdtest(calc, sys::AbstractSystem;
                verbose = true, 
                directional = (length(sys) <= 10), 
                rattle = 0.03u"Å", 
                test_virial = false, 
                test_forces = true, 
                )

   if test_forces 
      X0 = copy(position(sys))

      # T1 = eltype(eltype(X1))
      # if rattle isa Real 
      #    for i = 1:length(X1)
      #       ui = randn(SVector{3, T1})
      #       ui /= norm(ui)
      #       X1[i] += (rand() * rattle) * randn(SVector)
      #    end
      # end

      _at(_X) = FastSystem(bounding_box(sys), 
                           boundary_conditions(sys), 
                           _X, 
                           atomic_symbol(sys), 
                           atomic_number(sys), 
                           atomic_mass(sys))

      F = X -> potential_energy(_at(X), calc)
      dF = X -> - forces(_at(X), calc)

      f_result = fdtest(F, dF, X0; verbose = verbose )
   end 

   if test_virial
      error("test_virial is currently not implemented")
   end

   return (f_result = f_result, v_result = missing) 
end

