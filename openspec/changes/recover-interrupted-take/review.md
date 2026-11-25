# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 returned APPROVE_WITH_CHANGES with one Moderate finding. M1: if closing a take advanced the holder generation, lost-ack `release` and `joinStandalone` retries would be stranded. It also made three suggestions: S1 on the wire contract and typed outcomes, S2 on closure failing an in-flight sign-in, and S3 on deterministic race tests.
- **Reviewer:** cross-model CLI (Claude Code, `claude-opus-5-5`)
- **Reviewed:**
  - Artifacts (full): `openspec/changes/recover-interrupted-take/proposal.md:1-58`, `design.md:1-203`, `specs/esi-sso/spec.md:1-36`, prior `review.md:1-86`
  - Template: `openspec/schemas/specwright/templates/review.md:1-38`
  - Rules: `AGENTS.md:1-63`. Skills read: `serverpod-models` (1-193), `serverpod-migrations` (1-81), `serverpod-testing` (1-70). I did not re-read the other named skills. Round 1 covered pattern matching and unit tests, and this revision adds no new app-side mechanism beyond D1's typed interface.
  - Server: `server/kaname_server/lib/src/esi/sso_handoff.dart:1-263`, `server_sso_grants.dart:1-306`, `sso_route.dart:100-189,400-557`, `sso_sessions.dart:1-60`, `sso_holder_row.spy.yaml:1-13` (C5 destination)
  - ADR: `docs/adr/0017-esi-holder-handoff.md:1-21`
  - New citations checked against the source: D2 Rejected (`sso_handoff.dart:159-176,195-203`; `server_sso_grants.dart:54-56,163-169`), D4 (`sso_route.dart:422-427`) and the 404 body (`sso_route.dart:167,548-555`). All match.

**Rechecked against the source:**

- **M1: release retry.** `release` returns `released` only if `row.generation == generation`, the digest matches and the phase is `serverReserved`/`serverHeld` (`sso_handoff.dart:162-167,221-222`). Under the revised D2, closure changes only `takeClosures`. The holder generation, phase and digest stay the same, so round 1's sequence now ends with A's retry returning `released`.
  - Release commits at `g+1` with Pa, the ack is lost, server sign-in runs, and B's intent closes at epoch `g+1+c`. The row is then still `serverHeld`, at generation `g+1`, with digest Pa.
- **M1: join retry.** `joinStandalone` requires `generation == 1` plus a matching digest in a released phase (`:198-203`). Closure leaves all three unchanged, so the join retry also returns `released`.
- **M1: release and join contracts unchanged.** No release, join or sign-in predicate is relaxed. This matches the owner's preference.
- **Round 1 S2 is moot.** Sign-in records `assignmentGeneration` and `assignmentPhase` and rejects activation if either changed (`server_sso_grants.dart:53-56,163-169`). Closure changes neither, so an in-flight sign-in is no longer failed. Activation writes `observed.copyWith(...)` inside `_gate.run`, from a row read in the same gate (`:172,210-218`), so it keeps the current `takeClosures`. Take holds `pause`, then checks `isMutating` (`sso_handoff.dart:65-67`; `sso_sessions.dart:30,41-51`), so the take path and activation still exclude each other.
- **C5 placement.** C5 is in Carried constraints and points to `sso_holder_row.spy.yaml SsoHolderRow`. That file already has a `###` doc comment, so the destination exists. Flow & State Gaps bullet 2 contains both deterministic regression cases: "Test both retries with a closure between sign-in and retry". It also requires event ordering through explicit awaits or the dispatch barrier, with no elapsed-time checks (AGENTS.md).
- **The epoch is still a single-advance proof.** `e = generation + takeClosures`, and each component only increases.
  - Each epoch advance adds exactly 1: an acceptance (legacy `_cas` at `:89-102`, or the new start) adds 1 to the generation and replaces the digest, and a closure adds 1 to the offset.
  - Park, release and activation change neither component (`:125-133`, `:169-175`; `server_sso_grants.dart:210-218`). Inserts by join and activation start at generation 1 with a null offset, which counts as zero. Nothing deletes a row.
  - So each epoch value marks exactly one window, and `e+1` means exactly one advance.
  - A closure leaves `serverHeld` with the earlier digest, which is null or a different proof's. Either way it falls into the table's "digest does not match → notAccepted" row (`_matches` treats a null digest as a mismatch, `:224-227`). The rare case where an old digest matches lands in "matching digest in a released phase → unknown".
  - Only acceptance leaves `serverHeld`, so a closed epoch can never later be in `toDevice`/`deviceReserved` with a matching digest.
- **Delayed start and reconcile still cannot both win.** Start requires `serverHeld` at exactly `e`, and both writes CAS on ID, phase, generation and offset.
- **Accepted takes can still resume.** After start accepts P at `e`, the row is `toDevice` at generation `g+1` with digest P, so its epoch is `e+1`. Reconcile then matches "digest matches, phase `toDevice`/`deviceReserved`" and resumes park or returns the reservation. A closure needs `serverHeld` at `e`, so it cannot hit an accepted row.
  - The reservation reply carries the holder generation (`_reservation`, `:232-235`) next to the echoed epoch. Later `release` therefore still compares against the holder generation.
- **Signed 64-bit boundary.** `prepare` rejects `e >= 2^63-1`, so the advanced epoch `e+1 ≤ max`. The offset is at most `e-1`, since generation is at least 1, so incrementing it cannot overflow. The sum is guarded before it is computed. An unrepresentable epoch counts as unknown, which fails closed.
  - A legacy acceptance can still push the sum past the maximum, because the existing guard checks only the generation (`:78`). The design covers this: that state is "ineligible" for the new route and never terminal.
  - Epochs use canonical decimal strings. Dart VM `int.tryParse` returns null outside the int64 range.
- **New facts are consistent.** Proposal Impact ("one additive column"), C2, State & Ownership, Resource Bounds and the sequence diagram all describe closure as advancing only the offset. The 404 compatibility signature is exactly `_failure(404)` → `{"status":"signInFailed"}`. A server with SSO disabled returns the same body for the legacy route, so treating it as legacy is harmless.

## Findings

### Critical (blocking)

None.

### Moderate

None new. Round 1's M1 is resolved by the revised D2 and C5 (see Rebuttals).

### Suggestions

**S1. Treat a null `takeClosures` as zero inside the SQL CAS.**

D2 makes the column nullable and says existing rows count as zero. D2 also says both writes check the closure offset in the CAS. Every row written by existing code has a null offset (`sso_handoff.dart:205-213`, `server_sso_grants.dart:198-208`). A plain `"takeClosures" = $n` predicate never matches NULL, so every acceptance and closure on those rows would miss and return `pending`. This fails closed, and the cheapest server test would catch it. Two ways to remove the trap:
- In D2, after "Both writes check row ID, phase, holder generation and closure offset in the CAS", add: "Compare the offset as `COALESCE(\"takeClosures\", 0)` and write `COALESCE(\"takeClosures\", 0) + 1` on closure."
- Alternatively, declare the field `takeClosures: int, default=0` (`serverpod-models`: `default=` sets both the Dart and DB default). The migration then fills existing rows and the null case disappears.

**S2. Make the ADR line state what the design adds.**

The ADRs section says the protocol "uses ADR 0017's existing holder generation and proof model". The take-intent fence now also uses a server-only closure offset. Suggested wording: "To record during apply: none. The take-intent fence adds a server-only closure offset beside ADR 0017's holder generation and proof digest. That fence and its recovery boundary are unchanged."

**S3. State the expected result of the regression cases.**

In Flow & State Gaps bullet 2, after "Test both retries with a closure between sign-in and retry", add: "Each retry returns `released` and leaves the holder generation, phase and digest unchanged. Run these as `serverpod-testing` tests against the real holder table, because the fence is a SQL CAS."

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **(M1)** No edit is outstanding. Round 1's text (digest-and-phase retry acknowledgement at any generation) is superseded by the revised D2 and C5. The new design keeps the existing `release` and `joinStandalone` predicates and moves closure onto the additive `takeClosures` offset. I rechecked this against the source in this round.

CHANGES_APPLIED: yes

## Rebuttals

- **M1: rebutted by the author with a different design (revised D2 Choice/Rejected, C5, Flow & State Gaps bullet 2). Accepted by reviewer.**
  - Closure advances only `takeClosures`, and the take epoch is holder generation plus closure offset. Legacy and new acceptances still advance the holder generation and replace the digest, so they advance the epoch too.
  - The release and join retry predicates (`sso_handoff.dart:162-167,198-203`) and the sign-in generation check (`server_sso_grants.dart:163-169`) are unchanged. Neither stranding sequence from round 1 can happen.
  - The proof guarantees that passed round 1 still hold:
    - single-advance disambiguation at `e+1`
    - no `notAccepted` after commit
    - mutual exclusion between start and reconcile
    - accepted takes can resume
  - The signed 64-bit boundary is guarded. Both deterministic regression cases are in the design for the tasks stage.
  - Keeping the existing contracts is the narrower fix and matches the owner's #40 scope. Round 1's proposal would have relaxed them.