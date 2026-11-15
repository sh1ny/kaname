# Proposal

## Why

Kaname has no server yet. The architecture rests on one Serverpod process with Postgres and Redis behind Caddy (ADR 0001, ADR 0009), but none of it exists, so nothing proves that the pinned toolchain, the pub workspace and the Compose deployment fit together. This change serves roadmap **M0 - Walking skeleton** (change 3 of 6; prerequisite `repo-scaffold`, done). It advances the agent-verified exit criterion "`docker compose up` runs Serverpod, Postgres, Redis and Caddy locally. The web app loads and shows the health endpoint's answer. The Serverpod MCP entry is configured for the server package." It delivers the stack, the typed health endpoint, the placeholder web app served by Caddy, and the MCP entry. Showing the health answer on screen needs the generated client wired into the app, which is `app-shell`'s work (roadmap change 5), so that part of the criterion is judged at the milestone close. It also resolves the M0 TODO in AGENTS.md (the Serverpod MCP entry) and gives `app-shell` its first server-to-app contract. On the CI exit criterion ("runs every package's tests"), CI still runs every package's tests after this change, but the server packages' tests run on Linux only, because the server only ever runs in a Linux container (S5); the Windows and macOS runners analyse and format-check the server packages.

## What Changes

- New server packages in the root workspace: `server/kaname_server` (Serverpod 4.1, core only, no auth or other modules, the scaffold's examples removed) and its generated client `server/kaname_client`. The Serverpod CLI becomes a package-local dev dependency of the server, pinned through the lockfile, never installed globally.
- Run modes and backing services:
  - Postgres: development and test use Serverpod's embedded Postgres; the Compose stack and production use a Postgres 16+ container.
  - Redis is on in every server run mode (R48, R30, ADR 0007): a container from `serverpod start --docker` in development, a container from the server package's development Compose file in CI tests, and a Compose service in the stack.
  - The server is supported only as a Linux container.
- Initial migration (Serverpod's own tables). In the stack, a one-shot migration step applies it before the server starts.
- A setup task writes ignored development and test secrets on a fresh clone. The server image gets its toolchain through mise from `mise.lock`.
- A typed `health` endpoint through the generated client: server version, plus Postgres and Redis status. Serverpod's built-in `/livez` and `/readyz` probes are kept for Compose healthchecks.
- `deploy/compose.yaml` runs `server` (built from a Dockerfile), `postgres`, `redis` and `caddy`:
  - Caddy serves the current placeholder web build and proxies the API under `/api/` on plain HTTP, published on `127.0.0.1` only.
  - Secrets come from an uncommitted environment file, with a committed example.
- CI:
  - `mise run check` keeps running on Linux, Windows and macOS. It analyses and format-checks the server packages but does not run their tests.
  - A new Linux `server` job runs the server tests and the generated-client drift check, with Redis from the server package's development container.
  - A new Linux `stack` job runs `docker compose up` and asserts the health answer through Caddy.
  - Two new required check names on `main` (a `[user]` task).
- The Serverpod MCP entry (`mise exec -C server/kaname_server -- dart run serverpod_cli mcp-server --server-dir .`) goes in `.mcp.json` and `.omp/mcp.json`, and is enabled and allow-listed in `.claude/settings.json`. The M0 TODO in AGENTS.md is removed.
- THIRD_PARTY_NOTICES is regenerated, and the licence check covers the new pub dependencies.

## Capabilities

### New Capabilities
- `server-runtime`: the server packages, run modes, backing services per mode (Postgres, Redis always on), migrations at start, and the Linux-container-only support boundary.
- `server-health`: the typed health endpoint and its answer, and the liveness and readiness probes.
- `self-host-stack`: the Compose stack's services, how Caddy serves the web app and proxies the API, and how its secrets are supplied.

### Modified Capabilities
- `continuous-integration`: server tests and the stack check run in Linux jobs; the three-OS `check` covers server analysis and formatting, but not server tests.
- `workspace-layout`: the current-packages scenarios also report `kaname_server` and `kaname_client` under `server/`.

## Impact

- New: `server/kaname_server/` (with a development Compose file for Redis and a setup tool), `server/kaname_client/`, `deploy/` (compose file, Caddyfile, Dockerfile, environment example), server tests, mise tasks for the server and the stack.
- Changed: root `pubspec.yaml` (workspace members), `pubspec.lock`, `analysis_options.yaml` (generated code excluded), `THIRD_PARTY_NOTICES`, `.github/workflows/ci.yml`, `.mcp.json`, `.omp/mcp.json`, `.claude/settings.json`, `AGENTS.md`, `.gitignore` (embedded database data, passwords, the environment file).
- GitHub: two more required status checks on `main` (owner setting).
- Licences: the `serverpod` package (4.1.2) is licensed under SSPL v1, unlike the BSD-3 `serverpod_*` packages, and `postgres` 3.6.0 has an unfilled BSD-3 template. Both pass the licence check only through owner-approved, version-pinned exceptions (design D13).
- Container images (Postgres, Redis, Caddy, Debian) are pulled at run time, not vendored. Their licences sit outside the pub licence check, like the native-dependency gap `ci-matrix` named. The design checks which Redis image and licence fit ADR 0002.
- Local development needs Docker for Redis. Server tests need Docker on Linux only.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: The health contract

- **Choice:** A typed Kaname `health` Serverpod endpoint (server version, Postgres and Redis status) through the generated client, plus Serverpod's built-in `/livez` and `/readyz` for Compose healthchecks.
- **Rejected:** Built-in probes only (the app would read an HTTP status, with no generated-client contract).
- **Reversal cost:** medium
- **Important:** yes, binds future changes (the first server-to-app contract)
- **Chosen by:** user

### S2: Postgres per run mode

- **Choice:** Embedded Postgres for development and test runs; a Postgres 16+ container in the Compose stack and production.
- **Rejected:** Compose Postgres everywhere (tests would need Docker for the database too).
- **Reversal cost:** low
- **Important:** yes, binds future changes (test harness and config shape)
- **Chosen by:** user

### S3: Compose location and what Caddy serves

- **Choice:** `deploy/compose.yaml` (ADR 0003's `deploy/`). Caddy serves the placeholder web build and proxies the API on plain `http://localhost`; `app-shell` adds the health call on screen.
- **Rejected:** Caddy proxying the API only until `app-shell`; Compose inside the server package (Serverpod's scaffold default).
- **Reversal cost:** low
- **Important:** yes, changes what self-hosters see and run
- **Chosen by:** user

### S4: CI for the server

- **Choice:** A Linux `server` job for the server tests and a Linux `stack` job that runs `docker compose up` and asserts the health answer through Caddy. `check` on all three OSes covers server analysis and formatting.
- **Rejected:** Compose checked only locally; server tests on all three OSes (see S5).
- **Reversal cost:** low
- **Important:** yes, changes behaviour contributors see (new required checks)
- **Chosen by:** user

### S5: Redis in every server run mode; server tests on Linux only

- **Choice:** Redis on in development, test, the Compose stack and production, so the server keeps one bus and budget design (R48, R30, ADR 0007). Desktop and mobile never use Redis: connected, they talk only to the server; in solo and solo-lite, the budget runs in process. The server runs only as a Linux container, so its tests and the stack check run only on Linux, against a Redis container.
- **Rejected:** Redis off in development and test (reopens R48/R30: a second server code path that no install runs); native Redis on Windows and macOS runners (tests a setup no user has; the Windows port is unofficial).
- **Reversal cost:** medium
- **Important:** yes, binds future changes (run-mode config, test harness, support boundary)
- **Chosen by:** user (after discussion, 2026-11-15)

### S6: Serverpod modules

- **Choice:** Serverpod core only. No auth or IdP module (EVE SSO lands in M2) and no other modules; the scaffold's example endpoints and models are removed.
- **Rejected:** Keeping the scaffold's auth IdP module for M2.
- **Reversal cost:** low
- **Important:** yes, binds future changes (the module set and migrations)
- **Chosen by:** user

### S7: Where the Serverpod MCP entry is configured

- **Choice:** Both `.mcp.json` and `.omp/mcp.json`, enabled and allow-listed in `.claude/settings.json`; the AGENTS.md TODO is removed.
- **Rejected:** Claude only.
- **Reversal cost:** low
- **Important:** yes, changes the tools agents see
- **Chosen by:** user
