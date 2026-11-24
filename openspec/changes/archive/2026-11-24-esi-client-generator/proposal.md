# Proposal

## Why

Every M2 change after this one calls ESI. The scheduler reserves budget per rate group, the call log records routes, the token vault refreshes tokens, and SSO makes a scoped call. Each of them needs to know, for every route, its rate group, scopes, roles and cache behaviour, and needs typed requests and responses. ADR 0007 settles where that knowledge comes from: Kaname's own generator reads ESI's OpenAPI spec at one pinned compatibility date. Hand-written routes would let scopes and rate groups drift from what CCP enforces.

This is the first of five changes in **M2 - ESI platform and SSO**, with no prerequisite. It advances this agent-verified exit criterion:

- Kaname's generator reads the ESI spec at one pinned compatibility date and produces a reproducible typed client and route catalogue (rate group, scopes, roles and cache behavior). Recorded responses exercise the generated contract.

It advances no user-verified criterion. The owner's sign-in demo is judged when M2 closes, after `esi-sso`.

Constraining ADRs: 0007 (generated client, pinned date, bump PR with spec diff and contract tests, User-Agent and compatibility date pinned in one place, modules never call ESI directly), 0003 (pure-Dart shared packages, generators under `tools/`), 0002 (clean room, licence). Strategy rows R27 (own generator) and R28 (one scheduler for every call) bound it.

## What Changes

- **Pinned spec:** the ESI OpenAPI 3.1 spec at compatibility date **2026-11-19** is committed as a snapshot, next to a pin file that records the date, the source URL and the snapshot's SHA-256. `THIRD_PARTY_NOTICES` gets a hand-written CCP entry for it.
- **Fetch:** `mise run esi:fetch -- --date <YYYY-MM-DD>` is the only step that touches the network. It downloads the spec for that date, checks that the spec reports that date, and replaces the snapshot and pin file. A date bump is one PR carrying the spec diff, the generated diff and any updated contract fixtures. CI never fetches.
- **Generator:** a `kaname_tools esi` subcommand reads the snapshot and writes Dart for all 208 operations: typed request methods, typed models (including the spec's `oneOf` schemas and enums) and a route catalogue. The same snapshot always gives byte-identical output.
- **Drift check:** `esi:check` regenerates into a temporary directory and fails on any difference from the committed output, or when the snapshot does not match the pin file's hash. It joins `mise run check`, so it runs in CI on every OS and needs no network.
- **Package:** a new pure-Dart package, `packages/kaname_esi`, holds the generated client, the route catalogue and a small hand-written runtime: the transport interface, typed results and errors, and catalogue types.
- **No network of its own:** the client builds typed requests and parses typed responses through an injected transport. It sends nothing itself. `esi-request-scheduler` will supply the only transport that sends, so no module can reach ESI around the scheduler.
- **Contract tests:** Kaname-written synthetic exchanges (status, headers, body) that conform to the pinned schemas drive the generated client through a fixture transport. No CCP game data or character data enters the repository.

Out of scope: sending requests, rate budgets, the governor, caching, ETag storage and pagination loops (`esi-request-scheduler`); the call log (`esi-call-log`); tokens and SSO (`esi-token-vault`, `esi-sso`); the User-Agent value, which needs install contact details and is set by the sending transport; any module's use of ESI.

## Capabilities

### New Capabilities
- `esi-client-generation`: the pinned spec snapshot and its pin file, the deliberate fetch for a date bump, reproducible generation, and the offline drift check.
- `esi-client`: the generated typed client's contract: how requests are built (path, query, headers, body, compatibility date), how responses are parsed into typed results or typed errors, tolerance of values the pinned spec does not list, and the injected transport as the only way out.
- `esi-route-catalogue`: per-route metadata generated from the spec (method, path, rate group and its limit, scopes, required roles, cache behaviour, pagination), and lookup by route.

### Modified Capabilities
- `third-party-notices`: the hand-written sections also list the pinned ESI spec snapshot, and the check fails when its entry is missing.

## Impact

- `packages/kaname_esi` (new): the spec snapshot and pin file, generated client and catalogue, hand-written runtime, contract fixtures and tests.
- `tools/kaname_tools`: new `esi` subcommand (fetch, generate, check) and its tests; the notices check covers the snapshot.
- `mise.toml`: `esi:fetch`, `esi:generate` and `esi:check` tasks; `esi:check` and `test:esi` join `check` and `test`.
- Root `pubspec.yaml`: the new workspace member. Possibly new dependencies for the fetch (an HTTP client in `kaname_tools`), with `THIRD_PARTY_NOTICES` regenerated and the licence check passing.
- `THIRD_PARTY_NOTICES`: a CCP entry for the spec snapshot.
- Repository size: a spec snapshot of about 0.5 MB and generated Dart for 208 operations.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Pinned spec source

- **Choice:** commit the pinned spec JSON snapshot, with a CCP notice in `THIRD_PARTY_NOTICES`. The generator runs offline and reproducibly, and a date bump is a PR with a visible spec diff (ADR 0007).
- **Rejected:** commit only the date and the spec's SHA-256 and download at generation time (CI and the reproducibility check would need the network, and a bump PR would show only the generated diff). The EVE Developer License (§2.1, §7.1) neither expressly allows nor forbids putting the spec in a public repository. The generated client is derived from the spec either way.
- **Basis for publishing:** the spec is documentation of CCP Tools (EVE Developer License §1.5). Kaname is an Application distributed for the Purpose (§1.2, §1.13, §2.1(a) and (b)), as `README.md` already states. The same basis covers CCP's descriptions copied into the generated doc comments (D12). Attribution is the §7.1 proprietary notice in `THIRD_PARTY_NOTICES`. The owner confirmed this basis after design review round 1 (2026-11-23).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: the source of the ESI contract, and a licence question.
- **Chosen by:** user (2026-11-23; basis confirmed after review round 1)

### S2: Route coverage

- **Choice:** generate the typed client and the route catalogue for all 208 operations at the pinned date.
- **Rejected:** catalogue for every route but typed methods only for the routes M2 needs, with each module extending an allowlist (a hand-kept list that drifts); GET routes only (later modules write to ESI).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: what every module can call.
- **Chosen by:** user (2026-11-23)

### S3: Recorded responses

- **Choice:** Kaname-written synthetic exchanges (status, headers, body) that conform to the pinned schemas. No CCP game data or character data enters the repository, as with M1's synthetic SDE fixtures.
- **Rejected:** committing live recordings of public routes (CCP data in the repository, and recordings go stale with each bump).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: how every bump's contract tests are written.
- **Chosen by:** user (2026-11-23)

### S4: Network boundary

- **Choice:** the generated client has no network transport of its own. It builds typed requests and parses typed responses through an injected transport interface. `esi-request-scheduler` supplies the only transport that sends. Tests use a fixture transport.
- **Rejected:** a plain HTTP transport now, which the scheduler would wrap later (a way to reach ESI around the scheduler, against ADR 0007).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: the boundary every ESI call crosses.
- **Chosen by:** user (2026-11-23)

### S5: Compatibility date

- **Choice:** pin 2026-11-19, the newest date ESI listed on 2026-11-23.
- **Rejected:** 2025-12-16, an older date that has been out longer (M2 would start on an outdated contract).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: the contract every module codes against until the next bump.
- **Chosen by:** user (2026-11-23)

### S6: Package placement

- **Choice:** a new pure-Dart package, `packages/kaname_esi`, for the generated client, the catalogue and the hand-written runtime. The generator is a `kaname_tools esi` subcommand, like the tokens and l10n generators.
- **Rejected:** a separate generator package, `tools/kaname_esi_gen` (one more workspace member for one command); the client inside `kaname_core` (mixes generated code of 208 routes into the domain core).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: the package every server, solo and job import uses.
- **Chosen by:** user (2026-11-23)

### S7: Generated output

- **Choice:** commit the generated Dart. `esi:check` in `mise run check` regenerates into a temporary directory and fails on any difference, like `tokens:check` and `l10n:check`.
- **Rejected:** generation at build time with `build_runner`, output not committed (generated code invisible in review, and every consumer's build depends on the generator).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: how every bump is reviewed.
- **Chosen by:** user (2026-11-23)

### S8: Date bump

- **Choice:** `mise run esi:fetch -- --date <YYYY-MM-DD>` is the only network step. It replaces the snapshot and writes the pin file (date, source URL, SHA-256); then `esi:generate`. CI never fetches.
- **Rejected:** no fetch command, with the spec downloaded by hand per a README note (easy to fetch the wrong date or to leave the pin and the snapshot inconsistent).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: the bump procedure ADR 0007 requires.
- **Chosen by:** user (2026-11-23)
