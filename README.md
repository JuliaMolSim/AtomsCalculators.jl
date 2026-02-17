# AtomsCalculators

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaMolSim.github.io/AtomsCalculators.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaMolSim.github.io/AtomsCalculators.jl/dev/)
[![Build Status](https://github.com/JuliaMolSim/AtomsCalculators.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaMolSim/AtomsCalculators.jl/actions/workflows/CI.yml?query=branch%3Amaster)

## Overview

AtomsCalculators.jl provides a unified calculation interface for atomistic simulation engines within the JuliaMolSim ecosystem. It extends the core abstractions of [AtomsBase.jl](https://github.com/JuliaMolSim/AtomsBase.jl) to standardize how energies, forces, virials, and related quantities are computed and accessed.

The goal of this package is to enable interoperability between different simulation backends while maintaining a clean, extensible API for scientific workflows.

## Design Principles

- **Backend-agnostic abstraction**: Decouple physical models from simulation drivers.
- **Extensibility**: Allow new calculators to be integrated with minimal boilerplate.
- **Composability**: Support integration with molecular dynamics and geometry optimization routines.
- **Testability**: Provide utilities for validating calculator implementations.

## Features

- Unified API for energies, forces and virials
- Support for molecular dynamics with [Molly](https://github.com/JuliaMolSim/Molly.jl)
- Geometry optimization workflows
- Utilities for extending and testing calculator implementations
- Integration to ASE using [i-PI](https://github.com/i-pi/i-pi) style socket interconnect with [IPICalculator.jl](https://github.com/JuliaMolSim/IPICalculator.jl). This is also [Molssi Driver interface](https://molssi.org/software/mdi-2/) compatible.

## Usage Example

With an existing `AtomsBase.AbstractSystem` (`sys`) and calculator (`calc`) that implements the interface:

```julia
using AtomsCalculators

E = AtomsCalculators.potential_energy(sys, calc)
F = AtomsCalculators.forces(sys, calc)
V = AtomsCalculators.virial(sys, calc)

ef = AtomsCalculators.energy_forces(sys, calc)
# Access combined output
E2 = ef.energy
F2 = ef.forces
```

## Documentation

Full documentation is available at:
https://JuliaMolSim.github.io/AtomsCalculators.jl/stable/

## Ecosystem

AtomsCalculators.jl is part of the JuliaMolSim ecosystem and builds on [AtomsBase.jl](https://github.com/JuliaMolSim/AtomsBase.jl) to provide higher-level simulation functionality.
