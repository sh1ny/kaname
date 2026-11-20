# 0013. Client data bundle

- Status: accepted (2026-11-20)
- Date: 2026-11-20
- Supersedes: none
- Chosen by: user (2026-11-19 to 2026-11-20, `client-data-bundle` proposal S1, S2, S4, S7 and S8, design D2, D4, D13 and D20, and their review rounds)

## Context
ADR 0004 keeps static data as data: each SDE build is imported side by side and swapped live, and apps get one compact client data bundle per build. ADR 0011 has the fit engine read its dogma data from that bundle. ADR 0005 has three modes: connected apps learn of a build from their server, desktop solo imports the SDE itself, and mobile solo-lite's static-data source stays open (strategy R57). The bundle is therefore a contract with every app, with the fit engine adapter of M10, and with any device that builds a bundle without a server.

## Decision
- **Format and versioning:** one gzip file of UTF-8 JSON Lines per build. Line 1 is a header with `formatMajor`, `formatMinor`, `build`, `releaseDate`, `locales` and `sections` (each with `file`, `present` and `records`). Then, per section in a fixed file order, a `{"section": <file>}` line and one `[key, typed, raw]` line per record in ascending key order. JSON keys are sorted, numbers are written in their shortest form, and gzip has a zero mtime and a fixed level, so the same input gives the same bytes for one builder version with its locked dependencies.
- **Compatibility (C2):** readers accept any minor version of a major they know and ignore unknown header keys and sections. Adding a section or a header key is a minor bump; any other change is a major bump. An app that cannot read an announced major downloads nothing, keeps its bundle and reports that an app update is needed.
- **One format at a time (C15):** a server never builds or serves two format versions side by side. A stored bundle of another format counts as missing: it is rebuilt, never announced, and the route does not serve it.
- **Contents rule:** the typed columns of the 13 typed SDE files; each type's `radius`, `factionID`, `raceID` and `variationParentTypeID`; and the full raw JSON of every record of the five dogma files and of buffs (`dbuffCollections`), mutaplasmids (`dynamicItemAttributes`) and fighter abilities (`fighterAbilities`, `fighterAbilitiesByType`). Names are stored keyed by locale; bundles hold English only for now, and readers accept further locales. Each section's `records` counts its accepted records and `present` is `records > 0`.
- **Fit engine input (C3):** the dogma, buff, mutaplasmid and fighter sections carry full raw JSON, so the M10 adapter needs no format change for SDE fields. EVEShip.fit's synthetic attributes and effects, which the SDE lacks, are not in the bundle; that is a deliberate gap left to M10. The engine field list the design checked (A5) reflects the engine's public sources as of 2026-11-19; M10 re-checks it against the bundle before writing the adapter.
- **Public data only (C9):** a bundle holds only public SDE data, never character- or member-derived data. That is what allows its route and its announcement stream to be unauthenticated.
- **Per-build delivery:** the server builds a build's bundle on the compute worker before switching to it, under the static-data lock, and repairs a missing, failed or other-format active bundle. It serves the announced bundle and the previous one at `/static-data/bundle/<build>/<sha256>` on the API server, from memory.
- **Immutable URLs (C8):** a bundle URL always carries the bundle's SHA-256, which is what makes `Cache-Control: public, max-age=31536000, immutable` safe. A rebuilt bundle of the same build gets a new hash and therefore a new URL.
- **Whole bundles only (C13):** bundles are delivered whole. Build-to-build patches are not built; adding them later is a format decision.
- **On the device (C22):** an app keeps one bundle per device, as a cache of the bundle in use: a file in the app support directory on native platforms, one Cache Storage entry on the web. This is not the M4 local store, whose choice stays with R32's spike.
- **Solo and solo-lite paths:** the format, builder, reader and search live in the pure-Dart, `dart:io`-free package `kaname_static_data_bundle`. A local SDE zip runs through the import's own record selection and gives the same bytes as the server's build, so desktop solo can build its own bundle and mobile solo-lite can either build one or download a prebuilt one (R57 stays open).

## Consequences
- Every app and the fit engine adapter read this one format; a major bump costs every app one download and older apps an update.
- A builder or dependency upgrade that changes the bytes gives a new hash and one extra download per app, with no format bump.
- Server storage holds one bundle per stored build, at most three.
- **Rejected:**
  - A custom binary layout: much more code and a harder contract for a file whose size was not yet measured.
  - A SQLite file: SQLite on every platform, WASM on the web, and it pre-empts R32.
  - Shipping the engine's own `sde.dat`: its pipeline is a third-party tool outside the SDE-is-data path and is not built per Kaname build.
  - Typed columns only: `typeDogma` and effect modifiers live only in JSON, so the bundle would carry no usable dogma data.
  - Building and serving old and new formats side by side: double storage and build time for a window that is hard to bound.
- **Reversal cost:** medium. Apps and the fit engine path read the format; a change is a major bump and one download per app.
