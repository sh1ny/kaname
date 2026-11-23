# Review

## Metadata

- **Round:** 44. This is a targeted re-check of the Required Changes from round 43, not a new design pass and not a pre-ship review.
- **Prior round:** 43 (Codex cross-model review, `APPROVE_WITH_CHANGES`, `CHANGES_APPLIED: no`).
- **Route:** Claude
- **Artifacts read:**
  - `openspec/changes/static-data-settings/review.md` (round 43's findings and Required Changes)
  - Working-tree `openspec/changes/static-data-settings/design.md`: D4 and D5 (L115–166), D26–D31 (L405–469), A11 (L528), C30 and C32 (L563, L565), the failure table (L726–755) and Flow & State Gaps (L776–794)
  - Working-tree `openspec/changes/static-data-settings/tasks.md`: tasks 2.7 (L392), 5.4 (L424), 5.5 (L425) and 8.4 (L459)
  - `openspec/changes/static-data-settings/specs/static-data-admin/spec.md`: the stalled-writer scenario (L262), the replay and admission scenarios (L341–435) and the rollback answers (L578–626)
  - `.claude/skills/serverpod-testing/SKILL.md`, `.claude/skills/serverpod-database/SKILL.md`, `.claude/skills/serverpod-webserver/SKILL.md` and `.claude/skills/dart-add-unit-test/SKILL.md`
  - I read only tracked repository files and edited nothing.

## Findings

### Required Change 1: D31 copied chunks and full Content-Length — applied

- `design.md:463` now reads: "The body streams independent copies of up to 64 KB and declares the full encoded answer's `Content-Length`." This is the replacement text that round 43 asked for.
- The phrase "chunk views" no longer appears anywhere in `design.md`.
- The preceding paragraph (`design.md:462`) also requires "a stream of 64 KB copies, never views of that array". The two paragraphs no longer contradict each other.
- The parts round 43 said to keep are still there:
  - The stalled-writer scenario: `specs/static-data-admin/spec.md:262` says "at most that one 64 KB copied chunk, not its encoded answer".
  - Task 8.4: `tasks.md:459` says "64 KB copied chunks".
- An implementer can no longer reuse the bundle writer's `sublistView` pump by following D31.

### Required Change 2: admission and forward-switch summaries and the lost-insert flow — applied

- **"Admission store slow" row (`design.md:748`):**
  - If the store did not start, the call answers "update failed" or "rollback failed" with "Postgres unreachable".
  - If the store started, no worker request is sent. Update now answers "no answer yet" and rollback answers "outcome unknown", and the app follows X.
  - The settler "preserves an unexpired ended X, else applies D26's conditional upsert".
  - This matches D4 (L119), D5 (L153), D19 and D26's upsert rules (L411).
  - It also matches the replay scenario: `spec.md:381` says the call answers "outcome unknown" and X keeps its stored success.
- **Lost-acknowledgement flow (`design.md:789`):** it uses the same wording: no worker request, "no answer yet" or "outcome unknown", the app follows X, and the same settler rule. It adds that the slot is freed after settlement. The contradiction that would have reported failure for an X that already succeeded is gone.
- **"Forward switch, commit acknowledgement lost" row (`design.md:738`):**
  - A reread counts as evidence only "on the original usable connection still holding the lock".
  - After the lock is lost, the settler decides an update now from X's operation row.
  - Daily and start-up checks return `switchUnconfirmed` and attempt a "switch outcome unknown" check record, with no failed switch record.
  - This matches D4 at `design.md:131–133`.

### Required Change 3: tasks 5.4 and 5.5 make the owner-level fault checks explicit — applied

- **Task 5.4 (`tasks.md:424`)** now requires all three checks:
  - The real TCP proxy withholds the reply to an in-flight settle statement.
  - The test verifies that "the settler token returns within 20 s".
  - The test verifies that "an eligible retry settles X once the proxy heals".

  The 20-second limit matches D26 (L413) and C30.
- **Task 5.5 (`tasks.md:425`)** now requires:
  - The real proxy withholds the recovery update's reply "until the attempt is abandoned before sending `COMMIT`".
  - A check "from another session that the abandoned update does not commit".
  - A check that "admission stays closed until the successor's own commit returns".

  These match D26's start-up recovery text (L414) and D27 (L424).
- **What round 43 said to keep is still there:**
  - Task 5.5 still lists the post-`COMMIT` row "Recovery commit lands after abandonment".
  - Task 2.7 (`tasks.md:392`) still checks that the 3 s `connectTimeout` bounds opening on a silent proxy.
- **A11 still fits D26's policy.** A11 (`design.md:528`) records two observations:
  - Graceful `close()` waits for the in-flight query, which can still succeed.
  - `close(force: true)` fails the pending query.

  A11 says only forced close is used for abandonment. D26 (L413) and D27 already require `close(force: true)`, a 5 s cleanup wait and one logged orphan. Task 2.7 now probes both close modes. A11's last sentence correctly points the owner-level checks to the settlement and recovery tests.

### Non-blocking observations (outside round 43's required scope)

- The "Operation insert" row (`design.md:731`) still says the settler upserts X "unless X already ended". D26's upsert actually deletes and replaces an ended row older than 30 days. Row 748 and the flow at L789 now use the more precise wording "preserves an unexpired ended X". Aligning row 731 with that wording would be a small consistency edit, but nothing in the design contradicts it.
- Round 43 suggested scoping the query failure in D26's retry paragraph to the forced-close probe. In D26 (L413), "after which its futures complete with an error (A11)" is now followed directly by "Abandonment calls `close(force: true)` and waits for it at most 5 s; if it has not returned, the token is released anyway". So the forced-close policy and the token-return bound are both stated. The suggestion is adequately resolved.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

All three of round 43's Required Changes are in the working-tree `design.md` and `tasks.md`, and they agree with the `static-data-admin` spec delta. No Critical issue remains from round 43's findings.

## Required Changes

CHANGES_APPLIED: yes

1. D31 copied chunks and full `Content-Length`: verified at `design.md:462–463`. It matches `spec.md:262` and task 8.4.
2. The admission store, lost-insert and forward-switch summaries: verified at `design.md:738`, `design.md:748` and `design.md:789`. They match D4 (L119, L131–133), D5 (L153), D19 and D26 (L411–412).
3. The owner-level fault checks: verified in tasks 5.4 and 5.5 at `tasks.md:424–425`. The post-`COMMIT` case and task 2.7's silent-handshake check are still there.

## Rebuttals

- None. Round 43's findings are resolved as described above. Its rebuttals on A11 and task 2.7, on recovery ordering and ADR alignment, and on the round 42 follow-through still hold against the working tree.