# Review

## Metadata

- **Round:** 5
- **Prior round:** APPROVE_WITH_CHANGES. Two required changes remained, covering A1's abandoned-claim test and scheduler outage coverage on both backends.
- **Reviewer:** Codex, fresh read-only context
- **Reviewed:** The supplied `review.md`, `design.md`, and the `esi-request-scheduling` and `org-affiliation` delta specs. Verified the Serverpod 4.1.2 pin in the tracked `server/kaname_server/pubspec.yaml`.

## Findings

### Critical (blocking)

None.

### Moderate

1. **A1 is resolved.** It requires injected registrar time and synchronization on a claim or dispatch event. The test must assert that the recovered slot starts at most one sweep and that the next hourly slot reaches dispatch without restart. If one-shot liveness fails, A1 requires D9 to be reopened before apply and to specify how the same registrar recovers the claim without starting a second sweep. Pinned-source inspection and execution checks remain apply prerequisites.
2. **Scheduler outage coverage is resolved.** The scheduling delta explicitly requires both the shared affiliation outage and the two-route `503` scenarios to run against Redis and in-process state.
3. **D6 reflects the delegated approval.** It allocates order from the observation table's generated `BIGSERIAL` sequence before submission and uses a conditional upsert so only a valid observation with a higher order replaces a stored observation. A logical restore preserves the sequence position with the table, allowing fresh orders to advance past restored orders. The affiliation delta preserves the same ordering contract.

### Suggestions

None.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

Both required changes from round 4 are applied.

CHANGES_APPLIED: yes

## Rebuttals

None.