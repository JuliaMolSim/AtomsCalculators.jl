
using Printf, StaticArrays, Unitful, AtomsBase
using LinearAlgebra: norm 
using AtomsBase: AbstractSystem, FastSystem, position, 
                 FlexibleSystem
using AtomsCalculators: potential_energy, forces, virial 

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

function fdtest(F, dF, X::AbstractVector{TL}; 
                kwargs...) where {TL <: Unitful.Quantity}  
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



# -------------------------------------------
#  Interface code to perform FD tests on 
#  systems with calculators 

function _rattle(X, bb, r)
   if r === false; return X, bb; end
   X1 = copy(X)
   TX = eltype(ustrip.(X)) 
   bb1 = [bb...]
   for i = 1:length(X)
      ui = randn(TX); ui /= norm(ui)
      X1[i] += (rand() * r) * ui
   end
   for i = 1:length(bb) 
      ui = randn(TX); ui /= norm(ui)
      bb1[i] += (rand() * r) * ui
   end
   return X1, bb1
end


function _fdtest_forces(calc, sys::AbstractSystem, verbose, rattle) 
   X0, bb0 = _rattle(position(sys), bounding_box(sys), rattle)

   _at(X) = FastSystem(bb0, 
                       boundary_conditions(sys), 
                       X, 
                       atomic_symbol(sys), 
                       atomic_number(sys), 
                       atomic_mass(sys))

   F = X -> potential_energy(_at(X), calc)
   dF = X -> - forces(_at(X), calc)

   verbose && println("Forces finite-difference test")
   f_result = fdtest(F, dF, X0; verbose = verbose )
   return f_result 
end


function _fdtest_virial(calc, sys::AbstractSystem, verbose, rattle)
   X0, C0 = _rattle(position(sys), bounding_box(sys), rattle)

   # reference deformation is just the identify
   F0 = [1.0 0.0 0.0 ; 0.0 1.0 0.0 ; 0.0 0.0 1.0]
   f0 = F0[:] 

   # this implements a system where cell and positions are deformed according 
   # to the deformation matrix F obtained from the vector fvec 
   function _atv(fvec) 
      F = reshape(fvec, (3,3))
      bb = Ref(F) .* C0 # transform the cell 
      X = Ref(F) .* X0 # transform the positions
      return FastSystem(bb, 
                        boundary_conditions(sys), 
                        X, 
                        atomic_symbol(sys), 
                        atomic_number(sys), 
                        atomic_mass(sys))
   end

   F = fvec ->  ustrip(potential_energy(_atv(fvec), calc))
   dF = fvec -> Vector( ( - ustrip.(virial(_atv(fvec), calc)) )[:] )

   verbose && println("Virial finite-difference test")
   v_result = fdtest(F, dF, f0; verbose = verbose )
   return v_result 
end


"""
```julia
fdtest(calc, sys::AbstractSystem; kwargs...)
```
Performs a finite-difference test for a calculator on an atom system and 
returns a named tuple with the results.

### kwargs
- `verbose=true` : print the results of the test
- `rattle=false` : apply a random perturbation to the system before testing (to turn this on, set the amount of rattling, not `true`)
- `test_virial=true` : test the virial
- `test_forces=true` : test the forces
"""
function fdtest(calc, sys::AbstractSystem;
                verbose = true, 
                rattle = false, 
                test_virial = true, 
                test_forces = true, 
                )

   if test_forces 
      f_result = _fdtest_forces(calc, sys, verbose, rattle)
   else 
      f_result = missing 
   end

   if test_virial
      v_result = _fdtest_virial(calc, sys, verbose, rattle)
   else 
      v_result = missing
   end

   return (f_result = f_result, v_result = v_result) 
end

