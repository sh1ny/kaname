# 0004. Static data is data, swapped live

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-13)

## Context
CCP publishes the SDE as build-numbered JSONL with per-build change files and a schema changelog, and balance and data changes ship often. The owner requires that a new build is taken while the app runs, without recompiling and without changing definitions.

## Decision
- **No code is generated from SDE content.** There are no Dart enums or constants for type, group, attribute or effect ids, and no per-build classes. The few ids code must know live in one small table, checked against each build at import; a missing one is reported, not crashed on.
- **Drift is tolerated.** Known columns are typed. Each row's full record is stored as JSON next to them, so a new field is kept without a migration. A new file is stored raw and reported. Only the disappearance of a file Kaname depends on stops an import.
- **Server:**
  - checks daily, imports a build side by side with the active one, and switches atomically;
  - keeps one previous build for rollback and diffs, so up to three builds exist while an import runs;
  - running requests finish on the old build, with no restart;
  - an import that fails leaves the active build untouched.
- **Apps:**
  - each build produces a compact client data bundle;
  - on a build change the server pushes a notice; apps fetch the bundle or patch in the background and swap it in at a safe point;
  - solo desktop runs the importer itself; how mobile solo-lite gets static data is open (strategy R57), and the M1 bundle format must not rule out either importing on the device or downloading a prebuilt bundle.
- An admin and solo settings page shows loaded versus latest build, the last check, "update now" and the last import's result. Auto-update is on by default.

## Consequences
- Static-data access goes through typed accessors over rows, never compile-time constants.
- The fit engine's dogma data comes from the bundle, so a balance patch reaches fits without a release. The bundle format defined in M1 must already carry the dogma data in a form the pinned engine can be fed (ADR 0011), even though the engine lands in M10.
- **Rejected:** regenerating typed code per build (needs a release for every data change).
- **Reversal cost:** high. Accessors, import and bundle format are shared by every module.
