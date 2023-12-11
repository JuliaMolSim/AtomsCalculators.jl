# Check List for Calculator Implementers

1. Make sure that `AtomsCalculators.promote_force_type` returns correct force type and unit.
2. Make sure that `AtomsCalculators.zero_forces` returns correct array type and unit for forces.
3. Non allocating force call has to add to the force input array not overwrite it.
4. Make sure that your calculator supports nested multithreading. That is it can be called from inside multithreaded loop. This means you should not use static scheduling with `Threads.@threads`.
5. Remember to allow general keywords to be called. Meaning that your call needs to have `kwargs...`. You can safely ignore the extra keywords.
6. Remember that AtomsBase structures can return different data types for position. Some return `SVector`, some use `Vector` etc. You have to support them all.
7. You can make different implementations for different AtomsBase structures.