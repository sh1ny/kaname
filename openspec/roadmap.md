# Kaname Roadmap

Strategy: [openspec/strategy.md](strategy.md) · Architecture: [openspec/architecture.md](architecture.md)

Status is derived: a change is done when archived on `main`; a milestone is done when its changes are done and its exit criteria pass. Releases: 0.1 after M6, 0.2 after M8, 0.5 after M17, 1.0 after M27. Every milestone after M6 should ship on its own, so the project is useful wherever it stops.

## Now: M1 - Static data pipeline

**Outcome:** the server imports any SDE build side by side, switches builds atomically, keeps the previous one and reports what changed between builds. Apps download a compact client bundle once per build and search types and systems offline. A new build is taken while server and apps run, with no rebuild and no code change: unknown fields and files are kept and reported (ADR 0004). An admin and solo settings page shows loaded versus latest build. It retires the risk that static data forces releases. The bundle format must also feed the fit engine later and keep mobile solo-lite's options open (R57). It also checks whether the SDE has every field industry and logistics need right after a patch (R38). First, the product web build moves to `--wasm`, as the M0 grid spike recommends (R61).

**Exit criteria:**
- The product web build is `--wasm` (skwasm, CanvasKit fallback for browsers without WasmGC), without COOP/COEP headers, and `webbuild --check` passes on it. (agent)
- The server imports an SDE build side by side with the active one. Known columns are typed and every row keeps its full record as JSON. A new field or file is kept and reported; only a missing file Kaname depends on stops the import, and a failed import leaves the active build untouched. No code is generated from SDE content, and the known-ids table is checked against each build. (agent)
- The build switch is atomic: requests in flight finish on the old build, with no restart, and one previous build is kept for rollback and diffs. A report lists what changed between two builds. A daily check finds new builds. (agent)
- The client data bundle: one per build, carrying the dogma data. The change's design names the fit engine's input (ADR 0011) the bundle maps to, and shows the format serves both importing on the device and downloading a prebuilt bundle (R57). Apps fetch it once per build after a server notice, swap it in at a safe point, and search types and systems offline. (agent)
- An admin and solo settings page shows loaded versus latest build, the last check, "update now" and the last import's result; auto-update is on by default. (agent)
- A report records whether the SDE has every field industry and logistics need right after a patch (R38). (agent)
- The owner takes a new SDE build while the server and an app run, sees the change report and the settings page, and searches types and systems offline. (user)

**Changes** (in order; each about one PR):
1. `web-wasm-build` - product web build on `--wasm` (skwasm without COOP/COEP headers at first), the webbuild check, deploy notes.
2. `sde-import` - side-by-side import into Postgres: typed known columns plus raw JSON, unknown files stored and reported, known-ids table check, the R38 field check, and settles R56 (worker isolate access: the importer is the first job on the compute worker isolate).
3. `sde-build-switch` - atomic switch, previous build kept, build-to-build diff report, daily check; prerequisite `sde-import`.
4. `client-data-bundle` - bundle format with dogma data, per-build bundle, server notice, app download, cache and safe-point swap, offline type and system search; prerequisite `sde-build-switch`.
5. `static-data-settings` - admin and solo settings page: loaded versus latest build, last check, update now, last import result, auto-update; prerequisites `sde-build-switch`, `client-data-bundle`.

## Next: M2 - ESI platform and SSO

Every ESI call goes through one platform (ADR 0007). Kaname's own generator reads ESI's spec at a pinned compatibility date and produces a typed client and a route catalogue. One scheduler policy governs every call: an atomic budget reservation, bucket mirrors, a four-tier governor, priorities, a shared negative cache and polite polling. A token vault encrypts refresh tokens with an install key and refreshes single-flight per character. SSO uses a confidential web flow on the server and a PKCE native flow on solo devices. A call log records each call for 7 days, with visibility under ADR 0006. It retires the risk that ESI limits or token loss break the product.

## Later

- M3 - Identity and access: mains and alts, owner-hash transfers, states, groups, capabilities, org tree with coalitions.
- M4 - Privacy and sync: sharing policies and consent, privacy-scoped data paths, sync protocol (settles R51), local store spike (R32), solo engine skeleton.
- M5 - Character data and member audit: ingestion recipes, corp data from role tokens, audit and compliance.
- M6 - Rules, notifications and Discord v1: rule engine, smart groups, notification bus, Discord linking and role sync, pings. Release 0.1.
- M7 - Personal space: multi-character console, skill planner, assets, personal worklist, solo complete, solo to join, mobile push (settles R40).
- M8 - Prices and appraisal: one price service, paste appraisal, order tracker. Release 0.2.
- M9 - Fittings I: fit model and formats, doctrines, readiness, skill plans, push fit to character.
- M10 - Fittings II: FitEngine adapters (ADR 0011), golden corpus, fit editor.
- M11 - Ops and fleets: ops calendar, fleet tracking, participation, composition.
- M12 - SRP: killmail verification, payout rules, approvals, payment matching.
- M13 - Waitlist: X-up with fit checks, FC queue, invites, realtime.
- M14 - Structures, timers and sov: notification parsing, fuel, timer board, sov.
- M15 - Killmails and intel: killmail ingestion, feeds, stats, battle reports, intel model.
- M16 - Mapper I: collaborative wormhole maps, signatures, connections, realtime (settles R42).
- M17 - Mapper II: auto-mapping, routes, jump planning, map overlays. Release 0.5.
- M18 - Industry I: blueprints, jobs, facilities, cost model, build planner, stockpiles.
- M19 - Industry II: build requests, corp projects mirror, invention, PI dashboard.
- M20 - Mining and moons: ledgers, extractions, moon catalogue, reprocessing, mining tax.
- M21 - Finance: expected payments, journal matching, corp ledgers, tax programs.
- M22 - Market and logistics: buyback, freight, corp shop, standing buy orders.
- M23 - Recruitment and HR: applications, vetting summary, inactivity, alumni, blacklist.
- M24 - Diplomacy and standings: standings sets, requests, contact sync, ACL viewer.
- M25 - Org dashboards: dashboards, org worklist, scheduled reports, read-only API, signed webhooks.
- M26 - Desktop local: read-only log tailing, intel parsing, alarms, window layouts (settles R43).
- M26b - AI assistant: desktop panel driving the member's own runtime (D11; settles R35–R37).
- M27 - 1.0 hardening: install and upgrade polish, backup drills, accessibility, security review, performance.
- M28 - Own Dart dogma engine (optional): pure-Dart engine behind `FitEngine`, proven on the golden corpus.

## Done

- M0 - Walking skeleton - 2026-11-18 - The skeleton holds end to end on six targets and the self-host stack. The grid spike passes on skwasm but CanvasKit misses on scrolling (missed frames, on a software GPU), so M1 opens with `--wasm`. The owner's grid check ran on the development PC instead of a low-end laptop (R58).
