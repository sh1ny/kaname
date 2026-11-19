# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 REVISE: 1 critical (ADR 0012 bus scope vs ADR 0008), 12 moderate, 5 suggestions
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** openspec/changes/sde-import/proposal.md, design.md, specs/static-data-import/spec.md, specs/server-workers/spec.md, review.md (round 1); openspec/architecture.md; openspec/roadmap.md (M1); openspec/strategy.md (R38, R56, R57); openspec/specs/server-runtime/spec.md, openspec/specs/workspace-layout/spec.md; docs/adr/0004, 0008, 0009 (0001, 0002 and 0003 were listed in the design's ADRs section and checked for conflicts); cited sources server/kaname_server/lib/server.dart, server/kaname_server/bin/main.dart, server/kaname_server/config/development.yaml, server/kaname_server/config/generator.yaml, server/kaname_server/pubspec.yaml, server/kaname_client/pubspec.yaml, packages/kaname_core/lib/kaname_core.dart, mise.toml, .claude/skills/serverpod-models/SKILL.md, .claude/skills/serverpod-models/references/custom-serialization.md; AGENTS.md. Every cited file is tracked in git and none is a symlink. Each citation supports its claim: server.dart:4-7, main.dart:5-10, development.yaml:26-33, kaname_core.dart:1-9, workspace-layout spec:46-47, pubspec.yaml:10-11, mise.toml:81-89 and 241-258, ADR 0004:12-18, ADR 0009:21, :25, :27, :30-31, ADR 0008:20, serverpod-models SKILL.md:158-160 and custom-serialization.md:5. Moderate 3 notes the part of custom-serialization.md:5 that the design leaves out. A7 and A8 rest on package sources outside the repository and are recorded as assumptions, not cited paths, which is acceptable. No referenced stores.
- **Re-check (Required Changes only):** fresh-context subagent (Claude Code specwright-reviewer) re-read the current proposal.md, design.md, specs/server-workers/spec.md and specs/static-data-import/spec.md, plus packages/kaname_core/pubspec.yaml, openspec/specs/workspace-layout/spec.md and .claude/skills/serverpod-models/references/custom-serialization.md (all tracked) to check Required Change 3. All four Required Changes are applied; see the status under each one below. The applied edits introduce no contradiction.

### Round 1 findings, re-checked

| # | Status | Where |
|---|---|---|
| 1 Critical (bus scope vs ADR 0008) | Mostly resolved. D1:37 and C2 leave the bus, Redis, the vault and the privacy scope open. But C1 and D1:36 still state a general rule that closes them again; see Moderate 1 | design.md:36-37, 242-243 |
| 2 Hook/supervisor overwrite dev-task record | Resolved: the sweep runs only under the static-data lock (D3, D8, D10) | design.md:63-65, 127, 156, 328 |
| 3 No reconnect | Resolved: one connection per job, plus the "Postgres comes back" scenario | design.md:33; server-workers spec.md:58-60 |
| 4 Unassertable "Postgres unreachable" THEN | Resolved | server-workers spec.md:54-56 |
| 5 Storage bound vs previous build | Resolved: any other staged build is replaced, and C6 covers the previous build | static-data-import spec.md:154-163; design.md:247 |
| 6 Build-number source | Resolved: D11, A9, and the `_sde` file is a required file | design.md:162-168, 238; spec.md:95-104 |
| 7 Record-level faults | Resolved: D12, the spec requirement and fixtures | design.md:170-181, 146; spec.md:69-82 |
| 8 New/missing baseline | Resolved: `knownFiles` | design.md:95; spec.md:61-63, 106-108 |
| 9 Generated-ids scenario | Resolved: D13 adds a source scan test (Suggestion 2 notes its scope) | design.md:183-193; spec.md:128-130 |
| 10 jsonb declaration | Resolved as A8, but see Moderate 3 for the client side | design.md:78, 237 |
| 11 Lock vs ADR 0009 | Resolved: D3 and C3 | design.md:68, 244 |
| 12 One request in flight | Resolved: D14 and C9 | design.md:195-201, 250 |
| 13 Worker start limits | Resolved: the spec, D8 and C7 | server-workers spec.md:7-15; design.md:125, 248 |
| 14-18 Suggestions | All applied: `succeeded` is written in the transaction, idle-in-transaction timeout, the lock is taken before the download, the ownership row is fixed, and the endpoint must answer in under 1 s | design.md:65-67, 322, 363; server-workers spec.md:11 |

(Line numbers in this table and in the findings below refer to the round 2 text, before the Required Changes were applied.)

## Findings

### Critical (blocking)

None.

### Moderate

1. **C1 and D1:36 bring back, in general form, the conflict that round 1 found for the bus.** (Fixed: see Required Change 1.) C1 (design.md:242) says workers reach shared services "only through clients they own … never through a Serverpod `Session` or by proxying data through the main isolate". C2 (design.md:243) and D1:37 say Redis, the vault, the privacy scope and the bus are still open. Both entries go to ADR 0012, which would then contradict itself:
   - **The bus:** under ADR 0008:20 it is built on Serverpod's message system, which needs a `Session` (ADR 0009:27). C1 rules out both a `Session` in the worker and proxying through the main isolate. The only route C1 leaves is a bus client the worker owns that does not use Serverpod's messages. That is the contradiction with ADR 0008 that round 1 rated Critical.
   - **ADR 0009:** it lists "proxying through the main isolate over typed messages" as one of the two candidates for R56 (:27). It also says workers talk to the main isolate "through typed messages and the `RealtimeBus`" (:26).
   - **The privacy scope:** it lives in the main isolate (architecture.md:48). Proxying is the natural way for the realtime and Discord workers (architecture.md:49-50) to deliver through it, and C1 forbids it.

   Consequence: the M11 worker would have to break either accepted ADR 0012 or ADR 0008/0009. This is rated Moderate, not Critical, because D1:37 and C2 already state the intended scope, so the fix is a wording fix. D1 is `Chosen by: user`, so the fix goes to the owner.

2. **The "worker crashed" mark is a race, and D3's claimed bound on a held lock does not cover the download phase.** (Fixed: see Required Change 2.)
   - **The race:** D10 (design.md:156) tries the static-data lock as soon as `onExit` fires. Postgres releases a session lock only after it notices the closed socket, so on a crash the try-lock usually finds the lock still held. The record then stays `running`, and the code path that writes "worker crashed" rarely runs. Nothing else takes the lock until the next server start: the import is not resent and there is no daily check in this change. The admin therefore sees `running` until a restart. The spec still says the server "SHALL … record any import it was running as failed with reason "worker crashed"" (server-workers spec.md:29), and the "Crash during an import" THEN (spec.md:33) cannot be asserted reliably.
   - **The bound:** D3 (design.md:67) and the Mechanism Ledger (design.md:377) say `idle_in_transaction_session_timeout` and TCP keepalives mean "a dead socket therefore cannot hold the lock for long, even if A5 is wrong". The session lock is taken before the download (design.md:63, 363), and the download runs outside any transaction for up to 30 min (Resource Bounds), so `idle_in_transaction_session_timeout` does not apply then. If A5 is wrong, the socket is leaked but still open in a live process, so the kernel answers TCP keepalives and they never fire.

   Consequence: a crash during a download holds the lock until the process exits. Every later import, including the dev task, is then `skipped` with "import already running", and no sweep can run.

3. **The `SdeJson` `extraClasses` entry adds a dependency to the generated client that the design does not plan for.** (Fixed: see Required Change 3.) D4 (design.md:78) registers a hand-written `SdeJson` under `extraClasses`. The skill the design cites for this says "Both server and client must depend on the package" (`.claude/skills/serverpod-models/references/custom-serialization.md:5`). `kaname_client` depends only on `serverpod_client` (`server/kaname_client/pubspec.yaml:9-10`), and generator.yaml generates that client (`client_package_path: ../kaname_client`). The design does not say which package holds `SdeJson`, and the proposal's Impact section (proposal.md:39-41) does not mention `kaname_client`.

   Consequence: generation or analysis of `kaname_client` fails at task 2.1. Or, if `SdeJson` is put in `kaname_static_data`, the client and the Flutter app pick up `archive`, `http` and the importer as dependencies. That goes against the reason D7 gives for a separate package (design.md:118).

4. **The local-zip route is narrower than S6 and the Risks section claim, and the dev task has an unstated precondition.** (Fixed: see Required Change 4.)
   - **Offline installs:** S6 (proposal.md:93) says the local zip serves "installs without internet access", and Risks (design.md:393) says "the dev task imports a local zip". But the start hook only sends `RunImport(source: ccpLatest)` (design.md:128), and the dev task targets the development database (design.md:130). A staging or production install without internet has no supported way to import a local zip in this change, and nothing carries that gap forward.
   - **The dev task precondition:** in development, Postgres is embedded and Serverpod starts it (`server/kaname_server/config/development.yaml:26-27`; server-runtime spec.md:31). So the dev task, a plain Dart script, cannot connect unless the dev server is running. If the dev server is running with no active build, its start-time CCP import holds the lock through the download (up to 30 min), so the dev task is `skipped`.

   Consequence: a developer or offline operator following the design has no working path, and a later change has no constraint telling it to add one. S6 is `Chosen by: user`, so this goes to the owner.

### Suggestions

1. **`skipped` records are written without the lock.** State & Ownership (design.md:328) says every `sde_import` writer holds the static-data lock. D3's "Lock busy" path (design.md:64) and the spec (static-data-import spec.md:157-159) insert a `skipped` record precisely when the lock is not held. That insert is harmless today (it is a new row), but the stated invariant is false. Reword it to: "every update or delete of an `sde_import` row happens under the lock; `skipped` rows are inserted without it."
2. **Name the roots the source scan test reads.** D13 (design.md:186) scans "Dart source in the workspace's packages". The spec scenario (static-data-import spec.md:128-130) covers any Dart source file outside the known-ids table. List the scanned roots, for example `packages/`, `app_packages/`, `app/lib` and `server/kaname_server/lib` excluding `src/generated`, so that an id constant added to the server is caught the way the spec says.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

Changes 1 and 4 touch `Chosen by: user` decisions (D1, S6), so they go to the owner before they are applied. Each applied change updates its Decisions entry and the summary table.

1. **C1 and D1:36:** limit the rule to Postgres.
   - Replace C1 with: "Worker isolates reach Postgres only through connections they open themselves, per job, from a typed start message, behind Kaname interfaces; never through a Serverpod `Session` and never by copying rows through the main isolate. How workers reach other shared services is governed by C2."
   - In D1:36, replace "the general rule that a worker reaches shared services through clients it owns … never through a Serverpod `Session`" with the same Postgres-only rule.
   - Add to C2: "proxying through the main isolate over typed messages (ADR 0009:26-27) remains a candidate."

   **Re-check: fixed.** C1 (design.md:242) is the requested text, word for word. D1 (design.md:36) now records the rule "for Postgres only" with the same wording, and D1:37 leaves Redis, the vault, the privacy scope and the bus open. C2 (design.md:243) adds "proxying through the main isolate over typed messages (ADR 0009) remains a candidate". The D1 summary row (design.md:213) reads "bus and the rest left open", and D1's `Chosen by` (design.md:45) records the owner's choice. D1's rejected "Proxying through the main isolate" (design.md:39) concerns Postgres rows only, so it does not contradict C2. The server-workers requirement (spec.md:50-51) is Postgres-only as well, and proposal.md:10 and :14 match.

2. **D10, D3, the Mechanism Ledger, A5 and the server-workers spec:**
   - **D10:** on an unexpected exit, the supervisor retries the static-data try-lock at 1 s intervals for up to 30 s before it falls back to "the next lock holder marks it interrupted".
   - **server-workers spec.md:29 and :33:** make the outcome either one: "record any import it was running as `failed` with reason "worker crashed" (or "interrupted" when the lock is still held after the retry window)". Change the scenario's THEN to "… outcome `failed` with reason "worker crashed" once Postgres has released the worker's lock …".
   - **D3:67 and the ledger row for timeouts and keepalives:** state that they bound a dead connection only inside the import transaction. Add to A5 that if A5 is wrong, a crash during the download phase holds the lock until the process exits.
   - **A5's check (task 6.4):** require the crash test to kill the worker both during the download phase and during the transaction.

   **Re-check: fixed.** D10 (design.md:156) retries the try-lock every 1 s for up to 30 s, marks "worker crashed" when it gets the lock, and otherwise leaves the record for the next lock holder to mark "interrupted". The server-workers requirement (spec.md:25) states both outcomes with the 30-second retry window. The scenario's THEN (spec.md:29) now begins "once Postgres has released the worker's lock". D3 (design.md:67) and the ledger row (design.md:378) say that the timeouts and keepalives bound a dead connection only inside the transaction and do not cover the download. A5 (design.md:234) records the download-phase consequence and requires task 6.4's crash test to kill the worker during both the download and the transaction. A new ledger row (design.md:381) justifies the retry window. The State & Ownership row for the supervisor's crash mark (design.md:323) still holds, because the mark is written only under the lock.

3. **D4 and proposal Impact:** name the package that holds `SdeJson`, which must be importable by both `kaname_server` and `kaname_client` (custom-serialization.md:5). For example, put it in `kaname_core`, which has no dependencies, and keep it out of `kaname_static_data`. List the new `kaname_client` dependency in proposal.md's Impact section. If the static-data models are made `serverOnly` and that removes the client dependency, record it as an assumption instead, with how it was checked.

   **Re-check: fixed.** D4 (design.md:78) puts `SdeJson` in `kaname_core`, cites custom-serialization.md:5 and says the client and app never pull in the importer, `archive` or `http`. D7 (design.md:117) lists `SdeJson` among `kaname_core`'s contents. The D4 summary row (design.md:216) names `kaname_core`, and proposal.md:42 lists `kaname_client`'s new dependency on `kaname_core`. This creates no contradiction: `kaname_core` has no runtime dependencies (`packages/kaname_core/pubspec.yaml`), and a wrapper that implements only `toJson`/`fromJson` (custom-serialization.md:5) needs no Serverpod import, so the purity rule (`openspec/specs/workspace-layout/spec.md:46`) still holds.

4. **D8, S6 and Risks:**
   - **D8:** state that the dev task needs the development server running for its embedded Postgres, and that it records `skipped` while the server's own import holds the lock.
   - **S6 and Risks (design.md:393):** either remove "installs without internet access", or keep it and add a carried constraint. For example, C10: "Staging and production installs have no local-zip import path in this change; `static-data-settings` adds one (update now from a local zip). Kind: deliberate gap. Destination: doc comment: packages/kaname_static_data/lib/src/import_sde_job.dart ImportSdeJob".

   **Re-check: fixed.** D8 (design.md:130) states that the dev task needs the development server running for its embedded Postgres (citing development.yaml:26-27), that it records `skipped` ("import already running") while the server's start-time import holds the lock, and that staging and production have no local-zip path (C10). S6 (proposal.md:94) limits the local zip in this change to tests and the dev task, and defers the staging and production path to `static-data-settings`. The S6 summary row (design.md:212) matches. Risks (design.md:395) names the same gap and C10. C10 (design.md:250) is the requested carried constraint, with one kind and one destination. The static-data-import spec makes no offline-install claim that conflicts with this (spec.md:9-17, :166, :172).

CHANGES_APPLIED: yes

## Rebuttals
- **Required Change 1 (C1 scope):** fixed. The owner chose "Postgres only". design.md D1 and C1 now limit the rule to Postgres, and C2 keeps proxying through the main isolate as a candidate. Accepted by reviewer (design.md:36-37, 45, 213, 242-243).
- **Required Change 2 (crash mark):** fixed. The owner chose the retry window. Changes: D10 (try-lock every 1 s for up to 30 s), D3's bounds paragraph, A5 (crash test during the download and during the transaction), the Mechanism Ledger rows, and the server-workers requirement and scenario "A crashed worker is restarted and reported". Accepted by reviewer (design.md:67, 156, 234, 378, 381; server-workers spec.md:25, 29).
- **Required Change 3 (`SdeJson` package):** fixed. The owner chose `kaname_core`. Changes: D4, D7, the D4 summary row, and the `kaname_client` dependency in proposal.md's Impact. Accepted by reviewer (design.md:78, 117, 216; proposal.md:42).
- **Required Change 4 (local-zip route):** fixed. The owner chose "record the gap". Changes: S6 in proposal.md, the S6 summary row, D8 (the dev task's preconditions), Risks, and the new C10. Accepted by reviewer (proposal.md:94; design.md:130, 212, 250, 395).
- **Suggestions 1 and 2:** not applied to the planning artifacts, to keep this verdict valid. Both are carried into tasks.md: the `sde_import` doc comment states the insert-without-lock rule, and the scan test names its roots. Accepted by reviewer (Suggestions are not required changes).
