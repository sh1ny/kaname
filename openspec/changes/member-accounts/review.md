# Review

## Metadata

- **Round:** 6
- **Prior round:** REVISE. Round 5 found that a backward clock step before the first seal could change eligibility, that a calculation or cache hit could return a superseded window, that recovery could display stale membership while unlink was unsettled, and that roster requests could queue for bearer authentication before reaching the page limit. [Round 5](openspec/changes/member-accounts/review.md)
- **Reviewer:** cross-model CLI (Codex)
- **Reviewed in round 6:** Proposal, design, round‑5 review, all three delta specs, M3 roadmap, architecture, applicable current specs and in-force ADRs, Riverpod guide, Ember guidance, and project skills. Checked the relevant SSO, session, grant, handoff, scheduler, call-log, static-data admission, API ingress and Flutter source. Verified 61 cited source ranges against tracked paths and checked path components for symlinks before reading the source. No invalid citations found. No files were written, and no builds or tests were run.
- **Round‑6 recheck:** Verified the two Required Changes against D15–D18 and the ESI call-log and member-accounts delta specs.

## Findings

### Critical (blocking)

None. The design fits the M3 account scope. Postgres owns membership and revocation, ESI and admin authority follow the signing character, and Settings keeps viewer-scoped pages in memory under ADR 0010. The tradeoffs for restrictive account retirement, sparse history paging and conservative aggregate qualification are explicit. [M3 roadmap](openspec/roadmap.md#now-m3---identity-and-access) · [State and ownership](openspec/changes/member-accounts/design.md#state--ownership-full) · [Resource bounds](openspec/changes/member-accounts/design.md#resource-bounds-full) · [ADR 0010](docs/adr/0010-flutter-app-state.md)

### Moderate

1. **The durable call-log contract leaves the prune transaction implicit.** D15 and D16 require a single database UTC sample and an atomic seal advance when pruning would touch the latest sealed inputs. The delta requires safe output and includes a restart scenario, but does not require the prune batch to roll back when it cannot advance the seal. The current pruner deletes independently using an application-clock cutoff. Retaining that shape could leave the durable seal pointing at deleted inputs after a crash. The server would then have to suppress that window or risk returning incomplete totals. The delta also retains the unconditional wording that counts update one minute after midnight, although D16 makes that the eligibility boundary and requires a successful seal before publication. [D15–D16](openspec/changes/member-accounts/design.md#d15-persist-the-latest-sealed-window) · [Call-log delta](openspec/changes/member-accounts/specs/esi-call-log/spec.md) · [Current prune](server/kaname_server/lib/src/esi/esi_call_log_store.dart#L253)

2. **The recovery spec leaves the exact-session acknowledgment underdefined.** D18 specifies the original origin, the exact bearer and confirmation of committed deletion or absence. The delta says to confirm revocation and sign in again, but does not state what counts as confirmation or require a retry after the deletion commits and its reply is lost. The current server route deletes by bearer digest and replies `signedOut`. The Flutter adapter discards that reply. Reusing the adapter as written would leave the recovery notifier without evidence to distinguish a committed deletion from a failed request. Treating an expired or unauthenticated response as proof of deletion could also resume reads while an unlink that already passed its session check remains unsettled. [D18](openspec/changes/member-accounts/design.md#d18-revoke-the-acting-session-after-an-ambiguous-unlink) · [Recovery delta](openspec/changes/member-accounts/specs/member-accounts/spec.md#requirement-an-ambiguous-unlink-requires-session-recovery) · [Server sign-out](server/kaname_server/lib/src/esi/sso_route.dart#L384) · [Exact digest deletion](server/kaname_server/lib/src/esi/sso_sessions.dart#L203) · [Flutter adapter](app/lib/esi_sso/data/connected_account.dart#L92)

### Suggestions

- Exercise D19 through the real HTTP ingress using the effective native and web paths. Caddy strips `/api/` before proxying web requests, and the server already installs API middleware before startup. An endpoint-only test would miss a route mismatch that lets the fifth request reach authentication. Hold the first four lookups, count calls to the authenticator, and verify that a slot becomes available after failed auth settles. The SQL statement budget starts after a connection is acquired. If the existing pool acquisition deadline is verified, name it separately from the client connection timeout. [D19](openspec/changes/member-accounts/design.md#d19-admit-roster-rpc-before-bearer-database-work) · [Caddy API routing](deploy/Caddyfile#L61) · [Server middleware registration](server/kaname_server/lib/server.dart#L57) · [Current statement budget](server/kaname_server/lib/src/esi/esi_call_log_store.dart#L132)
- Carry the D17 barrier scenario through a computation owner, a joined waiter and a cache hit. Also admit one response before advancing the seal and deliver it afterward. That case verifies the chosen distinction between response admission and network delivery order. [D17](openspec/changes/member-accounts/design.md#d17-recheck-the-seal-at-response-admission) · [Superseded-response scenario](openspec/changes/member-accounts/specs/esi-call-log/spec.md#scenario-a-newer-seal-supersedes-a-pending-aggregate-response)

### Outside the approved threat model (non-blocking)

None.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

Both Required Changes are present in the delta specs.

## Required Changes

1. In the call-log delta, revise “Privacy-scoped call-log reads” and “Stable closed periods” to say that a five-day UTC window becomes eligible one minute after midnight by database time and can be published after its seal commits. Under “Released aggregate windows cannot go backward,” require prunes that would delete the latest sealed inputs to advance the seal under the exclusive release lock in the same transaction, using one database UTC sample for eligibility and retention. Require the batch to roll back if it cannot advance the seal. Extend the prune scenario to assert that failure before commit preserves both the prior seal and its inputs, and that restart after commit cannot publish the superseded window.

   **Applied.** Database UTC governs eligibility before the seal, and “Stable closed periods” first shows the new window after the seal commits. The prune requirement specifies one database UTC sample for eligibility and retention, the exclusive release lock, a single transaction, and rollback if the seal cannot advance. The scenario asserts that rollback preserves the prior seal and its receipts and that restart after a successful commit cannot publish the superseded window. [Eligibility and publication](openspec/changes/member-accounts/specs/esi-call-log/spec.md#requirement-privacy-scoped-call-log-reads) · [Seal and prune](openspec/changes/member-accounts/specs/esi-call-log/spec.md#requirement-released-aggregate-windows-cannot-go-backward)

2. In the member-accounts delta under “An ambiguous unlink requires session recovery,” require a definitive acknowledgment from the original server of committed deletion or absence of the exact acting session. State that the same bearer may retry revocation after a lost reply and that an auth, database or transport failure leaves the views uncertain. Add a scenario that drops the acknowledgment after deletion commits, retries with the same bearer, confirms absence, and resumes the views only after fresh sign-in. Assert that another live session stays valid.

   **Applied.** Recovery uses the exact acting bearer at the original server and requires confirmation of committed deletion or absence. Inconclusive responses, including auth, database and transport failures, leave both views uncertain. The lost-acknowledgment scenario confirms absence on retry with the same bearer, keeps another live session valid, and resumes the views only after fresh sign-in. [Recovery requirement](openspec/changes/member-accounts/specs/member-accounts/spec.md#requirement-an-ambiguous-unlink-requires-session-recovery) · [Lost acknowledgment](openspec/changes/member-accounts/specs/member-accounts/spec.md#scenario-revocation-commits-but-its-acknowledgment-is-lost)

CHANGES_APPLIED: yes

## Rebuttals

- **Pre-seal backward clock step:** Resolved by the owner's accepted cutoff semantics. D16 and its delta scenario use current database time until the first durable seal. An unsealed crossing does not decide eligibility. The watermark protects already sealed windows across the permitted rollback and restart. [Threat model](openspec/changes/member-accounts/design.md#threat-model) · [D16](openspec/changes/member-accounts/design.md#d16-define-the-cutoff-before-the-first-seal)
- **Superseded aggregate result:** Fixed. D17 gives each calculation owner, waiter and cache hit a fresh durable-seal check at response admission. A newer committed seal or a failed check yields unavailable without rows. [D17](openspec/changes/member-accounts/design.md#d17-recheck-the-seal-at-response-admission)
- **Recovery reads racing unsettled unlink:** Fixed in D18. The acting app clears and fences both views. Revocation of the exact session either waits for an unlink holding that row lock or prevents a delayed unlink from passing the session check. Fresh sign-in follows definitive acknowledgment. The required edit preserves that contract in the delta. [D18](openspec/changes/member-accounts/design.md#d18-revoke-the-acting-session-after-an-ambiguous-unlink)
- **Roster authentication ahead of admission:** Fixed. D19 takes one of four ingress slots before bearer database authentication and reuses that slot for page work. The per-account cap applies after authentication, and the page snapshot still checks the exact live session. The fifth-request scenario asserts zero additional bearer database lookups. [D19](openspec/changes/member-accounts/design.md#d19-admit-roster-rpc-before-bearer-database-work) · [Roster admission delta](openspec/changes/member-accounts/specs/member-accounts/spec.md#requirement-roster-reads-do-not-queue)