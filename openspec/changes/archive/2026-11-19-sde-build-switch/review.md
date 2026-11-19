# Review

## Metadata

- **Round:** 3
- **Prior round:** Round 2 (fresh-context subagent) gave REVISE: C1 (D6 relied on a `ready` that never fails while the supervisor retries a failed spawn forever), M1 (no task builds the amended D6), M2 (the shutdown-order claim had no Assumptions entry), M3 (no carried constraint for the rejected "call awaits the job"), S1 (stale citation line), S2 (state/bounds rows for a possible request queue). Commit 5ddee63 amends D6, A6, C9, the D6 summary row, one Failure & Visibility row, one Risks bullet and adds task 7.5.
- **Reviewer:** fresh-context subagent (Claude Code)
- **Reviewed:** openspec/changes/sde-build-switch/proposal.md, design.md (whole file), tasks.md (whole file, including the test map and 7.5), specs/static-data-builds/spec.md (daily-check and records requirements), specs/server-workers/spec.md, specs/static-data-import/spec.md (searched), review.md (round 2), `git show 5ddee63`. Source at `feat/sde-build-switch` HEAD (read with `git show HEAD:`): server/kaname_server/lib/server.dart, lib/src/workers/worker_supervisor.dart, lib/src/static_data/static_data_check_call.dart, static_data_runtime.dart, static_data_start_hook.dart, static_data_start.dart; plus the uncommitted working-tree diff of task 7.5 (`git diff HEAD`) for those files and test/integration/static_data/daily_check_call_test.dart. Serverpod 4.1.2 package source (outside the repository, read only to check A6, as the request allows): lib/src/server/serverpod.dart (`_requestReceivingShutdownTasks` registration, `shutdown`), lib/src/server/tasks/task_manager.dart `executeTasks`, lib/src/server/future_call_manager/future_call_manager.dart `stop`, serverpod_task_scheduler.dart `drain`. Skills loaded: serverpod-scheduling, codebase-design (both loaded; none failed).

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

Status of the round-2 findings:

- **C1: resolved.** D6 (design.md:93) no longer claims `ready` fails. The call now awaits neither `supervisor.ready` nor the answer. It relies only on behaviour the supervisor already has: `_send` returns a `WorkerError` "worker not running" at once when `_process == null` (worker_supervisor.dart:173-179), and `stop()` fails pending requests with "worker stopped" (:191-198). `ready` keeps its existing contract (:137-139). This is the round-2 alternative "send only when running, otherwise log", and it agrees with the restart policy (:43-51) and with the server-workers scenario "Worker fails to start". Nothing on the call's path waits on the worker, so the drain-then-stop shutdown order cannot hang on it. The working-tree code for 7.5 matches: `run` calls `runBuildCheck` under `unawaited(...)` and logs through `staticDataRuntime.log`.
- **M1: resolved.** Task 7.5 builds the amended D6 and C9 and adds a test with a spawn that always fails. That test fails on its 5 s timeout against the HEAD code, which awaits `ready` (static_data_check_call.dart:51 at HEAD), and passes once the call hands the request over. No supervisor change is needed, because no queue was added. The verify steps cover the C9 text and the existing daily-call and start-hook tests.
- **M2: resolved.** A6 records the shutdown order with the version, the files read, and what depends on it. I checked it against the 4.1.2 source. `Serverpod.shutdown` awaits `_requestReceivingShutdownTasks.executeTasks` before `experimental._shutdownTasks.executeTasks` (serverpod.dart:1342-1353). The first group includes `_futureCallManager?.stop(unregisterAll: true)` (:284-286). `FutureCallManager.stop` awaits `_scheduler.drain()` (future_call_manager.dart:206-209). The supervisor's stop is registered as an experimental shutdown task (static_data_start.dart:42-45). The claim holds.
- **M3: resolved.** C9 is a rejected alternative with exactly one destination, the `StaticDataCheckCall` doc comment, and the working-tree doc comment carries it.
- **S1: resolved.** The citation is now `static_data_start.dart:46`, which is `unawaited(hook.run());` at HEAD.
- **S2: resolved by construction.** D6 states that no request queue is added, so no State & Ownership or Resource Bounds row is needed.

Claims check (round 3, the amended text only). worker_supervisor.dart:43-51 shows the unlimited restart and spawn-retry policy. :173-178 shows the immediate "worker not running" answer. :185-200 covers `stop()` and its `_failPending('worker stopped')`; the method ends at :202, but the cited range contains the claim. server.dart:12-13 shows `await pod.start(); startStaticData(pod);`. static_data_start.dart:46 shows the detached `hook.run()`. Every cited file is tracked. The Failure & Visibility row for "Future call fails, the worker is down, or the holder is empty" and the new Risks bullet agree with D6, with C9 and with the code.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

- **S1 (new). A cron run that comes due while the worker is still starting is lost for the day.** Before the amendment, the call awaited `ready`, so a 12:00 run claimed during start-up waited for the worker. Now it gets "worker not running" and returns. D6 and Flow & State Gaps say the start catch-up covers such a day. That holds for an overdue row, but not for a row that comes due after the hook has evaluated `catchUpDue` and before `ready` completes. The hook reads `sde_check` and evaluates the rule before it awaits `ready` (static_data_start_hook.dart:161-190 at HEAD).

  Example: a server starts at 11:59:59 UTC with yesterday's check after yesterday's 12:00. No catch-up is due at evaluation. The 12:00:00 row runs before the isolate has spawned and logs "worker not running", and that day's build waits until the next day. The window is the worker's start-up time, so the risk is small, and the result is logged.

  The fix is cheap and changes no decision: in the hook, evaluate `catchUpDue` (and read its inputs) after `await supervisor.ready` instead of before. A run that found no worker writes no `sde_check` row, so the catch-up would then see no check since 12:00 and run. If you take this, D6 step 3 should say "after the worker is ready", and 7.5 (or a follow-up task) should move the read.
- **S2 (new).** A6's last sentence ("If it is wrong, a call that awaited the worker would merely delay shutdown less") is hard to parse. "If it is wrong, the hand-off is still correct; it only removes a shutdown delay that would not occur" says the same thing more plainly. This is wording only.
- **S3 (new, optional).** The shutdown behaviour C9 protects can be observed (how long the server takes to stop during a patch-day import), but no spec scenario states it. The 7.5 test checks a proxy, that the call returns at once. That is sufficient given A6. A server-workers scenario such as "Shutdown during a daily check: the server stops without waiting for the import; the next start's catch-up runs it again" would make the rule survive a later rewrite of the call. Note also that shutdown now kills a running import instead of waiting for it. Recovery is the existing "Worker crash mid-job" path: the backends are ended, the next start sweeps the record "interrupted", and with no `sde_check` row for the day the catch-up runs again. The Risks bullet could name that cost: one re-download after a stop during an import.

## Verdict

Every round-2 finding is resolved and checked against the code and the Serverpod 4.1.2 source. The amendment introduces no Critical or Moderate problem. The new items are suggestions only.

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals
