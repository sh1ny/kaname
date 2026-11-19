# Tasks

Project rules for every implementer and reviewer packet:
- `AGENTS.md`, section "Dart and Flutter code".
- Skills to load from `.claude/skills/<name>/SKILL.md`:
  - always: `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis`;
  - tests: `dart-add-unit-test`, `serverpod-testing`;
  - server: `serverpod-overview`, `serverpod-models`, `serverpod-database`, `serverpod-migrations`, `serverpod-configuration`;
  - design: `codebase-design`, `domain-modeling`.
- Run everything through mise. Use no mocking package: write hand-written fakes.

## Test map

Abbreviations: `SD` = `packages/kaname_static_data/test/`; `SI` = `server/kaname_server/test/integration/`.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| static-data-import → An import reads a build from CCP or a local zip | Latest build from CCP | SD/ccp_sde_source_test.dart | reads latest.jsonl and downloads that build | red |
| static-data-import → An import reads a build from CCP or a local zip | Local zip | SD/import_sde_job_test.dart | local zip and CCP source store equal rows | red |
| static-data-import → An import reads a build from CCP or a local zip | Build number disagrees | SD/import_sde_job_test.dart | fails on build number mismatch | red |
| static-data-import → An import reads a build from CCP or a local zip | Unreachable or corrupt source | SD/ccp_sde_source_test.dart | unreachable, cut-off and corrupt sources fail with reason | red |
| static-data-import → A build is imported side by side | New build next to the active one | SI/static_data/postgres_static_data_store_test.dart | new build is staged next to the active one | red |
| static-data-import → A build is imported side by side | Import fails partway | SI/static_data/postgres_static_data_store_test.dart | failure after rows leaves no rows and active untouched | red |
| static-data-import → A build is imported side by side | Server stops during an import | SI/static_data/start_hook_test.dart | dropped connection mid-import is swept to interrupted | red |
| static-data-import → Typed files keep typed columns and the full record | Known fields are typed | SI/static_data/postgres_static_data_store_test.dart | typed columns and raw jsonb round-trip | red |
| static-data-import → Typed files keep typed columns and the full record | Known field missing from a record | SD/import_sde_job_test.dart | missing optional field stores null | red |
| static-data-import → Typed files keep typed columns and the full record | Known field with the wrong type | SD/import_sde_job_test.dart | wrong-typed field is null and reported | red |
| static-data-import → Other files are stored record by record | Known untyped file | SD/import_sde_job_test.dart | known untyped file stored raw, not new | red |
| static-data-import → Other files are stored record by record | Empty file | SD/import_sde_job_test.dart | empty file listed with zero records | red |
| static-data-import → A bad record is skipped and reported | Invalid JSON line | SD/import_sde_job_test.dart | invalid JSON line is skipped and reported | red |
| static-data-import → A bad record is skipped and reported | Duplicate key in a typed file | SD/import_sde_job_test.dart | duplicate key keeps first and reports second | red |
| static-data-import → A bad record is skipped and reported | Every line bad | SD/import_sde_job_test.dart | required file with every line bad fails as missing | red |
| static-data-import → Drift is kept and reported | New file | SD/import_sde_job_test.dart | unknown file stored raw and reported new | red |
| static-data-import → Drift is kept and reported | New field in a typed file | SD/import_sde_job_test.dart | unknown field kept in JSON and reported | red |
| static-data-import → Only a missing required file stops an import | Typed file missing | SD/import_sde_job_test.dart | missing types file fails and names it | red |
| static-data-import → Only a missing required file stops an import | Build record missing | SD/import_sde_job_test.dart | zip without _sde fails with no build number | red |
| static-data-import → Only a missing required file stops an import | Known untyped file missing | SD/import_sde_job_test.dart | missing known untyped file is reported only | red |
| static-data-import → The known-ids table is checked against each build | All known ids present | SD/import_sde_job_test.dart | known-ids check passes | red |
| static-data-import → The known-ids table is checked against each build | Known id missing | SD/import_sde_job_test.dart | missing known id is reported | red |
| static-data-import → No code is generated from SDE content | New build with new content | SI/static_data/postgres_static_data_store_test.dart | build with new types and file imports without code change | red |
| static-data-import → No code is generated from SDE content | Id constants outside the known-ids table | SD/no_generated_ids_test.dart | no id constants outside knownIds | red |
| static-data-import → Each import checks the industry and logistics fields | All fields present | SD/import_sde_job_test.dart | field check reports every field present | red |
| static-data-import → Each import checks the industry and logistics fields | Field missing after a patch | SD/import_sde_job_test.dart | field check reports a missing field | red |
| static-data-import → Every import is recorded | Successful import | SI/static_data/postgres_static_data_store_test.dart | succeeded record commits with rows and holds four reports | red |
| static-data-import → Every import is recorded | Build already present | SD/import_sde_job_test.dart | stored build is skipped without writes | red |
| static-data-import → Imports run one at a time within a storage bound | Second import requested | SI/static_data/postgres_static_data_store_test.dart | second importer is skipped while the lock is held | red |
| static-data-import → Imports run one at a time within a storage bound | Another build is staged | SI/static_data/postgres_static_data_store_test.dart | commit removes every other staged build | red |
| static-data-import → An import starts when no build is active | First start | SI/static_data/start_hook_test.dart | no active build queues a CCP import | red |
| static-data-import → An import starts when no build is active | First start offline | SI/static_data/start_hook_test.dart | unreachable CCP records failure and server serves | red |
| static-data-import → An import starts when no build is active | Restart with an active build | SI/static_data/start_hook_test.dart | active build queues nothing | red |
| static-data-import → An import starts when no build is active | Test run mode or migration step | SI/static_data/start_hook_test.dart | test mode and maintenance role start no import | red |
| static-data-import → Only the first build is activated by the importer | Bootstrap | SI/static_data/postgres_static_data_store_test.dart | first build becomes active | red |
| static-data-import → Only the first build is activated by the importer | Later build | SI/static_data/postgres_static_data_store_test.dart | later build stays staged | red |
| static-data-import → Only the first build is activated by the importer | Failed first import | SI/static_data/start_hook_test.dart | failed first import leaves none active and requeues on start | red |
| server-workers → The server runs a compute worker isolate | Endpoints answer during an import | SI/workers/compute_worker_test.dart | health answers under 1 s during an import | red |
| server-workers → The server runs a compute worker isolate | Maintenance step | SI/workers/worker_roles_test.dart | maintenance step starts no worker and exits | red |
| server-workers → The server runs a compute worker isolate | Worker fails to start | SI/workers/compute_worker_test.dart | failed spawn is logged and server serves | red |
| server-workers → A crashed worker is restarted and reported | Crash during an import | SI/workers/compute_worker_test.dart | crash in download and in transaction marks worker crashed and restarts | red |
| server-workers → A crashed worker is restarted and reported | Worker fails repeatedly | SI/workers/worker_supervisor_test.dart | restart delay doubles to 60 s | red |
| server-workers → Workers exchange only typed messages | Known message | SI/workers/compute_worker_test.dart | typed import request gets typed result | red |
| server-workers → Workers exchange only typed messages | Unknown message | packages/kaname_core/test/worker_message_test.dart | unknown type or version is rejected with typed error | red |
| server-workers → Workers exchange only typed messages | Start message printed | SI/workers/compute_worker_test.dart | start message toString hides the password | red |
| server-workers → Workers reach Postgres through their own connections | Import writes to Postgres | SI/workers/compute_worker_test.dart | worker import writes through its own connection | red |
| server-workers → Workers reach Postgres through their own connections | Postgres unreachable from the worker | SI/workers/compute_worker_test.dart | unreachable Postgres fails the job, worker stays up | red |
| server-workers → Workers reach Postgres through their own connections | Postgres comes back | SI/workers/compute_worker_test.dart | next job reconnects after Postgres returns | red |

## 1. ADR 0012 and planning documents

- [x] 1.1 Verify A7: re-read `Serverpod.createSession` and the constructor's error path in the locked `serverpod` version (Dart MCP `read_package_uris`). Then write `docs/adr/0012-worker-isolate-access.md` (MADR-short, `Status: accepted` with the date the review passed, `Supersedes: none`). It carries C1 (worker-owned Postgres connections, per job, no Session, no copying rows through main), C2 (Redis, vault, privacy scope and bus stay open in R56; proxying through main remains a candidate; reconcile with ADR 0008) and C3 (the static-data advisory lock and why it is compatible with ADR 0009's "no extra locks"). It records the rejected alternatives with D1's reversal cost. Verify: the file exists and each of C1–C3 is stated in it.
- [x] 1.2 Add ADR 0012 to the in-force index in `openspec/architecture.md`, and to its Boundaries line for cross-isolate messages. Update strategy row R56 in `openspec/strategy.md` to show the Postgres part settled by ADR 0012 and the rest still open. Leave R38 for task 8.3. Verify: `mise run spec:validate` passes and `git diff` shows only these lines.

## 2. Shared types and the database schema

- [x] 2.1 Verify A3 and A8: read the `serverpod-models` skill and generate a throwaway model with a (build, id) unique index, a partial or marker-based active index, and an `extraClasses` field with `serializationDataType: jsonb`. Record the result in the D2/D4 doc comments of the models. If either assumption fails, stop and apply the drift rule.
- [x] 2.2 In `kaname_core`, add `SdeJson` (wrapper over `Map<String, Object?>` with `toJson`/`fromJson`), the `Job`/`JobRunner` interface and the versioned `WorkerMessage` base with an unknown-message rejection. First write `packages/kaname_core/test/worker_message_test.dart` ("unknown type or version is rejected with typed error"), see it fail, then implement it. Verify: `mise run test:core` passes and the row turns green.
- [x] 2.3 Add the `.spy.yaml` models to `server/kaname_server`: `sde_build`, `sde_import`, `sde_record` and the 13 typed tables, each typed table with `build`, the SDE id, its typed columns and `raw` (`SdeJson`, jsonb). Register `SdeJson` under `extraClasses` in `config/generator.yaml` and add `kaname_core` to `kaname_client`. Then run `mise run server:generate` and create the migration (`serverpod-migrations`). Verify: `mise run server:drift` is clean, `SI/migrations_test.dart` passes, and `mise run purity` still passes.

## 3. Importer package `kaname_static_data`

- [x] 3.1 Create `packages/kaname_static_data` (pure Dart; `archive` and `http`), add it to the workspace, and add a `test:static_data` task to `mise run test`. Run `mise run notices`. Verify: `mise run workspace`, `purity`, `licences` and `notices:check` pass.
- [x] 3.2 Verify A4 and A9: read the `archive` and `postgres` package docs through Context7 (streamed zip entries, multi-row parameterised insert), and fetch CCP's `latest.jsonl` and the entry list of the latest JSONL zip to confirm the `_sde` record's file and field. Record the findings in the `SdeSource` doc comment. Then build the zip reader (streaming entries and lines, with Resource Bounds' caps), `LocalZipSdeSource`, and `CcpSdeSource` with a fake `http` client. Write the `ccp_sde_source_test.dart` rows first. Verify: those rows are green.
- [x] 3.3 Verify A1 against CCP's published SDE documentation and schema changelog, and the zip from 3.2, for the typed files' field names. Then write the synthetic fixture builder (D9: every fixture case) in `SD/support/`.
- [x] 3.4 Write the typed record parsers and `knownFiles` (D6: typed, required, plain). Write the `import_sde_job_test.dart` rows for typed fields, other files, bad records, drift and missing files first, against the in-memory `StaticDataStore` fake. Verify: those rows are green.
- [x] 3.5 Write `knownIds`, holding only the ids M1 code uses, with its check. Verify: the known-ids rows are green.
- [x] 3.6 Verify A2 by listing what M18 (industry) and M22 (market and logistics) need from the roadmap and strategy. Then write `industryLogisticsFields` with its check. Verify: the field-check rows are green.
- [x] 3.7 Write `ImportSdeJob`: the lock, the stale sweep, the `running` record, the build-number check, the skip of stored builds, one transaction through `StaticDataStore`, and outcome recording. Its doc comment carries C6 and C10. The `sde_import` doc comment states that `skipped` rows are inserted without the lock and every update or delete happens under it (review round 2, suggestion 1). Verify: every remaining `SD/import_sde_job_test.dart` row is green.
- [x] 3.8 Write `SD/no_generated_ids_test.dart` (D13). It scans `packages/`, `app_packages/`, `app/lib`, `tools/` and `server/kaname_server/lib`, excluding `src/generated` (review round 2, suggestion 2), and holds a positive control fixture. Its doc comment carries C5. Verify: the row is green, and a seeded `const typeIdTritanium = 34;` in a temp copy fails it.

## 4. Postgres store in the server

- [x] 4.1 Write `SI/static_data/postgres_static_data_store_test.dart` rows first. Then implement `PostgresStaticDataStore` on `package:postgres`: per-job connection settings, session advisory lock, `idle_in_transaction_session_timeout` and keepalives, batched multi-row inserts, removal of other staged builds and bootstrap activation in the commit, and record pruning. Add a contract test that compares its columns and types with the generated table definitions (C4). Its doc comment carries C4 and C8. Verify: every row of that file is green under `mise run test:server`.

## 5. Compute worker

- [ ] 5.1 Write the typed messages (`WorkerStart` with a redacting `toString`, `RunImport`, `ImportFinished`, `WorkerError`) and `ComputeWorker`, which handles each request in its own task (D14, carrying C9 in its doc comment). Write the `SI/workers/compute_worker_test.dart` rows for known messages, the start message, own-connection writes, unreachable Postgres, Postgres coming back, and failed spawn first. Verify: those rows are green.
- [ ] 5.2 Write `WorkerSupervisor`: spawn with `onExit`/`onError`, restart backoff from 1 s to 60 s with a reset after 5 minutes of uptime, and the 30 s lock-retry window for the crash mark (D10). Test it with a fake clock in `SI/workers/worker_supervisor_test.dart`. Verify: that row is green.

## 6. Start hook and run modes

- [ ] 6.1 Write the `SI/static_data/start_hook_test.dart` rows first. Then wire the start hook into `server.dart` after `pod.start()`: the run-mode and role gate (D8, C7), the xact-lock stale sweep, the active-build check through the ORM, and `RunImport(ccpLatest)`. Verify: those rows are green.
- [ ] 6.2 Write `SI/workers/worker_roles_test.dart`: the maintenance step and the test run mode start no worker, and the maintenance step exits. Verify: the row is green, and `mise run stack:test` still passes (the stack's migration step exits).
- [ ] 6.3 Write the "health answers under 1 s during an import" test with a slow fake source on an explicitly spawned worker. Verify: the row is green.
- [ ] 6.4 Verify A5: kill the worker isolate once during the download and once during the transaction, and assert that the lock is released, no row of the build remains, the record reads `failed` ("worker crashed") and a new worker runs. Verify: the crash row is green. If A5 fails, stop and apply the drift rule.

## 7. Development task

- [ ] 7.1 Write `server/kaname_server/tool/sde_import.dart` and `mise run sde:import -- <zip>|--latest [--r38-report <path>]`. It runs `ImportSdeJob` against the development database and prints the import record. Document its precondition (the dev server is running) in the task description and the tool's doc comment. Verify: running it on a synthetic fixture zip against the dev database prints a `succeeded` record, and a second run prints `skipped`.

## 8. Integration

- [ ] 8.1 Run `mise run check`, `mise run test:server` and `mise run spec:validate`. Verify: all pass.
- [ ] 8.2 [evidence] Run the opt-in `sde-live` test, which imports CCP's latest build into a scratch database. Capture the build number, row counts per file, zip and unpacked sizes, import duration, whole-build delete time and the drift report → evidence/live-import.md. This settles A6 against Resource Bounds' caps. Any A1, A6 or A9 mismatch is fixed before this task is ticked. Ask the owner before running: this is a heavy download and import.
- [ ] 8.3 Run `mise run sde:import -- --latest --r38-report docs/static-data/r38-field-check.md` and commit the report. Update strategy row R38 with its finding (gap or no gap). Verify: the report names the build number and every declared field with present or missing.

## Workflow follow-up

- Pre-ship review, PR, and owner merge through `specwright-commit` and `specwright-pr` (`finish: pr`).
- Archive after merge, then `specwright-roadmap next` starts `sde-build-switch`.
