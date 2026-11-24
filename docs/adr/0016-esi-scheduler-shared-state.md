# 0016. Shared ESI scheduler state

- Status: accepted (2026-11-24)
- Date: 2026-11-24
- Supersedes: none; resolves the ESI Redis portion of ADR 0012's open decision.
- Chosen by: agent (inner design delegated by owner; reviewed in `esi-request-scheduler`).

## Context

ADR 0007 requires a single atomic check-and-spend across server isolates. ADR 0012 gives compute workers their own per-job Postgres connections and leaves Redis access open. The production Compose service runs one monolith on the default network; it defines no separate ESI-worker egress. The scheduler conservatively models one egress per install, not one legacy error budget per Dart socket or isolate. ADR 0005 keeps server and solo token ownership separate.

## Decision

Every ESI-calling server isolate owns its Redis command connection to the same scheduler namespace. The connection is bounded and reused for short commands, not obtained through a Serverpod session or proxied through the main isolate. Lua performs atomic admission and completion. Redis failure never permits local fallback. A corporation claim covers one in-flight HTTP poll; it does not lock a future call or surround a whole job (ADR 0009).

Native solo uses one in-process store. That store enforces atomicity only for its runtime; startup pacing cannot recover debits lost on process exit. Revisit durable solo limiter state when M4 chooses the solo local store. The vault and worker privacy-scope decisions remain open.

## Consequences

- Rejected main-isolate proxy: each time-sensitive admission and completion would depend on the endpoint isolate even though Redis is already the authority.
- Rejected a Redis connection per call: repeated TCP/auth handshakes on every short scheduling operation, unlike occasional long Postgres jobs.
- Reversal cost: medium. The state interface separates callers from Redis connection ownership, but a topology change must preserve budget scope and atomicity.
