# Review

## Metadata

- **Round:** 49. This is a focused re-review of the owner-approved D5/C37 correction and the round-48 fixes (F1–F3) only. Unchanged decisions are not reopened, and the uncommitted Dart code was not audited.
- **Read:** `design.md` D4 (L114–140), D5 (L142–169), D21 (L353–364), D22 (L366–372), D26 (L405–418), A7 (L532), C18/C22/C37 (L553, L555, L568), Failure & Visibility (L724–753); `specs/static-data-builds/spec.md` "Switch and rollback records follow their outcome" (L36–53); `specs/static-data-admin/spec.md` L470–472 and L612–622 (to check for contradictions); `tasks.md` 5.5 (L422), 5.8 (L425) and the test-map rows L113, L148–149, L171; `review.md` (round 47; round 48 is taken from the brief); serverpod-testing SKILL L88–101 and serverpod-database SKILL L97–105.

## Findings

### F1 (round 48): the in-flight original is tested against a reconciliation that is visibly waiting. Passes.

- **Where:** `tasks.md` 5.5.
- The task now requires "dedicated connections and no harness rollback". It pauses "the original rollback after it takes the row lock", checks that "reconciliation blocks on that row", and only then lets the original commit or abort.
- It then asserts "each branch's exact end, records, build pair and revision".
- This matches serverpod-testing L91: concurrent transactions need `RollbackDatabase.disabled`.
- A7 (L532) now names task 5.5 as testing the real writer and reconciliation with the commit in flight. The assumption and the task agree.

### F2 (round 48): the failed record uses the build pair read under the original lock. Passes.

- **Where:** D5 L151, C37 L568, `tasks.md` 5.5.
- D5 says the record names "the active and previous builds read under the original lock before the attempt, never builds read on the fresh connection (C22)".
- C37 says "for the builds read under the original job lock".
- Task 5.5 says "for the original build pair".
- This is consistent with C22's rule that a job that has lost its connection makes no claim from a fresh read.

### F3 (round 48): the failure-matrix row for a lost rollback acknowledgement is updated. Passes.

- **Where:** Failure & Visibility L741.
- The row now says: end X `rollbackFailed` together with its failed record when X is open, let the row decide when X has already ended, and otherwise leave it to the settler's `outcomeUnknown` with no record.
- This agrees with D5 L151 and D26 L412. Row L742 ("statement fails") and row L749 ("job connection lost around a commit") don't conflict with it.

### F4: Each case was checked against the fence. Passes.

- **Committed.** The original's first statement ends X (D21 L358), so its commit holds or has released X's row with X ended. Reconciliation either waits and then re-checks (A7), or finds X already ended. Either way it updates 0 rows, inserts no record, and returns the row's `rolledBack`. This is the admin spec's "Commit acknowledgement lost" (L470–472).
- **Aborted, X open.** Reconciliation updates 1 row and commits the end and the failed record in one transaction. The original can no longer commit: any later first statement finds X ended and aborts (D21). The builds and revision are untouched and nothing is pruned (D5, C37).
- **In flight.**
  - Past its first statement: reconciliation waits on the row lock, then behaves as in the committed or aborted case. Task 5.5 tests both.
  - Not yet at its first statement: reconciliation wins and the original's fence later aborts it.
- **Already ended (including by recovery).** 0 rows are updated and the row decides. A missing or unreadable row gives `unconfirmed`, never success (D5 L151). The settler's fallback is unchanged (D26 L412).
- **Insert fails inside reconciliation.** The end rolls back with it, so X stays open and the settler ends it `outcomeUnknown`. This matches admin "Failure cannot be recorded" (L616–618) and builds "Failed record cannot be stored" (L43–45). There is no state with a failed record but an open X, or the reverse.
- **Scope.** C37 limits the exception to "an admin rollback only". The development task's own-session evidence rule (D5 L165, builds L47–49) and D4's ban on failed switch records after the lock is lost are unchanged. No API deadlines changed. Pre-existing endpoint and settler behaviour stays as approved.

### F5: No direct contradictions. Passes.

- These now agree with each other: D5, C37, the builds requirement (L37), admin "Statement fails", "Failure cannot be recorded" and "Rollback cannot be confirmed" (L612–622), D26's `unconfirmed` handling, and C18's "every write that ends one is conditional".

### Advisory (non-blocking)

- **AD1 (D5 L151): reconciliation can wait indefinitely.** If the old backend has run the first statement and is left idle in its transaction with a half-open socket, reconciliation has no lock timeout and waits until Postgres drops that backend. The job doesn't reply in the meantime, and C34 stops new jobs being sent. This is the same class as the already-accepted "Running job loses its lock and hangs", so it is not new risk. Two possible fixes:
  - Force-close the original connection before reconciling on a fresh one, so the backend aborts promptly.
  - Use a `SET LOCAL lock_timeout` and reply `unconfirmed` when it expires.
- **AD2 (C37 L568): wording.** "after its first statement conditionally ends that exact operation" is clear enough. Adding "and that statement updated one row" would make the doc comment match D5's "Only if this updates one row" word for word.
- **AD3 (`tasks.md` 5.5): make "blocks on that row" observable.** Assert it from a third session, for example `pg_blocking_pids(<reconciliation pid>)` contains the original's pid, or `pg_stat_activity.wait_event_type = 'Lock'`. A timing gap alone shouldn't count as proof.
- **AD4 (`tasks.md` 5.5): add the "reconciliation wins" order.** Hold the original before its first statement, let reconciliation commit, then release the original. Assert that its fence aborts it: no rollback, no revision bump, and no second record. D21 already guarantees this, but testing it with the real rollback writer would complete the in-flight cases.
- **AD5 (spec): no named scenario for the new branch.** There is no scenario for "connection lost, rollback aborted, X open → ended 'rollback failed' with a failed record for the original pair". Admin "Statement fails" requires Postgres to stay reachable, and "Rollback cannot be confirmed" covers the unreadable case. Task 5.5 tests the branch, so this only affects traceability. A short scenario, or adding the new branch to "Statement fails", would map it.
- **AD6 (Failure & Visibility L741): wording.** "if the attempt aborted and X is open" reads as if the job knows the abort beforehand. "if the conditional end updates X" describes what the fence actually decides.

## Verdict

The amendment correctly makes reconciliation's conditional end of X the only way a failed admin-rollback record can be written without the job lock. That end is atomic with the record, uses the build pair from the original lock, and changes no builds, revision or pruning. All round-48 findings are addressed, and the committed, aborted, in-flight and already-ended cases all resolve through the row fence. Task 5.5 tests them adequately. The development-task rule and the D26 fallback are unchanged.

VERDICT: APPROVE
CHANGES_APPLIED: n/a

## Required Changes

None.

## Rebuttals

- **Not testing the missing or unreadable row in 5.5:** I accept this. It is already covered by "Rollback cannot be confirmed" (test-map L149) and by the settler's `unconfirmed` handling (D26), and the amendment doesn't change that path.
- **The unbounded wait (AD1) is not a Required Change:** it doesn't affect correctness, because the fence still orders the outcome. Its liveness impact matches the already-approved hung-job model (`workerStuck`, then restart recovery).