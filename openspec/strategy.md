# Kaname Strategy

## Purpose
Kaname (要, "linchpin") is an open-source, self-hosted EVE Online corporation and alliance suite: one Flutter app for web, desktop and mobile on a Serverpod server, with a personal console for every pilot. It replaces a patchwork of separate tools with one coherent product that a small group can deploy and that members want to install for themselves.

## Users
- **Pilots (members):** run the app for their own characters (skills, plans, assets, wallets, industry, fits), connected to their org's server or alone on desktop (solo). They need it to be useful to them first, and to share only what they choose.
- **Leadership** (directors, FCs, recruiters, industry and logistics leads): member audit, compliance, fleets, doctrines, SRP, structures and timers, economy, all from data members share under a clear policy.
- **Install admins:** self-host one install for one organisation tree (a corp, an alliance, or a coalition) and need setup, upgrades and backups to be easy.
- **Guests** (blues, applicants, contractors): limited access through state rules.

The first real user is expected to be the owner's own corp; until then trials use seeded or volunteer data (R39).

## Boundaries
- **Non-commercial and self-hosted:** no paid tiers, hosted SaaS, ads or ISK-for-access, as CCP's developer licence requires. No central bot or relay run by the project: each install brings its own Discord bot and push keys.
- **One organisation tree per install.** Coalitions are modelled; hosting several unrelated alliances on one install is out of scope for 1.0.
- **EULA boundary:** desktop integration only reads log files and moves or resizes windows. No input broadcasting, synthetic input, memory reading, client screen capture, packet inspection or global keyboard hooks.
- **Privacy:** personal data is private by default. Each org decides what members must share, members see exactly what is shared, and admins are not exempt.
- **Clean room:** no third-party product code, schemas or templates. Static game data is data, never generated code.
- **AI assistant:** desktop only, driving the member's own agent runtime. There are no API keys or LLM billing in Kaname, and no server-side model.
- Platforms: web, Windows, Linux, macOS, Android and iOS from one codebase. Only Tranquility is tested.

## Success measures
1. A new admin goes from `docker compose up` to the first login in under 30 minutes, following the docs.
2. Release 0.1 runs a small corp's core (login, alts, groups, Discord roles) with no other tool.
3. Members keep using the personal console after a week of real use (the M7 trial).
4. An install never trips ESI's error limit (no 420 responses) in a 24-hour soak.

## Tracks
- **Platform:** static data, ESI and SSO, identity, privacy, sync (Part A).
- **Member core and personal console:** audit, rules, notifications, Discord, personal space, prices (Parts B–C).
- **Fleet, doctrine and space:** fittings, ops, SRP, waitlist, structures, intel, the mapper (Parts D–E).
- **Economy and org:** industry, mining, finance, logistics, recruitment, diplomacy, dashboards (Parts F–G).
- **Desktop extras and 1.0:** log tailing, intel, alarms, the assistant, hardening (Parts H–I).

## Decision summary

- init 2026-11-14: all (source: setting)
- close M0 2026-11-18: all (source: setting)
- close M1 2026-11-23: all (source: setting)
- close M2 2026-11-26: all (source: setting)

| # | Run | Decision | Choice | Rejected | Reason | Important | Chosen by |
|---|---|---|---|---|---|---|---|
| R1 | init | Backend (D1, 2026-11-13) | Serverpod (Dart) with Postgres and Redis | Other server stacks | One language end to end; custom identity providers, recurring jobs, streams and Redis are built in | yes | user |
| R2 | init | Clients (D2, 2026-11-13) | One Flutter app for web, desktop and mobile; parity and sync first, desktop extras later | Separate apps per platform | One codebase, every platform | yes | user |
| R3 | init | Hosting (D3, 2026-11-13) | Self-host first with Docker Compose; no SaaS, no paid tier | Hosted service | Developer licence and project intent | yes | user |
| R4 | init | Licence (D4, 2026-11-13) | AGPL-3.0 | Permissive or non-commercial licences | Hosted forks must share source; compatible with the MIT fit engine | yes | user |
| R5 | init | Fit engine (D5, 2026-11-13) | EVEShipFit's MIT dogma engine, pinned and unmodified, behind Kaname's `FitEngine` interface (FFI native, WASM web); own Dart engine optional later | Writing an engine first | Defers the hardest calculation work | yes | user |
| R6 | init | Solo mode (D6, 2026-11-13) | Desktop works alone with a local database and runs every job locally; joining a server later uploads personal records; corp and alliance features are server-only | Server-only app | Members get value without a server | yes | user |
| R7 | init | Privacy (D7, 2026-11-13) | Sharing policy per org; private by default; members see what is shared; non-shared data only in aggregates | Org sees everything | Trust, and members want to install it | yes | user |
| R8 | init | Name (D8, 2026-11-14) | Kaname | Other names | Owner's pick | yes | user |
| R9 | init | Mapper (D9, 2026-11-13) | Built-in wormhole mapper | Integrating an external mapper | A stand-out feature | yes | user |
| R10 | init | No-copy rule (D10, 2026-11-13) | Concepts only from studied projects; pinned, credited dependencies are use, not copying; any data-file copy needs owner approval and a licence notice | Porting code | Clean room | yes | user |
| R11 | init | AI assistant (D11, 2026-11-13) | Desktop only, driving the member's own runtime behind one driver interface: Claude Code over ACP, Codex over `codex app-server`, OMP's native RPC later. Wire parts adapted from the owner's kumiko project with a provenance note ("adapted from kumiko, (c) Nikolay Bochev, relicensed AGPL-3.0"); no vendored third-party parts. Read-only tools through the privacy engine; UI actions only after the user confirms | API keys or a server-side model | No billing and no keys in the app | yes | user |
| R12 | init | Repo and workspace (Q2, Q17, 2026-11-14) | Public `sh1ny/kaname` from day one; git; WSL primary clone, a separate Windows clone only for the Windows desktop app, synced through GitHub | Private until 0.1; shared checkout | Community trust; Windows builds need Windows | yes | user |
| R13 | init | Roles (Q12, 2026-11-14) | Claude plans, OMP implements, OMP launches Claude to review; no Codex | Other splits | Owner's workflow | no | user |
| R14 | init | Live static-data updates (2026-11-13) | A new SDE build is taken while server and apps run, with no rebuild and no code generated from SDE content | Regenerating code per build | CCP ships data changes often | yes | user |
| R15 | init | Branding (Q14) | Ember kit as is, with impeccable for design reviews | A product-specific palette | One design system | no | user |
| R16 | init | Coalition depth (Q7) | Model coalitions in the org tree now; test multi-alliance installs later | One alliance plus guests; full coalition at 1.0 | Cheap to model, costly to migrate | yes | user |
| R17 | init | Mobile solo (Q9) | Solo-lite: local store, sync in the foreground or OS background fetch | Mobile always connected | Lets people try it without a server; engine is shared | yes | user |
| R18 | init | Push (Q8) | UnifiedPush/ntfy by default; FCM/APNs only with the installer's own keys | FCM/APNs first | Self-host-pure, no central relay | yes | user |
| R19 | init | Success measures | The four measures above | Release cut points only | Observable and checkable | no | user |
| R20 | init | M0 changes | Policies folded into `repo-scaffold`; `web-grid-spike` added; the baseline writes the foundational ADRs | Plan's list with `adrs-and-policies`, spike at M2 | Tests the riskiest UI assumption first | yes | user |
| R21 | init | CI matrix | Linux, Windows and macOS runners; web, Windows, Linux, macOS, Android and iOS (no codesign) builds from M0 | Linux and Windows only | Free runners for public repos; catch breakage early | no | user |
| R22 | init | Detailed module plans | Nothing now; each milestone restates its modules' requirements, scrubbed, in its own change proposals and designs | All modules now under `docs/`; never | Small baseline, nothing stale | no | user |
| R23 | init | Repo layout (ADR 0003) | Root pub workspace; pure-Dart shared packages; vertical, compiled-in modules with feature toggles | Adding melos | Serverpod 4.1 projects are pub workspaces already | yes | user |
| R24 | init | App state (ADR 0010) | flutter_riverpod 3 confined to the presentation layer; no codegen, no experimental persist; domain and repositories plain Dart, constructor-injected | ChangeNotifier ViewModels; Riverpod with codegen; Bloc | Saves async, cache and invalidation glue across many screens; confined so domain code stays framework-free. Chosen after discussion | yes | user |
| R25 | init | Privacy enforcement (ADR 0006) | In the data-access layer, with an architecture test against bypass | Endpoint checks | One place to get right | yes | user |
| R26 | init | ESI token holder (ADR 0005) | Exactly one holder per character, server or device; connected apps never call ESI for server-held characters | Device may also poll | Avoids diverging data, game writes from two places and double load on CCP, and gives one place to see sync state (reason corrected after review M5, 2026-11-14) | yes | user |
| R27 | init | ESI client (ADR 0007) | Own generator from ESI's OpenAPI spec at a pinned compatibility date | Hand-written routes | Rate groups and scopes come from the spec | yes | user |
| R28 | init | ESI rate limits (ADR 0007) | One scheduler with a governor, bucket mirror, negative cache and downtime pause for every call | Per-module throttling | The error limit is shared per connection | yes | user |
| R29 | init | Sync conflicts (ADR 0008) | Server truth; per-user change log; field-level last-writer-wins with history for personal records; org records online only | CRDTs; record-level LWW | Enough for personal records; org data needs authority | yes | user |
| R30 | init | Realtime (ADR 0008) | Serverpod streams; one RealtimeBus on Serverpod's message system (Redis is always present, R48); per-object event log with sequence and gap resync; every delivery through the privacy scope | A bus that also works without Redis (first answer, changed after review M1) | One bus design | yes | user |
| R31 | init | Process model (ADR 0009) | One server process; endpoints and the future-call adapter on the main isolate; realtime, Discord and compute worker isolates; fit engine in-process on the compute worker (updated after review, R53) | Separate worker containers | Fewer deployment parts for small installs | yes | user |
| R32 | init | Local store for solo and offline cache | Decide at M4 with a spike of drift against Serverpod's client-side database; no ADR until then | Choosing drift or Serverpod's client DB now | Nothing needs it before M4; Serverpod's client DB is new | yes | user |
| R33 | init | Token vault (ADR 0007) | Refresh tokens encrypted with an install key kept outside the database; rotated token saved as soon as CCP returns it (R52) | Plain in Postgres | A database dump must not leak tokens | yes | user |
| R34 | init | Third-party Riverpod skill | Vendor nothing; `app-shell` writes a short project-owned Riverpod guide | Vendoring the external skill | It requires code generation and a mocking package, which ADR 0010 and the project rules exclude | no | user |
| R35 | init | Assistant: read-only SQL over the member's own data only | Open | — | Owner evaluating (2026-11-13) | yes | pending |
| R36 | init | Assistant: an early M26b-lite after M8, with a minimal read-only game-log reader | Open | — | Owner evaluating (2026-11-13) | yes | pending |
| R37 | init | Assistant: an OpenAI-compatible endpoint driver as a third route next to ACP and app-server | Open | — | Owner evaluating (2026-11-13) | yes | pending |
| R38 | init | Optional community overlay of client-extracted game data for fields the SDE lacks right after a patch | No overlay unless an import's field check finds a gap | Add an overlay now | All 30 declared fields were present in SDE build 3714173 ([field check](../docs/static-data/r38-field-check.md)); every import re-checks them | no | user |
| R39 | init | First real user (Q6) | Open (likely the owner's corp) | — | Needed for user trials from M5 | no | pending |
| R40 | init | Mobile scope (Q15) | Open, decide at M7 (lean: push plus read-only views and a few one-tap actions) | — | — | yes | pending |
| R41 | init | Voice service adapter (Q16) | Open (lean: Mumble adapter near M25) | — | — | no | pending |
| R42 | init | Wormhole statics data source (Q10) | Open, decide at M16 | — | Any copied data needs owner approval | no | pending |
| R43 | init | More desktop extras (Q5) | Open, ask near M26 | — | — | no | pending |
| R44 | init | Public demo hosting (Q13) | Open, after 0.2 | — | Needs its own ESI app and seeded data | no | pending |
| R45 | init | One shared native SSO client id for solo users | Open, check CCP's developer terms at M4 | — | — | yes | pending |
| R46 | init | Licence of a shared agent-runtime package, if ever extracted from kumiko (Q3) | Open (lean: MIT or Apache) | — | Copying is already permitted | no | pending |
| R47 | init | Optional third-party price and appraisal providers (Q11) | Open, decide at M8 | — | ESI prices suffice to start | no | pending |
| R48 | init | Redis and instances (review M1, M2) | Redis required on every install; one server instance in 1.0; multi-instance later through a superseding ADR with worker leases | Multi-instance now with leases; Redis optional on one instance | Target size fits one instance; one bus and budget design | yes | user |
| R49 | init | Offline data (review M7) | Clients persist only the viewer's own data and org records; other members' data in memory only | Cache on disk and purge on reconnect | A revoke must reach offline viewers | yes | user |
| R50 | init | Login scopes (review M8) | Enabled modules' scopes limited to the org policy's required classes, plus the member's opt-ins; never-requested classes get no scope | Union of all enabled modules' scopes | Hold only the access members chose to give | yes | user |
| R51 | init | Ordering of concurrent field edits (review M13) | Open item that M4's sync-protocol change must settle before any client ships (lean: hybrid logical clock per field edit) | Settling it now; server arrival order | Nothing syncs before M4 | yes | user |
| R52 | init | ESI correctness (review M3, M4, M5, M12) | Atomic check-and-spend budget reservation; single-flight refresh per character with save-on-return and one re-read retry under the lock (a crash before the save still means re-login); bounded hot loops; corrected one-holder rationale | — | Races and crashes must not trip limits or kill tokens | yes | user |
| R53 | init | Server jobs (review M9, M10, S1) | Job logic in pure Dart behind a job-runner interface (future calls are the server adapter); no extra Redis job locks; idempotent jobs; static-data import and fit engine on a compute worker isolate | Jobs as FutureCall subclasses; extra locks | Solo reuses jobs; endpoints never stall | yes | user |
| R54 | init | Privacy paths (review M6, S7) | Privacy scope and its test cover every outbound path (streams, Discord, push, exports, API); per-character call-log rows are privacy-classed, admins see totals | Call log as operational data visible to admins | Admins are not exempt | yes | user |
| R55 | init | Fit-engine rejection reason (review M11) | ADR 0011 rejects other engines because D5 chose EVEShipFit's first and an own Dart engine later; no licence claim | The incorrect licence and no-copy reason | Owner, 2026-11-14: "We already settled on the choice of engine" | no | user |
| R56 | init | Worker isolate access to Postgres, Redis, vault, privacy scope and bus (review round 2 M1) | ADR 0012: workers own Postgres connections per job. ADR 0014: the main isolate publishes typed worker replies to the bus. Redis, vault and privacy scope remain open | Proxying Postgres rows through the main isolate; an unstarted Serverpod in the worker | Serverpod's ORM and messages need a Session | yes | pending |
| R57 | init | Static-data source for mobile solo-lite (review round 2 M3) | Open, settle with the mobile scope (R40); M1's bundle format keeps both options | — | No server to fetch a bundle from | yes | pending |
| R58 | close M0 | Hardware for the owner's grid-spike check (M0 user exit criterion) | The development PC under gaming load | A low-end laptop (now optional) | Owner, 2026-11-17: "This PC counts"; accepted 2026-11-18 (web-grid-spike task 9.5) | yes | user |
| R59 | close M0 | Pending rows R35–R47, R56, R57 | All stay open until their milestone or event | Settling some at this close | None is due yet | no | user |
| R60 | close M0 | M1 split | Four changes: `sde-import`, `sde-build-switch`, `client-data-bundle`, `static-data-settings` | Three changes with the build switch folded into the import | Smaller PRs along ADR 0004's seams | yes | user |
| R61 | close M0 | Product web build renderer | `--wasm` (skwasm, without COOP/COEP headers at first) as a small `web-wasm-build` change, first in M1 | A later milestone; keeping the CanvasKit-only build | The grid spike: CanvasKit missed S4, skwasm passed with margin | yes | user |
| R62 | close M0 | New Next (M2) | One paragraph; split at M1's close | Agreeing M2's split now | Only Now is split | no | user |
| R63 | close M1 | Owner demo of a live SDE switch and offline search | Accept the live `3714173` → `3720952` switch started at the owner's request; the owner saw Settings and the change report and found Tritanium and Jita with the API stopped | Replay the switch manually | The live switch and disconnected app demonstrated the full outcome | yes | user |
| R64 | close M1 | Remaining pending strategy rows | Leave R35–R37, R39–R47, the Redis, vault and privacy-scope parts of R56, and R57 open | Settle them now | Defer to their milestones or triggers; R38 is settled separately | no | user |
| R65 | close M1 | M2 split | `esi-client-generator`, `esi-request-scheduler`, `esi-call-log`, `esi-token-vault`, `esi-sso` | Four changes with the log folded into the scheduler | Review call-log privacy and retention separately from scheduler correctness | yes | user |
| R66 | close M1 | M2 owner exit demo | Owner proves confidential server SSO and native solo PKCE with a scoped ESI call in each; owner-provided native registration | Owner proves server SSO only | Prove both deployment modes without deciding a shared client ID (R45) | yes | user |
| R67 | close M1 | New Next (M3) | One paragraph; split at M2 close | Agree the M3 split now | Let M2 prove the identity handoff first | no | user |
| R68 | close M1 | Privacy boundary before M4 | Assign scoped own-row and admin aggregate reads to `esi-call-log` and explicit policy and opt-in inputs to `esi-sso`. Keep cross-member sharing and the full consent lifecycle in M4 | Leave those M2 exit criteria unassigned | Meet ADR 0006 without expanding M2 into organisation consent | yes | user |
| R69 | close M1 | Static-data admin cutover | In `esi-sso`, replace the shared key with sign-in and required admin scope; public status stays readable | A sixth M2 change after `esi-sso` | Close the interim auth boundary in the change that supplies sign-in, as ADR 0015 requires | yes | user |
| R70 | close M2 | Remaining pending strategy rows | Leave R35–R37, R39–R47, the Redis, vault and privacy-scope parts of R56, and R57 open | Settle some now | None is due at M3. Owner, 2026-11-26: "Keep all open" | no | user |
| R71 | close M2 | M3 split | `member-accounts`, `character-transfer`, `org-tree-affiliation`, `member-states`, `groups-and-capabilities`, in that order | Four changes with the transfer folded into `member-accounts` | Review owner-hash transfer separately from account linking. Owner, 2026-11-26: "Five changes, in order" | yes | user |
| R72 | close M2 | M3 owner exit check | On the local stack: main and alt sign-in with real affiliation and member state, a group capability granted and removed, and an outside character with no member state | Sign-in and state only; adding a real character transfer | Proves accounts, states and capabilities live without a character sale. Owner, 2026-11-26: "Full check" | yes | user |
| R73 | close M2 | New Next (M4) | One paragraph; split at M3's close | Agree the M4 split now | Only Now is split. Owner, 2026-11-26: "Yes, one paragraph" | no | user |
