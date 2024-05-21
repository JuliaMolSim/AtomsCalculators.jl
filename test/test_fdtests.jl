
using AtomsCalculators, Unitful, AtomsBase, StaticArrays, Test 

ACT = AtomsCalculators.AtomsCalculatorsTesting

##

module DemoPairCalc
   using AtomsCalculators, AtomsBase, ForwardDiff, Unitful, StaticArrays
   using AtomsCalculators: @generate_interface 
   using LinearAlgebra: norm 
   import AtomsCalculators: energy_forces_virial, 
                            potential_energy, forces, virial 

   abstract type AbstractPot end 

   struct Pot <: AbstractPot end 
   struct PotFerr <: AbstractPot end 

   const uE = u"eV" 
   const uL = u"Å"

   _v(r) = exp( - sum(abs2, r) )
   _dv(r) = ForwardDiff.gradient(_v, r)

   function _energy(X) 
      return sum(_v(X[j] - X[i]) 
                 for i = 1:length(X), j = 1:length(X) 
                  if i != j)
   end 

   function _forces(X) 
      f = zeros(SVector{3, Float64}, length(X))
      for i = 1:length(X), j = 1:length(X)
         if i != j 
            f[i] += _dv(X[j] - X[i])
            f[j] -= _dv(X[j] - X[i])
         end
      end
      return f
   end

  
  
   function _virial(X) 
      vir = @SMatrix zeros(3,3)
      for i = 1:length(X), j = 1:length(X)
         if i != j 
            r = X[j] - X[i]
            vir -= r * _dv(r)'
         end
      end
      return vir 
   end
   
   # @generate_interface  ... not working as expected 
   potential_energy(sys, calc::AbstractPot; kwargs...) = 
        _energy(ustrip.(position(sys))) * uE 

   forces(sys, calc::Pot; kwargs...) = 
         _forces(ustrip.(position(sys))) * uE / uL

   forces(sys, calc::PotFerr; kwargs...) = 
         0.9 * _forces(ustrip.(position(sys))) * uE / uL

   virial(sys, calc::AbstractPot; kwargs...) = 
         _virial(ustrip.(position(sys))) * uE

   function random_system(Nat)
      bb = [ SA[1.0,0.0,0.0], SA[0.0,1.0,0.0], SA[0.0,0.0,1.0]]*uL
      X = [ Atom(1, rand(SVector{3, Float64})*uL, missing) for _ = 1:5 ]
      periodic_system(X, bb)
   end

end

D = DemoPairCalc


##

Nat = rand(4:8) 
sys = D.random_system(Nat)
calc = D.Pot()
calcFerr = D.PotFerr()

##


result = ACT.fdtest(calc, sys)


# @test result.f_result

# result = AtomsCalculators.AtomsCalculatorsTesting.fdtest(calcFerr, sys)
# @test !result.f_result

##

