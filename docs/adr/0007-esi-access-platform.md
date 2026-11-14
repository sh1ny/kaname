# 0007. ESI access platform

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-14, including the review fixes for atomic budget, refresh and loop bounds)

## Context
Every module pulls ESI data. ESI publishes an OpenAPI 3.1 spec with rate-limit groups (`x-rate-limit`), scopes and required roles for each route. Rate limits are token buckets per route group and per (application, character), over a 15-minute window. A separate error limit applies to each connection, and one misbehaving route can lock a whole install out. Refresh tokens are long-lived secrets that may rotate on every refresh.

## Decision
- **Generated client:**
  - Kaname's own generator reads ESI's spec at one pinned compatibility date;
  - it produces a typed client plus a route catalogue (rate group, scopes, roles, cache behaviour);
  - bumping the date is a single PR with a spec diff and contract tests over recorded responses.
- **One scheduler policy for every call.** Each isolate that calls ESI uses the same scheduler code against one shared budget state:
  - **Atomic reservation.** A call reserves its cost before it is sent, through one atomic check-and-spend: a Redis script on the server, in-process in solo. Two isolates can never both spend a bucket's last tokens. Response headers then correct the mirror.
  - **Bucket mirror** per (group, character) and per connection.
  - **Governor** driven by the error budget and bucket pressure, with four tiers: full, spaced, single, stopped.
  - **Priorities:** interactive, realtime, notifications, sync, backfill.
  - **Shared negative cache** for 403 and 404 responses.
  - **Polite polling:** `If-None-Match` on every call; respect for `Expires`, capped at a sane maximum; per-install jitter; a pause during downtime or when TQ is unreachable.
  - **Corp endpoints** are polled once per corp, with a qualified role holder.

  A refused call is logged as "not sent", never as an error.
- **Hot loops are bounded:**
  - only online characters whose owners turned tracking on;
  - a minimum interval per loop;
  - a capped share of each bucket, so interactive and sync calls are never starved.

  The exact numbers come with the loops (M11, M17).
- **Call log:**
  - route, status, cost, latency and bucket after each call, kept 7 days, never holding tokens;
  - its visibility follows ADR 0006.
- **Token vault:**
  - refresh tokens are encrypted with an install key from an environment variable or secret file, never stored in the database or logged;
  - **refresh is single-flight per character** (one lock per character id around refresh and save);
  - the new refresh token is saved as soon as CCP returns it, before the access token is used;
  - on `invalid_grant`, the refresher re-reads the stored token under the lock and retries once if it differs; this covers an expired lock, not a crash. A crash between CCP's answer and the save loses the rotated token: the token is marked dead and the member logs in again;
  - a token confirmed dead notifies the member and is never retried.
- **Scopes:**
  - one login per character asks for the scope set ADR 0006 defines (enabled modules, limited by the org's policy, plus the member's opt-ins);
  - adding a module or opt-in prompts a re-authorisation, not a second token.
- **SSO v2:**
  - a confidential web flow for the server and a PKCE native flow for solo devices;
  - JWTs validated offline against CCP's JWKS (issuer, audience, expiry, subject);
  - a custom Serverpod identity provider maps characters to users.
- **Identity:** a User-Agent with the install's contact details, and one compatibility date pinned in one place.

## Consequences
- Modules declare sync recipes. They never call ESI directly.
- Backups must include the vault key separately, and the docs say so loudly.
- **Rejected:**
  - Hand-written routes: scopes and rate groups drift.
  - Per-module throttling: it cannot see the shared error budget.
  - Read-then-spend bucket checks: they race between isolates.
  - Plain-text tokens: a database dump leaks every character.
- **Reversal cost:** high. Every module's data depends on this layer.
