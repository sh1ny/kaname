# 0011. Fit engine behind a Kaname interface

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (D5, 2026-11-13; rejection reason restated 2026-11-14)

## Context
Fit calculations (dogma) are large and exacting. EVEShipFit publishes an MIT-licensed Rust dogma engine with a C ABI and a WASM build. Kaname needs the same results on every platform and on the server.

## Decision
- Kaname defines its own `FitEngine` interface in Dart.
- The first implementation adapts EVEShipFit's engine, pinned and unmodified: `dart:ffi` on native platforms and the server, JS interop to its WASM build on web. It is credited in `THIRD_PARTY_NOTICES`.
- The engine reads dogma data from the static-data bundle (ADR 0004).
- A golden corpus checks identical outputs across platforms and is re-run after each static-data build.
- A pure-Dart engine behind the same interface is an optional later milestone, written clean-room from the SDE, public formulas and output comparison only.

## Consequences
- Native build tooling (Rust targets, WASM) joins CI when the engine lands (M10), not before.
- **Rejected:** other engines. D5 chose EVEShipFit's engine first and Kaname's own Dart engine later. Also rejected: writing an engine first, which would mean months of work before any fit feature.
- **Reversal cost:** low behind the interface; the golden corpus proves any replacement.
