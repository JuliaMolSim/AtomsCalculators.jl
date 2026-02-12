# AtomsCalculators.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaMolSim.github.io/AtomsCalculators.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaMolSim.github.io/AtomsCalculators.jl/dev/)
[![Build Status](https://github.com/JuliaMolSim/AtomsCalculators.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaMolSim/AtomsCalculators.jl/actions/workflows/CI.yml?query=branch%3Amaster)

## Overview

AtomsCalculators.jl provides a unified calculation interface for atomistic simulation engines within the JuliaMolSim ecosystem. It extends the core abstractions of AtomsBase.jl to standardize how energies, forces, stresses, and related quantities are computed and accessed.

The goal of this package is to enable interoperability between different simulation backends while maintaining a clean, extensible API for scientific workflows.

## Design Principles

- **Backend-agnostic abstraction**: Decouple physical models from simulation drivers.
- **Extensibility**: Allow new calculators to be integrated with minimal boilerplate.
- **Composability**: Support integration with molecular dynamics and geometry optimization routines.
- **Testability**: Provide utilities for validating calculator implementations.

## Features

- Unified API for energies, forces and virials
- Support for molecular dynamics
- Geometry optimization workflows
- Utilities for extending and testing calculator implementations

## Documentation

Full documentation is available at:
https://JuliaMolSim.github.io/AtomsCalculators.jl/stable/

## Ecosystem

AtomsCalculators.jl is part of the JuliaMolSim ecosystem and builds on AtomsBase.jl to provide higher-level simulation functionality.
