# Proposal

## Why

The server now imports, switches and rolls back SDE builds, but the apps see none of it: static data is read only on the server, and nothing tells a running app that a build changed. ADR 0004 requires one compact client data bundle per build, a server notice on each build change, and apps that fetch the bundle and swap it in at a safe point. ADR 0011 requires that bundle to carry the dogma data the fit engine will read. This change is the fourth of five in **M1 - Static data pipeline** (prerequisite `sde-build-switch`, done). It advances this agent-verified exit criterion:

- The client data bundle: one per build, carrying the dogma data. The change's design names the fit engine's input (ADR 0011) the bundle maps to, and shows the format serves both importing on the device and downloading a prebuilt bundle (R57). Apps fetch it once per build after a server notice, swap it in at a safe point, and search types and systems offline.

It also prepares the user-verified criterion "the owner takes a new SDE build while the server and an app run, sees the change report and the settings page, and searches types and systems offline". That criterion is judged when M1 closes, because the settings page comes with `static-data-settings`. The change's one `[user]` task (11.7, added in apply) is a different check: the owner repeats the browser checks in Edge, Firefox and Safari.

Constraining ADRs: 0004 (static data is data, swapped live), 0005 (connected, solo and solo-lite modes), 0008 (Serverpod streams, fan-out through one `RealtimeBus`), 0009 (compute worker isolate, jobs behind a runner), 0010 (Riverpod in the presentation layer only), 0011 (`FitEngine` reads dogma data from the bundle), 0012 (workers reach Postgres through their own connections). Strategy rows R32 (local store deferred to M4) and R57 (mobile solo-lite's static-data source stays open) bound it.

## What Changes

- **Bundle format:** one versioned, self-contained file per build. It holds the 13 typed SDE files (types, groups, categories, market groups, meta groups, dogma attributes, attribute categories, effects, units, type dogma, regions, constellations, solar systems) with their typed columns. The dogma files (attributes, attribute categories, effects, units, type dogma) also carry each record's full JSON, and so do four files outside the typed set: buffs (`dbuffCollections`), mutaplasmids (`dynamicItemAttributes`) and fighter abilities (`fighterAbilities`, `fighterAbilitiesByType`). Types also carry `radius`, `factionID`, `raceID` and `variationParentTypeID`. A field-by-field check of the fit engine's input (design) found these to be every SDE field it reads beyond the typed columns. Names are stored keyed by locale; this change writes English only. The same input, built by the same builder version with its locked dependencies, gives byte-identical output; a builder upgrade may change the bytes, which costs apps one extra download.
- **Shared builder:** the format, builder, reader and search live in a new pure-Dart, `dart:io`-free package, `kaname_static_data_bundle`, used by the server, the app and `kaname_static_data`. The server builds a bundle on the compute worker for each build it switches to. A test builds the bundle from a local SDE zip with no server and gets the same bytes, which keeps device-side import open (R57).
- **Serving:** the server serves the announced bundle, and the one announced before it, by build number, from memory. A bundle URL (build number and hash) never changes, so clients may cache it.
- **Notice:** a minimal `RealtimeBus` (local delivery on Serverpod's message system, ADR 0008) and a stream the app holds while connected. Each switch and rollback announces the new active build once its bundle is ready. The app also checks on start and on reconnect.
- **App:** fetches the bundle once per build, keeps one copy that each save replaces whole (native: a file in the app support directory, replaced by rename; web: one browser Cache Storage entry), and swaps it in at a safe point, so a search in progress finishes on the bundle it started with.
- **Offline search:** a quick search in the top bar over the bundle in memory: case-insensitive substring on the English name, prefix matches first, up to 50 results, published types and all solar systems, and an exact numeric id also matches. Each result shows its name and its group or region.

Out of scope: build-to-build patches (full bundles only); other name languages; on-device import wired into the app (solo comes later; this change only proves the builder runs without a server); detail screens for types or systems; the settings page, "update now", auto-update toggle and import results (`static-data-settings`); choosing the M4 local store (R32); the fit engine itself, and the attributes and effects EVEShip.fit patches in beyond the SDE (M10).

## Capabilities

### New Capabilities
- `client-data-bundle`: the bundle format and its version, what it holds, the deterministic shared builder, one bundle per build built by the server, and serving it by build number.
- `client-static-data`: how the app learns of a new build, fetches and keeps the bundle per platform, and swaps it in at a safe point.
- `static-data-search`: offline search over types and solar systems from the bundle, and the top-bar quick search that shows it.
- `realtime-bus`: the `RealtimeBus` interface with local delivery, and the build-change stream apps subscribe to.

### Modified Capabilities
- `server-workers`: the compute worker also runs bundle builds.
- `static-data-builds`: a switch or rollback announces the new active build to apps once its bundle is ready.

## Impact

- `packages/kaname_static_data_bundle` (new): bundle format, builder, reader, search index; tests and fixtures. `packages/kaname_static_data`: reading records from a zip into the builder.
- `packages/kaname_core`: the `RealtimeBus` interface.
- `tools/kaname_tools`: the purity check also keeps web-safe packages free of `dart:io`.
- `server/kaname_server`: bundle build job on the compute worker, bundle storage and serving, the bus on Serverpod messages, the build-change stream endpoint; possibly a migration.
- `app/`: bundle fetch, cache and swap in `data/` and `logic/`, the top-bar search UI, localised strings; possibly new dependencies (file paths on native, Cache Storage on web), with `THIRD_PARTY_NOTICES` regenerated.
- Server storage: one bundle per stored build (at most three).
- Client download: one bundle per build change.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Bundle contents

- **Choice:** all 13 typed SDE files with their typed columns. The five dogma files also carry each record's full JSON, plus buffs (`dbuffCollections`) and mutaplasmids (`dynamicItemAttributes`). The field-by-field check of the fit engine's input then added types' `radius` and the full JSON of `fighterAbilities` and `fighterAbilitiesByType` (owner's choice after the check); the round 5 design review added types' `factionID`, `raceID` and `variationParentTypeID`, which the engine's input lists, so M10 needs no format change for them (owner's choice). EVEShip.fit's patched attributes and effects, which the SDE does not hold, are an M10 item, not part of this bundle.
- **Rejected:** typed columns only (first answer, revisited: `typeDogma` has no typed columns, and effect modifiers live only in JSON, so the bundle would carry no usable dogma data, against ADR 0011); an explicit list of extra dogma fields (barely smaller, and a missed field would force a format bump); leaving out types' faction, race and variation parent (no evidence the M10 adapter can do without them); full JSON for every file (much larger, mostly type descriptions); types, systems and dogma only (later changes would need a format bump for groups, markets and the map).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: the bundle format is a contract with every app and with the fit engine.
- **Chosen by:** user (after discussion of the fit engine's input)

### S2: Name languages

- **Choice:** English names only in this change, stored keyed by locale so later builds can add languages without breaking the format.
- **Rejected:** every SDE language now (a much bigger bundle, unused until the app is localised).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: the format's name layout.
- **Chosen by:** user

### S3: Server notice

- **Choice:** a minimal `RealtimeBus` interface with local delivery on Serverpod's message system, and a Serverpod stream the app holds while connected; the app also checks the active build on start and on reconnect. This is the bus's first user (ADR 0008).
- **Rejected:** a stream fed straight from the switch with no bus (a path ADR 0008 does not describe); polling only (no push, a weak fit for "after a server notice").
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: every later realtime feature uses the bus interface.
- **Chosen by:** user

### S4: Keeping the bundle on the device

- **Choice:** each device keeps one copy of the bundle in use, replaced whole by each save: native platforms as one file in the app support directory, written to a temporary file and renamed over it; web as one browser Cache Storage entry under a fixed key, holding its build and hash, so a reload needs no new download. A reader always sees a whole old or a whole new bundle (round 5 design review). The M4 local store (R32) is not chosen here.
- **Rejected:** web in memory only (a full download on every load); choosing the M4 local store now (pre-empts R32's spike); several entries with a current pointer and cleanup (rounds 3 and 4: every version raced across tabs or an interrupted save).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see: what the app downloads and keeps.
- **Chosen by:** user

### S5: Where search lives

- **Choice:** a quick search field in the top bar with a results list; no detail screens yet.
- **Rejected:** a dedicated Search destination in the navigation; a search box on the static-data settings page (would wait on `static-data-settings`).
- **Reversal cost:** low
- **Important:** yes, because it changes what users see.
- **Chosen by:** user

### S6: Search rules

- **Choice:** case-insensitive substring on the English name, prefix matches ranked first, up to 50 results, published types and all solar systems; an exact numeric id also matches.
- **Rejected:** prefix only (misses words inside a name); fuzzy matching (more code, harder to test deterministically).
- **Reversal cost:** low
- **Important:** yes, because it changes what users see.
- **Chosen by:** user

### S7: Patches

- **Choice:** full bundles only; build-to-build patches are left to a later change if size calls for them.
- **Rejected:** building and serving patches now.
- **Reversal cost:** low
- **Important:** yes, because ADR 0004 names patches as an option and this defers it.
- **Chosen by:** user

### S8: Building without a server

- **Choice:** the builder is pure Dart in a shared package (design D11). A test builds the bundle from a local SDE zip with no server and gets the same bytes as the server's build. No on-device import is wired into the app yet.
- **Rejected:** wiring desktop solo import into the app now (solo arrives with M4 and M7); a server-only builder with the device path argued only in design (R57 would rest on argument alone).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: solo and solo-lite reuse this builder.
- **Chosen by:** user
