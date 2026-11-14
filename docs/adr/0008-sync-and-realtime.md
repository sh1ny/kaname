# 0008. Sync and realtime

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-14; bus on Redis and LWW ordering deferred to M4 after review)

## Context
Connected clients keep an offline cache (limited by ADR 0006) and edit some personal records offline. The mapper, fleets, waitlist and timers need live, collaborative updates. Every install runs Redis and one server instance in 1.0 (ADR 0001).

## Decision
- **Sync:**
  - The server is the source of truth.
  - Each syncable table carries id (UUIDv7), owner, version, `updated_at` and `deleted_at`.
  - The server keeps a per-user change log with a monotonic sequence. Clients pull since a sequence and push edits with their base version.
  - Personal records (fits, plans, notes, alarms, layouts) merge per field, with the losing value kept in history. Org records (doctrines, timers, maps) are edited online only.
  - **Open, settled in M4 before any client ships:** what orders concurrent edits to one field. The lean is a hybrid logical clock stamp per field edit. Server arrival order alone is not acceptable, because an old offline edit would overwrite a newer one.
- **Realtime:**
  - Serverpod WebSocket streams carry live updates and sync invalidation to clients.
  - Fan-out goes through one `RealtimeBus` interface built on Serverpod's message system, which delivers locally on one instance and across instances through Redis.
  - Every delivery passes the privacy scope (ADR 0006).
  - Collaborative objects are an append-only event log with a per-object sequence. Clients apply events in order and resync on a gap.
  - Field-level merge, monotonic states, and soft delete with undo.

## Consequences
- Every syncable model follows the column convention from the start.
- **Rejected:**
  - CRDTs everywhere: heavy, and org data needs a single authority.
  - Record-level last-writer-wins: it loses concurrent edits to other fields of the same record.
  - A bus that also works without Redis: Redis is always present (ADR 0001).
- **Reversal cost:** high for the sync protocol, because clients will already be in the field; medium for the bus, which sits behind an interface.
