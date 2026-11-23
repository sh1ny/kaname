# Kaname Roadmap

Strategy: [openspec/strategy.md](strategy.md) · Architecture: [openspec/architecture.md](architecture.md)

Status is derived: a change is done when archived on `main`; a milestone is done when its changes are done and its exit criteria pass. Releases: 0.1 after M6, 0.2 after M8, 0.5 after M17, 1.0 after M27. Every milestone after M6 should ship on its own, so the project is useful wherever it stops.

## Now: M2 - ESI platform and SSO

**Outcome:** a test character signs in on a self-hosted server and in native solo mode, then makes a scoped ESI call through the same generated client and scheduler policy. One holder owns the character's token (ADR 0005). The platform keeps ESI limits and token handling out of product modules (ADR 0007); call-log reads follow ADR 0006.

**Exit criteria:**
- Kaname's generator reads the ESI spec at one pinned compatibility date and produces a reproducible typed client and route catalogue (rate group, scopes, roles and cache behavior). Recorded responses exercise the generated contract. (agent)
- Every ESI call goes through the shared scheduler. Tests prove atomic budget reservation across server isolates and in solo, response-header correction, four governor tiers, priorities, shared negative caching and conditional polling with downtime handling. (agent)
- Call logs retain route, status, cost, latency and bucket for seven days, distinguish refused calls from errors, contain no tokens, and enforce ADR 0006 visibility. (agent)
- Refresh tokens are encrypted with an install key kept outside the database. Tests prove one holder per character, single-flight refresh and rotation recovery, and re-login when a rotated token is lost. (agent)
- The server uses confidential SSO and maps the validated character to a Serverpod identity; native solo uses PKCE. Both validate JWT claims against CCP's JWKS and derive requested scopes under ADR 0006. (agent)
- The owner signs in with a test character through both flows and sees a scoped ESI call succeed in each, without concurrent token holders for that character. Use an owner-provided native registration; the shared native client ID decision (R45) stays open. (user)

**Changes** (in order; each about one PR):
1. `esi-client-generator` - pinned ESI spec and compatibility date, typed client and route catalogue.
2. `esi-request-scheduler` - atomic budgets (Redis on server, in-process in solo), bucket mirrors, four-tier governor, priorities, negative cache and conditional polling; prerequisite `esi-client-generator`.
3. `esi-call-log` - scheduler outcomes, seven-day retention, secret-free logging and ADR 0006 visibility; prerequisite `esi-request-scheduler`.
4. `esi-token-vault` - install-key encryption, one token holder per ADR 0005, single-flight refresh and rotation recovery.
5. `esi-sso` - confidential server flow and native PKCE, JWT/JWKS verification, Serverpod identity and a scoped ESI call through the platform; prerequisites `esi-call-log`, `esi-token-vault`.

## Next: M3 - Identity and access

Build on the character identity established in M2: model mains and alts, handle ownership transfers using the SSO owner hash, and represent member states, groups and capabilities. Model the organisation tree through corporations, alliances and coalitions so access can follow membership and delegated roles.

## Later

- M4 - Privacy and sync: sharing policies and consent, privacy-scoped data paths, sync protocol (settles R51), local store spike (R32), solo engine skeleton, on-device SDE import and solo auto-update.
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
- M1 - Static data pipeline - 2026-11-23 - The self-hosted stack took SDE build `3720952` over `3714173` without rebuilding; the owner saw Settings and the change report and found a type and a system offline. All 30 declared industry and logistics fields were present in the SDE audit, so no overlay is needed unless a future audit finds a gap.
  [Static data settings decision S2](changes/archive/2026-11-23-static-data-settings/proposal.md#s2-meaning-of-the-solo-half-before-solo-mode-exists) kept the M1 app side to bundle status and Download now; on-device import and solo auto-update remain in M4.
