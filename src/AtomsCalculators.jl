module AtomsCalculators


using AtomsBase: AbstractSystem
using Compat: @compat
using StaticArrays
using Unitful

@compat public Energy
@compat public Forces
@compat public Virial
@compat public calculate
@compat public energy_forces
@compat public energy_forces!
@compat public energy_forces_virial
@compat public energy_forces_virial!
@compat public energy_unit
@compat public forces
@compat public forces!
@compat public get_parameters
@compat public get_state
@compat public length_unit
@compat public potential_energy
@compat public promote_force_type
@compat public set_parameters!
@compat public set_state!
@compat public virial
@compat public zero_energy
@compat public zero_forces
@compat public zero_virial


include("interface.jl")
include("utils.jl")
include("submodules/Testing.jl")


end
