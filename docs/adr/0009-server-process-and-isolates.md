# 0009. Server process and isolate model

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-14, including the review fixes for job reuse, locks and compute isolates)

## Context
The server:
- answers requests;
- runs recurring jobs (sync recipes, affiliation, static-data checks);
- runs hot polling loops (location every few seconds, fleet members, a killmail stream);
- imports static-data builds;
- computes fits;
- keeps a Discord gateway connection.

A small alliance install must fit in 2 vCPU and 4 GB, on one instance (ADR 0001). Serverpod future calls are stored in the database, are claimed for one execution across the cluster, and must be idempotent (installed skill `serverpod-scheduling`). The solo engine has no Serverpod server.

## Decision
- One Serverpod server process per install.
- **Job logic lives in pure-Dart packages behind a job-runner interface:** sync recipes, recurring jobs and their schedules. A Serverpod future call (`callRecurring` with an interval or a cron) is the server's adapter; the solo engine has its own in-process adapter. Jobs are idempotent. No extra locks are added on top of the future-call claim.
- **Main isolate:** endpoints and the future-call adapter. Long work moves off it.
- **Realtime worker isolate:** the hot loops. Location and fleet polling and the killmail stream use the shared scheduler and its loop bounds (ADR 0007).
- **Discord worker isolate:** the gateway connection and a REST queue per route bucket that honours Discord's rate limits.
- **Compute worker isolate:** static-data import and bundle building, and fit-engine calls. The engine stays in-process over FFI, off the endpoint isolate.
- Workers talk to the main isolate through typed messages and the `RealtimeBus` (ADR 0008). With one instance in 1.0, each worker runs exactly once.
- **Open, settled by the first change that adds a worker isolate (strategy R56):** how a worker isolate reaches Postgres, Redis, the token vault, the privacy scope and the `RealtimeBus`. Serverpod's ORM and `session.messages` need a `Session`, which a spawned isolate does not have; the candidates are proxying through the main isolate over typed messages, or worker-owned connections behind the same interfaces.

## Consequences
- Cross-isolate messages are typed, versioned models, never ad hoc maps.
- A crashed worker is restarted and reported on the admin health page.
- **Rejected:**
  - Separate worker containers: more deployment parts for small installs.
  - Writing jobs as `FutureCall` subclasses directly: solo could not run them.
  - Redis locks on top of future calls: a second mechanism with its own stale-lock failure.
- **Reversal cost:** medium. Workers talk only through messages and the bus, so moving one into its own process stays contained.
