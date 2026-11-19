# Tasks

Skills for every implementer and reviewer packet (paths under `.claude/skills/`): `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis`, `dart-add-unit-test`, `serverpod-overview`, `serverpod-models`, `serverpod-database`, `serverpod-migrations`, `serverpod-scheduling`, `serverpod-testing`, `codebase-design`. Rules: AGENTS.md "Dart and Flutter code". Server tests run with the embedded Postgres; per the owner's note, ask before running heavy or opt-in live tests.

## Test map

Abbreviations: `KSD` = `packages/kaname_static_data/test/`, `SRV` = `server/kaname_server/test/integration/`.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| static-data-builds → Stored builds have one of three states | After a switch | SRV static_data/build_switch_test.dart | after a switch the old active is previous and nothing else is stored | green |
| static-data-builds → Stored builds have one of three states | Import while active, previous and staged builds exist | SRV static_data/build_switch_test.dart | an import drops the staged build first and never stores more than three | green |
| static-data-builds → A newer build is switched to after its import | Daily build arrives | SRV static_data/build_switch_test.dart | switch makes the new build active, the old previous and removes the oldest | green |
| static-data-builds → A newer build is switched to after its import | Switch fails | SRV static_data/build_switch_test.dart | a failing switch statement keeps the active build and leaves the new one staged | green |
| static-data-builds → A newer build is switched to after its import | Older build imported | KSD take_latest_build_job_test.dart | an older build stays staged and is never switched to | green |
| static-data-builds → A request reads one build from start to end | Switch during a request | SRV static_data/pinned_reader_test.dart | a pinned request keeps reading the old build across a switch | green |
| static-data-builds → A request reads one build from start to end | Fixed build removed | SRV static_data/pinned_reader_test.dart | a pinned build removed by two switches fails with build no longer stored | green |
| static-data-builds → A request reads one build from start to end | No active build | SRV static_data/pinned_reader_test.dart | pinning with no active build fails with no active build | green |
| static-data-builds → The previous build can be rolled back to | Rollback | SRV static_data/build_switch_test.dart | rollback swaps active and previous and moves the hold | green |
| static-data-builds → The previous build can be rolled back to | No previous build | SRV static_data/build_switch_test.dart | rollback without a previous build fails with no previous build | green |
| static-data-builds → The previous build can be rolled back to | Import running | SRV static_data/build_switch_test.dart | rollback while the lock is held fails with import running | green |
| static-data-builds → A rolled-back build is held | Daily check after a rollback | KSD take_latest_build_job_test.dart | a held announced build gives outcome held | green |
| static-data-builds → A rolled-back build is held | Newer build after a rollback | KSD take_latest_build_job_test.dart | a newer build lifts the hold and makes the rolled-back-to build previous | green |
| static-data-builds → Each build switched to is compared with the build it replaces | Changed build | SRV static_data/build_diff_test.dart | changed types file reports counts, keys and volume field | green |
| static-data-builds → Each build switched to is compared with the build it replaces | First build | KSD take_latest_build_job_test.dart | the first build becomes active with no stored report | green |
| static-data-builds → Each build switched to is compared with the build it replaces | Build imported by the development task | KSD take_latest_build_job_test.dart | a staged development import gets its report when switched to | green |
| static-data-builds → Each build switched to is compared with the build it replaces | Comparison fails | KSD take_latest_build_job_test.dart | a failed comparison is recorded and the switch still happens | green |
| static-data-builds → The diff report lists counts, keys and fields | More than 1,000 changes in one file | SRV static_data/build_diff_test.dart | more than 1000 changed keys are cut off and marked | green |
| static-data-builds → The diff report lists counts, keys and fields | File only in the new build | SRV static_data/build_diff_test.dart | a file only in the new build is listed as new with all records added | green |
| static-data-builds → The diff report lists counts, keys and fields | Records that differ only in key order | SRV static_data/build_diff_test.dart | key order alone is not a change | green |
| static-data-builds → Any two stored builds can be compared on demand | Compare active and previous | SRV static_data/dev_tasks_test.dart | sde:diff prints the same report as the stored one | red |
| static-data-builds → Any two stored builds can be compared on demand | Build not stored | SRV static_data/dev_tasks_test.dart | sde:diff of a missing build exits non-zero with build not stored | red |
| static-data-builds → The server checks for a new build every day | New build found | KSD take_latest_build_job_test.dart | a newer announced build is imported, compared and switched | green |
| static-data-builds → The server checks for a new build every day | No new build | KSD take_latest_build_job_test.dart | the active build announced gives up to date | green |
| static-data-builds → The server checks for a new build every day | CCP unreachable | KSD take_latest_build_job_test.dart | unreachable CCP records a failed check and keeps the active build | green |
| static-data-builds → The server checks for a new build every day | Start after a long stop | SRV static_data/start_hook_test.dart | a start 30 hours after the last check runs a check and keeps the daily call | green |
| static-data-builds → The server checks for a new build every day | Restart across 12:00 UTC | KSD daily_build_check_schedule_test.dart | a restart across 12:00 UTC is due a catch-up | green |
| static-data-builds → The server checks for a new build every day | Restart after today's check | SRV static_data/start_hook_test.dart | a restart after today's check runs none and keeps one daily call | green |
| static-data-builds → The server checks for a new build every day | Test run mode or migration step | SRV static_data/start_hook_test.dart | test mode and maintenance role schedule no check | green |
| static-data-builds → Every check, switch and rollback is recorded | CCP names an older build | KSD take_latest_build_job_test.dart | an older announced build gives outcome older | green |
| static-data-builds → Every check, switch and rollback is recorded | Check while an import runs | KSD take_latest_build_job_test.dart | a check while the lock is held records import already running | green |
| static-data-import → Imports run one at a time within a storage bound | Second import requested | SRV static_data/postgres_static_data_store_test.dart | second importer is skipped while the lock is held | green |
| static-data-import → Imports run one at a time within a storage bound | Another build is staged | SRV static_data/postgres_static_data_store_test.dart | an import removes the staged build before writing and keeps active and previous | green |
| static-data-import → Imports run one at a time within a storage bound | Import fails after removing the staged build | SRV static_data/postgres_static_data_store_test.dart | a failed import leaves the staged build removed and active and previous unchanged | green |
| static-data-import → Only the first build is activated by the importer | Bootstrap | SRV static_data/postgres_static_data_store_test.dart | first build becomes active with no previous build | green |
| static-data-import → Only the first build is activated by the importer | Later build | KSD take_latest_build_job_test.dart | a later import is staged by the import and then switched to | green |
| static-data-import → Only the first build is activated by the importer | Failed first import | SRV static_data/start_hook_test.dart | failed first import leaves none active and requeues on start | green |
| static-data-import → An import starts when no build is active | First start | SRV static_data/start_hook_test.dart | no active build queues a CCP import | green |
| static-data-import → An import starts when no build is active | First start offline | SRV static_data/start_hook_test.dart | unreachable CCP on first start writes a failed check and no import record | green |
| static-data-import → An import starts when no build is active | Restart with an active build | SRV static_data/start_hook_test.dart | an active build imports on start only when the check finds a newer one | green |
| static-data-import → An import starts when no build is active | Test run mode or migration step | SRV static_data/start_hook_test.dart | test mode and maintenance role start no import | green |
| server-workers → The server runs a compute worker isolate | Endpoints answer during an import | SRV workers/compute_worker_test.dart | health answers under 1 s during an import | green |
| server-workers → The server runs a compute worker isolate | Endpoints answer during a build comparison | SRV workers/compute_worker_test.dart | health answers under 1 s during a build comparison | green |
| server-workers → The server runs a compute worker isolate | Maintenance step | SRV workers/worker_roles_test.dart | maintenance step starts no worker and exits | green |
| server-workers → The server runs a compute worker isolate | Worker fails to start | SRV workers/compute_worker_test.dart | failed spawn is logged and server serves | green |

## 1. Build state model and records

- [x] 1.1 Write failing store tests in `SRV static_data/build_switch_test.dart` and `postgres_static_data_store_test.dart` asserting the new columns and tables exist and enforce one previous build (insert two rows with `previousMarker` true → unique violation). Verify: tests fail on the missing column or table.
- [x] 1.2 Add `previous` to `SdeBuildState` (`sde_build_state.spy.yaml`) and `BuildState`, `previousMarker: bool?` (unique index) and `held: bool` (default false) to `sde_build.spy.yaml`, and new models `sde_check.spy.yaml` (with `SdeCheckOutcome`), `sde_switch.spy.yaml` (with `SdeSwitchKind` `forward`/`rollback` and `SdeSwitchOutcome`) and `sde_build_diff.spy.yaml`, with jsonb `report` (D1, D5, D4). Run `serverpod generate` and create the migration through the package-local CLI (`serverpod-migrations` skill). Verify: 1.1 tests pass, `migrations_test.dart` passes, and `postgres_static_data_store_contract_test.dart` is extended to the new columns and passes.
- [x] 1.3 Extend the pure-Dart `StaticDataStore`/`StaticDataWriter` interfaces and `InMemoryStaticDataStore` with the state, hold, check, switch and diff-record operations the later groups need. Write C7 in the doc comment of `StaticDataStore`: every switch and rollback takes the static-data lock and changes states in one transaction on that lock's connection, never through the main isolate's ORM. Verify: `mise run analyze` clean; the C7 text is present.

## 2. Import drops the staged build first

- [x] 2.1 Write failing tests for "Another build is staged", "Import fails after removing the staged build" and "Bootstrap" (map rows; `postgres_static_data_store_test.dart`), and the in-memory equivalents in `KSD import_sde_job_test.dart`. Verify: they fail for the right reason (the staged build is still removed at commit, inside the import transaction).
- [x] 2.2 Move the staged-build removal out of `commitBuild` into its own committed transaction under the lock, before the import transaction (D8). Split `ImportSdeJob`'s body into a lock-free `importBuild` step that `ImportSdeJob` (development task) and the later check job both call (D2). Update `ImportSdeJob`'s doc comment: C6 of `sde-import` is now satisfied, so replace it with a pointer to the switch. Verify: 2.1 tests green, all of `KSD import_sde_job_test.dart` passes, and the "Second import requested" row is re-run and still green.

## 3. Switch, rollback and hold

- [x] 3.1 Verify A4: in `SRV static_data/build_switch_test.dart`, read the active build's rows through a second connection in a loop while a switch transaction deletes a whole seeded build, and assert that no read blocks for longer than one second. Verify: the test passes. If it fails, A4 is disproved: stop and apply the drift rule.
- [x] 3.2 Write failing tests for "After a switch", "Daily build arrives", "Switch fails" (inject a failing statement through a test hook in the switch transaction), "Rollback", "No previous build" and "Import running" (map rows). Verify: they fail.
- [x] 3.3 Implement the switch transaction (D2 steps 1–6) and `RollbackJob` (swap, hold moves to the rolled-back-from build, `held` cleared on the build made active) in the Postgres store and the in-memory store, each writing an `sde_switch` record. Write C6 in `RollbackJob`'s doc comment (`packages/kaname_static_data/lib/src/rollback_job.dart`). Verify: 3.2 rows green, and the C6 text is present.

## 4. Pinned reader

- [x] 4.1 Write failing tests for "Switch during a request", "Fixed build removed" and "No active build" (map rows), plus in-memory reader tests in `KSD static_data_reader_test.dart`. Verify: they fail.
- [x] 4.2 Add the `StaticDataReader`/`PinnedBuild` interface with `type(id)` and `solarSystem(id)`, the `BuildNoLongerStored` and `NoActiveBuild` errors as a sealed error family (D3, D9), an in-memory implementation, and the server implementation through the ORM in `server/kaname_server/lib/src/static_data/`. Check that the spec requirement "A request reads one build from start to end" states C1 (that every server-side static-data read goes through the pinned reader) and reference it from the reader's doc comment. Verify: 4.1 rows green; `mise run analyze` clean.

## 5. Build diff

- [x] 5.1 Verify A1: in `SRV static_data/build_diff_test.dart`, assert that `'{"a":1,"b":2}'::jsonb = '{"b":2,"a":1}'::jsonb` holds on the embedded Postgres. Verify: the test passes. If it fails, A1 is disproved: stop and apply the drift rule.
- [x] 5.2 Write failing tests for "Changed build", "More than 1,000 changes in one file", "File only in the new build" and "Records that differ only in key order" (map rows). Also write tests for raw files: a raw file with a repeated key and empty-key records gives multiset counts that no join multiplies (D4, review M4). Verify: they fail.
- [x] 5.3 Implement `StaticDataDiffer` and `BuildDiffReport` in `kaname_static_data` (`build_diff.dart`), the SQL differ in the server store per D4 and D11 (typed tables on `sdeId` with `jsonb_each` field counts; `sde_record` classified per record; keys capped at 1,000 per file and kind with a `truncated` flag), and an in-memory differ. Write C5 in `BuildDiffReport`'s doc comment. Verify: 5.2 rows green; the C5 text is present.
- [x] 5.4 Verify A3 with the opt-in live test: extend `SRV static_data/sde_live_test.dart` to diff two real builds and time each per-table statement and the whole-build delete of a switch. Ask the owner before running it (heavy test). Record the timings. If a statement comes near the five-minute timeout, apply the drift rule (split by key range).
- [x] 5.5 [evidence] Capture the live test's timing output from 5.4 → evidence/live-diff-timing.md

## 6. Check job and daily schedule

- [x] 6.1 Write failing tests in `KSD daily_build_check_schedule_test.dart` for `catchUpDue`: no check ever; no active build; last check yesterday 12:20 with a restart today at 12:05 (the "Restart across 12:00 UTC" row); a check today at 12:00 with a restart at 15:00 (due: false); and the cron string `0 12 * * *`. Verify: they fail.
- [x] 6.2 Implement `DailyBuildCheckSchedule` (`packages/kaname_static_data/lib/src/daily_build_check_schedule.dart`) and write C8 in its doc comment. Verify: 6.1 green; the C8 text is present.
- [x] 6.3 Write failing `TakeLatestBuildJob` tests in `KSD take_latest_build_job_test.dart` with the in-memory store, a fake source and a failing-differ fake, for the map rows "Older build imported", "Daily check after a rollback", "Newer build after a rollback", "First build", "Build imported by the development task", "Comparison fails", "New build found", "No new build", "CCP unreachable", "CCP names an older build", "Check while an import runs" and "Later build". Also test a staged newer build left by a failed switch: it is switched without being imported again. Verify: they fail.
- [x] 6.4 Implement `TakeLatestBuildJob` (`packages/kaname_static_data/lib/src/take_latest_build_job.dart`) per D2: one lock hold, outcome decision, `importBuild`, compare before a forward switch unless a report exists (D10: a failed comparison is stored as `failed` and the switch goes on), the switch, the `sde_check` record with `checkedAt` set to the job's start, and pruning to 100 rows. Write C3 and C4 in its doc comment. Verify: 6.3 rows green; the C3 and C4 texts are present.

## 7. Worker, future call and start hook

- [x] 7.1 Verify A2 and A5: write `SRV static_data/daily_check_call_test.dart`. It schedules the recurring call twice with cancel-then-schedule in between and asserts exactly one pending `serverpod_future_call` row with identifier `kaname-sde-daily-check` and a next run at 12:00 UTC. It also schedules a one-off run of the call against a server started with no `futureCall` config key and asserts that it runs. Verify: the test passes. If either assumption fails, apply the drift rule.
- [x] 7.2 Write failing tests: the start-hook rows "Start after a long stop", "Restart after today's check", "Test run mode or migration step" (static-data-builds), "First start offline" and "Restart with an active build" in `SRV static_data/start_hook_test.dart`; "Endpoints answer during a build comparison" in `SRV workers/compute_worker_test.dart`; and a typed `RunBuildCheck` → `BuildCheckFinished` round trip, with an unknown-version rejection, in `compute_worker_test.dart`. Verify: they fail.
- [x] 7.3 Add the typed worker messages `RunBuildCheck` and `BuildCheckFinished` (versioned, registered in the codec), the worker's handler that runs `TakeLatestBuildJob` on its own connection, and `WorkerSupervisor.runBuildCheck`. Verify: the round-trip and comparison-health rows green.
- [x] 7.4 Add the `StaticDataCheckCall` future call and the `staticDataRuntime` holder in `server/kaname_server/lib/src/static_data/`, not exported, with a `@visibleForTesting` `reset()`. Add `meta` as a direct dependency of `kaname_server` for the annotation (review S8), then run `mise run notices`. Rewrite `StaticDataStartHook.run` per D6: start the supervisor, publish it to the holder, cancel and schedule the daily call from `DailyBuildCheckSchedule.cron`, then run the check when `catchUpDue` says so. Write C2 in `StaticDataStartHook`'s doc comment. Verify: 7.2 start-hook rows green; the re-run green rows "First start", "Failed first import" and "Test run mode or migration step" (static-data-import) are still green; `mise run notices:check` passes; the C2 text is present.

## 8. Development tasks

- [ ] 8.1 Write failing tests in `SRV static_data/dev_tasks_test.dart` for "Compare active and previous" and "Build not stored", for `sde:rollback`'s exit codes on success, "no previous build" and "import running", and unit tests for both tools' argument parsing in `server/kaname_server/test/unit/`. Verify: they fail.
- [ ] 8.2 Add `server/kaname_server/tool/sde_rollback.dart` and `tool/sde_diff.dart` (the diff in one `REPEATABLE READ READ ONLY` transaction, D7) and the mise tasks `sde:rollback` and `sde:diff` beside `sde:import` in `mise.toml`, each described with its arguments and its need for the development server. Verify: 8.1 green; `mise tasks` lists both.

## 9. Architecture and integration

- [ ] 9.1 Update `openspec/architecture.md`. In State ownership, the static-data builds row becomes "active, previous and at most one staged; at most three at any moment", with the switch and rollback jobs under the lock as writers. Update the Resource bounds row for the static-data import the same way. Verify: the diff shows only those rows changed; `mise run spec:validate` passes.
- [ ] 9.2 Run `mise run check` (workspace, purity, analyze, format:check, test, notices:check) and confirm every test-map row is green. Verify: the command exits 0 and the map has no `red` row.

## Workflow follow-up

- The owner's M1 user-verified criterion (take a new build while the server and an app run, see the change report and settings page, search offline) is judged at M1's close, after `client-data-bundle` and `static-data-settings`.
