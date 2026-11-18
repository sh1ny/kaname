# 0012. Worker isolate access

- Status: accepted (2026-11-19)
- Date: 2026-11-19
- Supersedes: none
- Chosen by: user (2026-11-19, `sde-import` design D1 and its review rounds 1 and 2)

## Context
ADR 0009 runs long work on worker isolates and leaves open how a worker reaches Postgres, Redis, the token vault, the privacy scope and the `RealtimeBus` (strategy R56). Serverpod's ORM and `session.messages` need a `Session`, which a spawned isolate does not have.

The first worker is the compute worker, and its first job is the static-data import (`sde-import`). It writes about a million rows per SDE build and needs Postgres only. A `Session` cannot be had in a worker without constructing a second `Serverpod`: in Serverpod 4.1.2, `Serverpod.createSession` builds its session on the instance's own server and database pool, and the constructor calls `exit(1)` on any initialisation error, which would end the whole server process.

## Decision
- **Postgres (C1):** a worker isolate reaches Postgres only through connections it opens itself, per job, from a typed start message, behind Kaname interfaces; never through a Serverpod `Session` and never by copying rows through the main isolate.
  - The main isolate sends the resolved connection settings (host, port, database, user, password, TLS) in the worker's start message. The message's text form never shows the password.
  - A job opens its connection when it starts and closes it when it ends, so a Postgres restart affects only the jobs running at that moment, and the next job reconnects.
  - Job code depends only on Kaname interfaces (for the importer, `StaticDataStore`). The server implements them in plain SQL; solo implements them on its local store.
  - Tables stay declared in `.spy.yaml`, so Serverpod migrations own the schema and the main isolate reads them through the ORM. A contract test keeps the worker's SQL in step with the generated tables.
- **Still open (C2):** how a worker reaches Redis, the token vault, the privacy scope and the `RealtimeBus` stays open in R56. ADR 0008 builds the bus on Serverpod's message system, so the first worker that publishes (the realtime worker, M11) settles these and reconciles them with ADR 0008. Proxying through the main isolate over typed messages (ADR 0009) remains a candidate for them.
- **Static-data lock (C3):** imports take a Postgres session advisory lock on a fixed static-data key before anything else and hold it until the job ends. This is compatible with ADR 0009's "no extra locks on top of the future-call claim": the lock guards writers outside any future-call claim (the development import task runs in its own process), and Postgres releases it with the session, so it has none of the stale-lock failure that ADR 0009 rejected Redis locks for. A short transaction-scoped try-lock on the same key lets the start hook and the worker supervisor sweep stale import records only when no import is live.

## Consequences
- Every later worker follows this rule for Postgres. Worker connections sit outside the main isolate's pool and count against Postgres's connection limit: one per running job.
- Credentials cross isolates only inside the process, in a message whose text form redacts them.
- The import takes one long transaction on one connection, outside the main pool; its duration and WAL growth are measured by the opt-in live import.
- **Rejected:**
  - Proxying Postgres writes through the main isolate: every row of a million-row build would be copied across isolates and written by the endpoint isolate, which ADR 0009 keeps free of long work.
  - An unstarted `Serverpod` in the worker: it depends on Serverpod internals, and its constructor's `exit(1)` would end the server process.
  - One long-lived worker connection with reconnect logic: more state in the worker for no gain at one job a day.
  - Settling the bus, Redis, the vault and the privacy scope now: a job that publishes nothing gives no evidence for them.
- **Reversal cost:** medium. Job code sees only Kaname interfaces, so changing how the server implements them stays inside `kaname_server`.
