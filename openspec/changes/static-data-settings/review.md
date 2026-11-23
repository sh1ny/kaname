# Review

## Metadata

- **Round:** 47. This is a targeted full Specwright design review of A13 and task 2.9 only. Round 46 approved the rest, and no finding outside this amendment is reopened.
- **Prior round:** 46 (Claude, APPROVE_WITH_CHANGES, no Required Changes outstanding).
- **Route:** Claude
- **Artifacts read (tracked files only; none edited; no caches or untracked paths):**
  - `openspec/changes/static-data-settings/design.md`: A13 (L530), plus D28 (L431–442) to check the token rule.
  - `openspec/changes/static-data-settings/tasks.md`: task 2.9 (L394), with 2.7 and 2.8 (L392–393) for context.
  - `openspec/changes/static-data-settings/review.md` (round 46).
  - `.claude/skills/serverpod-database/SKILL.md` and `.claude/skills/serverpod-testing/SKILL.md` (transaction use; `RollbackDatabase.disabled` at L91; `configOverride` at L157).
- **Evidence taken as given:**
  - A real Serverpod 4.1.2 diagnostic confirmed backend pid 910563 twice as reusable. It then entered a real transaction on that backend and ran `pg_sleep(10)` with a 1 s driver timeout. The call failed with `DatabaseQueryException` reporting query cancellation, and the next borrower got backend 910564.
  - Pinned source explains why: Serverpod wraps PostgreSQL exceptions inside the callback, its own non-`PgException` escapes, and the pool discards that connection.
  - The user has already approved checking for safe reuse or replacement, rather than requiring reuse.

## Findings

### F1: The replacement outcome is expressed (passes)

- A13 (L530) now separates the two layers:
  - The driver says "can reuse a connection after a clean cancellation".
  - Serverpod "maps a PostgreSQL query error to `DatabaseQueryException` inside its transaction callback, and the pool discards that connection when the error escapes."
- This matches the pinned-source explanation.
- A13 records the observation: "Apply observed a replacement backend after a clean client cancellation in a Serverpod transaction."
- Its check now reads: "a later borrower sees a clean replacement after clean cancellation or an unrecoverable timeout."
- Task 2.9 (L394) matches this:
  - "Let the error escape the Serverpod transaction."
  - "in both cases verify it is discarded and the borrower on its replacement sees the defaults."
  - The old "same backend after clean cancellation" expectation is gone.
- The task requires replacement in both cases. That is narrower than "reuse or replacement", but it is what A13 now claims and what the pinned source does. If a future pin reused the connection, the task would stop for drift and send the change back for a decision, which is the right result. A silent pass would be wrong. This fits the user's approval because it doesn't require reuse.

### F2: Both real timeout cases are kept (passes)

- Task 2.9 still runs both trials under the real Serverpod `queryTimeout`:
  - "replies flowing", which is the clean cancellation, with "an extra cancel connection at about 60 s".
  - "replies held", with "the hard timeout at about 75 s", and the replies released "before the next checkout".
- It still requires "a Serverpod pool of 16 through `TcpProxy`, with no test-harness rollback transaction". That matches serverpod-testing L91 and L157.
- It still requires recording the timings and setting explicit test timeouts above those budgets.
- The 1 s diagnostic is evidence only and does not replace either trial.

### F3: Transaction cleanliness is kept (passes)

- The interrupted backend is still identified "by pid and start time".
- The borrower on the replacement must see "the defaults, not the interrupted transaction's read-only mode or `SET LOCAL` marker".
- Both checks apply in both cases.

### F4: No public promise or token release rule changed (passes)

- A13 says "D28 keeps tokens until the session future and grace end, independent of those driver timers." This matches D28 L434: a token is held until the session future completes (commit or rollback included) and the per-path statement timeout has passed.
- D28 L436 and L438 are unchanged in substance. Tokens cap visible work at 8, the rule doesn't rely on checkout, setup or cleanup deadlines, and a stalled pool still fails closed.
- A13 still names the public-read bounds as verified by the same scenarios: "Repeated lost replies" and "Waiting calls during a stall" (7.3), and "Repeated connection losses" (8.3).
- The dependents (D2, D9, D23, D28, D3, D19) and task 2.9's drift target are unchanged.
- No new product promise is made, and none is removed.

### Advisory (non-blocking, no change required)

- **AD1:** Make "verify it is discarded" observable, not inferred. Two ways to do this:
  - Before each trial, snapshot the pool's (pid, `backend_start`) set. Afterwards, check that the interrupted pair is absent from `pg_stat_activity` (or never reappears while borrowing past all 16 slots).
  - Check that the borrower's pair is new.
- **AD2:** A13's sentence "The driver can reuse a connection after a clean cancellation" is explanation only. No decision depends on it and task 2.9 doesn't probe it, which is fine. Don't turn it into a claim later without a probe.
- **AD3:** Round 46's advisory on the marker still applies: use a custom setting such as `SET LOCAL kaname.probe = 'x'`, not a short `statement_timeout`.

## Verdict

The amendment states the replacement outcome that the diagnostic and pinned source show. It keeps both real 60 s and 75 s timeout trials and the transaction-cleanliness checks, and it leaves D28's token release rule and the public-read promises unchanged.

VERDICT: APPROVE
CHANGES_APPLIED: n/a

## Required Changes

None.

## Rebuttals

- **Requiring replacement rather than "reuse or replacement":** I accept it. A13 now asserts that the connection is discarded, based on pinned source and an observed run. A test that accepted either outcome would leave that claim unchecked. Stopping for drift if reuse ever appears keeps the user's approved scope, because reuse is not required. It only becomes a reason to re-decide.