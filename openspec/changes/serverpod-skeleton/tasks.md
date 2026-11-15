# Tasks

## Test map

Abbreviations: `S` = `server/kaname_server/test`, `C` = `server/kaname_client/test`, `T` = `tools/kaname_tools/test`. Tests under `S` and `C` are server tests: they run in `mise run test:server` on Linux, never in `mise run check`. Tests tagged `stack` run only in `mise run stack:test` against a running Compose stack (the `stack` CI job); `test:server` excludes the tag. Tests under `T` are cheap structure tests that parse committed files with `package:yaml` and run in `check` on all three OSes.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| server-runtime → The server and its client are workspace packages | Server packages resolve with the workspace | T/workspace_test.dart | root workspace lists kaname_server and kaname_client, the server pubspec holds serverpod_cli as a dev dependency and the lockfile holds it (a workspace lockfile marks it transitive); evidence: task 1.4 (`dart run serverpod_cli version` through mise) | green |
| server-runtime → The server and its client are workspace packages | Generated client out of date | n/a (mechanical: `mise run server:drift` regenerates, formats and runs `git diff --exit-code`, which names the differing files) → evidence/drift-check.md | task 2.5 | red |
| server-runtime → Redis is enabled in every server run mode | Run-mode configuration | S/unit/run_mode_config_test.dart | every run mode enables Redis with a host and port | red |
| server-runtime → Redis is enabled in every server run mode | Redis unreachable at start | S/integration/probes_test.dart | redis unreachable at start: readyz 503 and the log names redis | red |
| server-runtime → Each run mode uses its defined Postgres | Test run needs no external database | S/integration/health_endpoint_test.dart | all dependencies up (runs on embedded Postgres; CI installs no Postgres) | red |
| server-runtime → Each run mode uses its defined Postgres | Embedded data is not tracked | T/gitignore_test.dart | embedded postgres data, passwords.yaml and env files are ignored (`git check-ignore`) | red |
| server-runtime → Migrations are applied before the server serves | Fresh database | S/integration/migrations_test.dart | maintenance run applies every committed migration to an empty database | red |
| server-runtime → Migrations are applied before the server serves | Database from a newer server | S/integration/migrations_test.dart | maintenance run exits 1 naming the mismatch on a database with an unknown migration | red |
| server-runtime → The server image takes its toolchain from mise | Image matches the pinned toolchain | C/stack/image_test.dart (tag `stack`) | build log shows the mise-installed dart version and pub get with the lockfile enforced; plus T/dockerfile_test.dart: no Dockerfile states a Flutter or Dart version | red |
| server-runtime → The server image takes its toolchain from mise | No secrets in the image | C/stack/image_test.dart (tag `stack`) | image built from a checkout with passwords.yaml and .env contains neither | red |
| server-runtime → The server image takes its toolchain from mise | Lockfile out of date | C/stack/image_test.dart (tag `stack`) | build from a copy with an unsatisfied pubspec fails at dependency resolution | red |
| server-runtime → Insights and persistent session logs run only in development | Production configuration | S/unit/run_mode_config_test.dart | insights and persistent session logs only in development; console logging everywhere | red |
| server-runtime → Insights and persistent session logs run only in development | Calls in the stack | C/stack/stack_test.dart (tag `stack`) | health calls write no session log row and no insights port listens | red |
| server-runtime → A fresh clone can start the server locally | Fresh clone | S/unit/setup_test.dart | setup on a fresh tree writes passwords.yaml and a derived dev env with one redis password; evidence: task 3.6 (fresh clone, setup, `test:server`) | red |
| server-runtime → A fresh clone can start the server locally | Existing secrets | S/unit/setup_test.dart | setup leaves existing passwords unchanged | red |
| server-runtime → Agents reach the server through the Serverpod MCP entry | Entry starts | T/mcp_config_test.dart | claude and omp configs hold the serverpod entry through mise and claude enables and allow-lists it; evidence: task 7.3 → evidence/mcp-entry.md | red |
| server-runtime → Agents reach the server through the Serverpod MCP entry | Server not running | n/a (mechanical: the bridge's own error, observed by calling a tool with no runner) → evidence/mcp-entry.md | task 7.3 | red |
| server-runtime → The server is supported only as a Linux container | Supported platform stated | T/policy_docs_test.dart | deploy README states linux/amd64 container support and native Windows and macOS servers unsupported | red |
| server-runtime → The server is supported only as a Linux container | Server tests on a non-Linux runner | T/ci_workflow_test.dart | server tests run only in the linux server job; check never runs test:server | red |
| server-health → The health endpoint returns a typed answer | All dependencies up | S/integration/health_endpoint_test.dart | all dependencies up | red |
| server-health → The health endpoint returns a typed answer | Redis down | S/integration/health_endpoint_test.dart | redis down: postgres up, redis down, no host or error text | red |
| server-health → The health endpoint returns a typed answer | Postgres down | S/integration/health_endpoint_test.dart | postgres down: answer within 10 seconds with postgres down | red |
| server-health → Liveness and readiness probes answer over HTTP | Ready server | S/integration/probes_test.dart | ready server: readyz 200 | red |
| server-health → Liveness and readiness probes answer over HTTP | Dependency lost | S/integration/probes_test.dart | dependency lost after start: livez 200, readyz 503, no details | red |
| self-host-stack → One Compose file runs the whole stack | Stack comes up | C/stack/stack_test.dart (tag `stack`) | readyz 200 and health through caddy holds postgres up and redis up; plus T/compose_config_test.dart: four services and a migrate step with named volumes | red |
| self-host-stack → One Compose file runs the whole stack | Data survives a restart | C/stack/stack_test.dart (tag `stack`) | down and up keeps the database and applies no migration twice | red |
| self-host-stack → One Compose file runs the whole stack | Migration fails | C/stack/stack_test.dart (tag `stack`) | an unknown migration stops migrate and server never starts; plus T/compose_config_test.dart: server depends on migrate completed successfully | red |
| self-host-stack → One Compose file runs the whole stack | A backing service fails to start | T/compose_config_test.dart | migrate depends on postgres and redis healthy and both have healthchecks | red |
| self-host-stack → Caddy is the only published entry point | Web app and API through one origin | C/stack/stack_test.dart (tag `stack`) | index.html at / and generated-client health call at http://localhost/api/ | red |
| self-host-stack → Caddy is the only published entry point | Unknown path under the API prefix | C/stack/stack_test.dart (tag `stack`) | /api/no-such-endpoint returns the server's not-found, never index.html | red |
| self-host-stack → Caddy is the only published entry point | Not reachable from the network | T/compose_config_test.dart | only caddy publishes a port, bound to 127.0.0.1 | red |
| self-host-stack → Caddy is the only published entry point | Internal services are not published | T/compose_config_test.dart | only caddy publishes a port, bound to 127.0.0.1 | red |
| self-host-stack → Stack secrets are never committed | Example file only | T/gitignore_test.dart | deploy env example is tracked with placeholders and deploy .env is ignored | red |
| self-host-stack → Stack secrets are never committed | Missing secret | T/compose_config_test.dart | every secret uses the required-variable form; plus C/stack/stack_test.dart (tag `stack`): compose up with an empty secret stops naming the variable | red |
| continuous-integration → CI runs the server tests on Linux | Server tests pass | T/ci_workflow_test.dart | server job on linux runs server:setup, starts dev redis, runs server:drift and test:server; evidence: task 8.2 | red |
| continuous-integration → CI runs the server tests on Linux | Redis container missing | T/ci_workflow_test.dart | server job waits for redis healthy in a named step before tests | red |
| continuous-integration → CI runs the server tests on Linux | Generated client stale | T/ci_workflow_test.dart | server job runs server:drift; drift behaviour → evidence/drift-check.md | red |
| continuous-integration → CI runs the server tests on Linux | A server test fails | T/ci_workflow_test.dart | server job is separate from check and check jobs keep fail-fast off | red |
| continuous-integration → CI checks the self-host stack on Linux | Stack healthy | T/ci_workflow_test.dart | stack job on linux generates placeholder secrets, builds web, runs stack:test; evidence: task 8.2 | red |
| continuous-integration → CI checks the self-host stack on Linux | Stack never becomes ready | T/ci_workflow_test.dart | stack job prints every service log on failure and always runs compose down with volumes | red |
| workspace-layout → Analysis and formatting are clean | Clean workspace | n/a (mechanical: `mise run check` exit 0 with the server packages present) → evidence/check-task.md | task 8.1 | red |
| workspace-layout → Analysis and formatting are clean | An analysis info | n/a (mechanical: a planted `info` in hand-written server code makes `mise run analyze` exit non-zero) → evidence/check-task.md | task 8.1 | red |
| workspace-layout → Analysis and formatting are clean | Files outside the workspace members | T/workspace_test.dart | format directories are workspace members only (re-run) | green |
| workspace-layout → Analysis and formatting are clean | An unformatted file | n/a (mechanical: `dart format --set-exit-if-changed` on a planted file) → evidence/check-task.md | task 8.1 | green |
| workspace-layout → Analysis and formatting are clean | Generated code | T/analysis_options_test.dart | analysis excludes exactly the generated server and client paths; plus evidence/check-task.md: an unformatted generated file fails format:check | red |
| workspace-layout → Packages follow the placement and naming rule | Current packages comply | T/workspace_test.dart | current layout reports app, core, tools, server and client and passes | green |
| workspace-layout → Packages follow the placement and naming rule | A misplaced or misnamed package | T/workspace_test.dart | missing prefix or directory mismatch fails with rule (extended to `server/`) | green |
| workspace-layout → One task runs every local check | All checks pass | n/a (mechanical: `mise run check` exit 0; its log shows no server test ran and the server packages analysed) → evidence/check-task.md | task 8.1 | red |
| workspace-layout → One task runs every local check | One check fails | n/a (mechanical: `mise run check` non-zero with a planted failure) → evidence/check-task.md | task 8.1 | green |
| workspace-layout → One task runs every local check | Server tests run on their own | n/a (mechanical: `mise run test:server` exit 0, then non-zero naming a planted failing test) → evidence/server-tests.md | task 3.6 | red |

## 1. Server packages in the workspace

- [x] 1.1 Verify A7 and A1: add `server/kaname_server` (from the pinned Serverpod 4.1 CLI's `create`, run through `mise exec -- dart run` from a temporary package, not a global install) and `server/kaname_client` as root workspace members with `serverpod_cli` as a server dev dependency; `mise run resolve` must succeed with the Flutter-pinned `flutter_test` versions. A resolve conflict stops the change and goes to the owner.
- [x] 1.2 Verify A9: record where the pinned CLI writes generated code in both packages; if it differs from `lib/src/generated/` and `lib/src/protocol/`, use the real paths in 2.2 and note them in design.md under the drift rule.
- [x] 1.3 Strip the scaffold to Serverpod core (S6): remove auth/IdP modules, example endpoints and models, the scaffold's Flutter app and its own Compose file; keep `config/` and `migrations/`. Verify `mise exec -- dart analyze server/` reports no issues.
- [x] 1.4 [evidence] Capture the scaffold record: CLI version, the `create` output paths, the resolve result, and `mise exec -C server/kaname_server -- dart run serverpod_cli version` → evidence/scaffold.md
- [x] 1.5 Write failing tests in `T/workspace_test.dart`: "current layout reports app, core, tools, server and client and passes" and the misnamed-package test extended to `server/`, plus the resolve test row; update `tools/kaname_tools/lib/src/workspace.dart` so `server/` packages are recognised; verify they pass and flip the rows green. Re-run "format directories are workspace members only".
- [x] 1.6 Regenerate THIRD_PARTY_NOTICES (`mise run notices`) and make `mise run licences` pass for the new pub dependencies; any exception goes to task 1.7.
- [ ] 1.7 [user] Approve or reject each licence exception the agent proposes from task 1.6, with a date, or confirm that none were needed. The agent writes approved entries, and `mise run licences` passes.

## 2. Analysis, formatting and the drift check

- [ ] 2.1 Write failing `T/analysis_options_test.dart` ("analysis excludes exactly the generated server and client paths").
- [ ] 2.2 Exclude the generated paths in `analysis_options.yaml` (D7, C9); keep them in `format:check`. Verify the test passes and `mise run analyze` and `mise run format:check` exit 0; flip the row green.
- [ ] 2.3 Write C9 at its destination: confirm the `workspace-layout` delta's "Analysis and formatting are clean" requirement states that generated code is excluded from analysis but format-checked.
- [ ] 2.4 Add `mise run server:drift` (generate, `dart format`, `git diff --exit-code` over the generated paths). Verify it exits 0 on the clean tree.
- [ ] 2.5 [evidence] Change an endpoint signature without regenerating, run `mise run server:drift`, capture the non-zero exit and the named files, then revert → evidence/drift-check.md

## 3. Run-mode configuration, secrets and server tests

- [ ] 3.1 Write failing `S/unit/run_mode_config_test.dart` (Redis enabled with host and port in every mode; Insights and persistent session logs only in development, console logging everywhere).
- [ ] 3.2 Set `config/development.yaml`, `test.yaml`, `staging.yaml`, `production.yaml`: embedded Postgres `dataPath` in development and test, external Postgres in staging and production, Redis on everywhere (dev Redis on 127.0.0.1:8091, D6), Insights and persistent session logs per D8 and D10. Verify the tests pass; flip rows green.
- [ ] 3.3 Write failing `S/unit/setup_test.dart` (fresh tree; existing secrets unchanged) and `T/gitignore_test.dart` (embedded data, `passwords.yaml`, env files ignored; `deploy/.env.example` tracked).
- [ ] 3.4 Implement `server/kaname_server/tool/setup.dart` and `mise run server:setup` (D11): writes `config/passwords.yaml` with one Redis password for development and test and derives the dev Redis `.env`; never overwrites. Add the dev Redis service to `server/kaname_server/docker-compose.yaml` (digest-pinned `redis:8`, 127.0.0.1:8091, password from `.env`, healthcheck). Update `.gitignore`. Write C8 as the doc comment on `main` in `tool/setup.dart`. Verify both tests pass; flip rows green.
- [ ] 3.5 Add `mise run test:server` (starts nothing; expects dev Redis up; runs `dart test --exclude-tags stack` in both server packages) and confirm `mise run check`'s `test` task still runs only core, tools and app. Settle the design's open question here: record how `serverpod_test` reads the test Redis address in the first server test's file comment.
- [ ] 3.6 [evidence] From a fresh clone on Linux: `mise run resolve`, `mise run server:setup`, `docker compose up -d` in the server package, `mise run test:server` passes; then a planted failing test makes it exit non-zero naming the test; run `server:setup` again and show `git status` lists no secret → evidence/server-tests.md

## 4. Health endpoint, probes and migrations

- [ ] 4.1 Verify A4 and A8: a throwaway `withServerpod` test shows the test schema is created from the committed migrations, and an endpoint call completes while the embedded Postgres is stopped. If either fails, stop and take the spec change to the owner.
- [ ] 4.2 Write failing `S/integration/health_endpoint_test.dart` (all up; Redis down; Postgres down within 10 s; no host, port or error text in any answer).
- [ ] 4.3 Add the `HealthReport{version, postgres, redis}` model and `enum DependencyStatus{up, down}`, and the unauthenticated `health` endpoint with parallel `SELECT 1` and Redis PING, 2 s timeouts each (D4). Regenerate the client; verify the tests pass, `server:drift` is clean; flip rows green.
- [ ] 4.4 Verify A3: start the server with Redis enabled but unreachable and observe whether it starts with `/livez` 200 and `/readyz` 503. If it fails to start instead, stop and take the spec change to the owner.
- [ ] 4.5 Write failing `S/integration/probes_test.dart` (ready server; Redis unreachable at start with the log naming Redis; dependency lost after start), spawning the server process with `SERVERPOD_*` overrides; make them pass (custom readiness only if built-in probes don't meet the spec); flip rows green.
- [ ] 4.6 Verify A5, then write failing `S/integration/migrations_test.dart` (maintenance run applies every migration to an empty database; exits 1 naming the mismatch on a database holding an unknown migration). Create the initial migration (Serverpod's own tables) with the package-local CLI; verify the tests pass; flip rows green.
- [ ] 4.7 Write C4 as the doc comment on `main` in `server/kaname_server/bin/main.dart`: stack migrations run only in the one-shot maintenance step, because the monolith's `--apply-migrations` keeps serving after a failed migration outside development.

## 5. Server image

- [ ] 5.1 Write failing `T/dockerfile_test.dart`: no Dockerfile states a Flutter or Dart version; the build stage installs through mise in locked mode with checksum-verified mise 2026.11.8; `pub get --enforce-lockfile`; runtime is slim Debian with curl, non-root; `deploy/server.Dockerfile.dockerignore` denies by default and never admits `passwords.yaml` or `.env`.
- [ ] 5.2 Verify A6, then write `deploy/server.Dockerfile` per D5 (`platform: linux/amd64`, `dart compile exe`) and its dockerignore; verify the test passes and `docker build` succeeds on Linux; flip the structure row's part green.
- [ ] 5.3 Write C5 at its destination: confirm the `server-runtime` delta's "The server image takes its toolchain from mise" requirement states that no Dockerfile states a toolchain version.

## 6. Compose stack and Caddy

- [ ] 6.1 Write failing `T/compose_config_test.dart` (four services and a `migrate` step with named volumes; `migrate` after postgres and redis healthy; server after `migrate` completed successfully; only caddy publishes, on 127.0.0.1; every secret in `${VAR:?}` form).
- [ ] 6.2 Write `deploy/compose.yaml` (digest-pinned `postgres:16`, `redis:8`, `caddy:2`; production run mode; `.env` mapped to `SERVERPOD_PASSWORD_*`, D9), `deploy/Caddyfile` (web build at `/`, `/api/*` with the prefix stripped, `/livez` and `/readyz` passed through, D2, D12), `deploy/.env.example` with placeholders, and `deploy/README.md` stating the `linux/amd64` support boundary. Verify the T tests pass; flip rows green.
- [ ] 6.3 Verify A2: the generated client called with `http://localhost/api/` reaches the endpoint path under the prefix. If it does not, stop and take D2 back to the owner.
- [ ] 6.4 Write failing `C/stack/stack_test.dart` and `C/stack/image_test.dart` (tag `stack`) for every stack row in the test map; add `mise run stack:up`, `stack:test` and `stack:down` (down removes volumes). Run them against the stack on Linux; verify they pass; flip rows green.
- [ ] 6.5 Write failing `T/policy_docs_test.dart` case for the deploy README's support statement; verify it passes; flip the row green.
- [ ] 6.6 Write C6 as part of the doc comment on `LicencesCommand` in `tools/kaname_tools/lib/src/licences.dart`: container image licences (Postgres, Redis, Caddy, Debian) are outside the pub licence check and the SBOM.
- [ ] 6.7 Write C1, C2, C3 and C7 at their destinations: confirm the named requirements in `specs/server-runtime/spec.md` and `specs/self-host-stack/spec.md` hold that text (archive copies them into the main specs).

## 7. CI jobs and the MCP entry

- [ ] 7.1 Write failing `T/ci_workflow_test.dart` cases for the `server` and `stack` jobs (Linux only; setup, dev Redis health wait in a named step, `server:drift`, `test:server`; stack with placeholder secrets, host web build, `stack:test`, logs of every service on failure, `docker compose down -v` always) and update the existing timeout, pinning and resolve tests for the new jobs. Add both jobs to `.github/workflows/ci.yml` and the header's check-name rules; verify the tests pass; flip rows green.
- [ ] 7.2 Verify A10, then write failing `T/mcp_config_test.dart`; add the Serverpod entry (`mise exec -C server/kaname_server -- dart run serverpod_cli mcp-server --server-dir .`) to `.mcp.json` and `.omp/mcp.json`, enable and allow-list it in `.claude/settings.json`, and remove the M0 TODO from AGENTS.md. Verify the test passes; flip the row green.
- [ ] 7.3 [evidence] Start the MCP entry from the repository root: record the bridge naming `server/kaname_server`, then a tool call with no runner returning its "the server is not running" error → evidence/mcp-entry.md

## 8. Integration on the pull request

- [ ] 8.1 [evidence] Run `mise run check` on Linux from a clean tree: exit 0, the log shows the server packages analysed and format-checked and no server test run; then planted failures (an analysis info in hand-written server code, an unformatted hand-written file, an unformatted generated file, a failing core test) each make it exit non-zero naming what failed; revert → evidence/check-task.md
- [ ] 8.2 [evidence] Capture this change's PR run: every job's name, runner and conclusion (all `success`, including `server` and `stack`), taken from `gh run view --json jobs` through the fenced KintsugiBot credential → evidence/ci-run.md
- [ ] 8.3 [evidence] Capture the trailer block of each commit on this branch (`git log main..HEAD --format=%H%n%(trailers)`), showing the owner's `Signed-off-by` before the single `Co-authored-by`, and the `signoff` job's passing output → evidence/commit-trailers.md
- [ ] 8.4 [user] In main's branch protection, add `server` and `stack` as required status checks, then confirm by ticking this task.

## Workflow follow-up

- The M0 exit criterion's on-screen part (the web app shows the health answer) is judged at milestone close, after `app-shell` wires the generated client into the app (proposal, Why).
- After the owner merges the PR, `specwright-finish` handles cleanup. The next M0 changes are `ember-theme` and `app-shell`.
