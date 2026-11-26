# Kaname Roadmap

Strategy: [openspec/strategy.md](strategy.md) · Architecture: [openspec/architecture.md](architecture.md)

Status is derived: a change is done when archived on `main`; a milestone is done when its changes are done and its exit criteria pass. Releases: 0.1 after M6, 0.2 after M8, 0.5 after M17, 1.0 after M27. Every milestone after M6 should ship on its own, so the project is useful wherever it stops.

## Now: M3 - Identity and access

**Outcome:** a member signs in with any of their characters and reaches one account that holds their main and alts. The install declares its organisation tree, and a scheduled affiliation check keeps every character's corp and alliance current. Rules turn affiliation into member states, and states and groups grant the capabilities that modules check on the server. A character that changes EVE account leaves its old Kaname account without exposing either owner's data.

**Exit criteria:**
- A member signs in with any linked character and reaches the same account. Linking an alt requires signing in with that alt while signed in. The member picks a main and can unlink a character. A character belongs to at most one account, and M2's per-character identities migrate into accounts. (agent)
- When CCP reports a new owner hash for a character, Kaname detaches it from the old account, ends its sessions and drops its server vault token and opt-ins. The new owner gets the character only by signing in and never sees rows that belonged to the previous owner. A device that still holds the character keeps server ESI blocked until it parks, as ADR 0017 requires; verified reclaim stays in M7. (agent)
- The install declares one corporation, one alliance or a coalition of alliances as its tree. A scheduled job refreshes every known character's corporation and alliance through the public affiliation route and the shared scheduler, without a token. (agent)
- Admin rules map affiliation to member states (member, guest or none). An account's state follows its characters, and a character that leaves the tree loses member state at the next affiliation check. (agent)
- Modules declare capabilities, and states and groups grant them. A delegated group manager can change only the groups they manage. Every capability check runs on the server through one check, and an architecture test fails on a bypass. Static-data administration becomes a capability; the configured admin characters remain only as the first admin. (agent)
- On the local self-host stack, the owner signs in with a main from inside the tree, links an alt, and sees both characters' corporation and alliance and the account's member state from the real affiliation job. The owner creates a group that grants a capability to another test account and sees that account gain access, then lose it when removed. A character from outside the tree signs in and gets no member state. (user)

**Changes** (in order; each about one PR):
1. `member-accounts` - one account per member with a main and alts, alt linking by signed-in SSO, unlinking, and migration of M2's per-character identities.
2. `character-transfer` - owner-hash change detection, detaching the character from the old account, ending its sessions, dropping its server token and opt-ins, and keeping the previous owner's rows hidden, without clearing a device holder (ADR 0017); prerequisite `member-accounts`.
3. `org-tree-affiliation` - the install's declared tree (corporation, alliance or coalition) and a scheduled, tokenless affiliation refresh through the shared scheduler.
4. `member-states` - admin rules from affiliation to member states and an account state derived from its characters; prerequisites `member-accounts`, `org-tree-affiliation`.
5. `groups-and-capabilities` - module-declared capabilities, grants from states and groups, delegated group managers, one server-side capability check with an architecture test, and static-data admin as a capability; prerequisite `member-states`.

Smart groups stay in M6 and in-game roles from role tokens in M5. Organisation sharing and consent stay in M4.

## Next: M4 - Privacy and sync

Put the sharing policies and consent of ADR 0006 on top of M3's members and states, and route every privacy-classed read through the privacy scope. Define the sync protocol and settle field-edit ordering (R51). Run the local store spike (R32), build the solo engine skeleton, and add on-device SDE import and solo auto-update. Check CCP's developer terms for one shared native client ID (R45).

## Later

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
- M2 - ESI platform and SSO - 2026-11-26 - The owner signed in on the local stack and on a native desktop, read skills in each mode, and saw the server refuse a call while the desktop held the character. Moving the holder between server and device needed three follow-up fixes after `esi-sso` merged: a refused take, a lost viewer reply and an interrupted take. Each lost or refused reply between two installs needs its own regression test.
