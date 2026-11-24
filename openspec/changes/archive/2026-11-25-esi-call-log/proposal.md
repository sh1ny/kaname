# Proposal

## Why

M2 change 3 builds on the archived `esi-request-scheduler` so operators and pilots can distinguish ESI failures from intentional refusals without exposing authorization secrets or other pilots’ histories. It advances the agent-verified call-log exit criterion; the owner’s sign-in demo remains at M2 close after `esi-sso`.

## What Changes

- Record scheduler outcomes with catalogue route, outcome/status, cost, latency and bucket, using only an explicit allowlist of fields. Refusals are not errors.
- Keep seven days of history; exclude expired rows from reads and remove them from storage.
- Apply ADR 0006 at the data-access layer: return only the viewer’s rows and expose only route-level totals and errors to admins, with minimum group size and no drill-down. Admins cannot see another member’s rows in M2.
- Out of scope: token vault, SSO, policy sharing/consent, remote client delivery and UI. No temporary key or unauthenticated lookup.

## Capabilities

### New Capabilities

- `esi-call-log`: secret-free scheduler history, retention, and privacy-scoped reads.

### Modified Capabilities

None.

## Impact

Shared ESI scheduler and its runtime compositions, server persistence and pruning, and server-side privacy-scoped reads. No public wire change.

Manual branch gate (authorized Orca workaround): OpenSpec is repo-local; the clean worktree was already on `feat/esi-call-log` at `86904e724af4d46f02db5fd5810f8e87c8eec861`, identical to local `main` and freshly fetched GitHub `main`. The scheduler archive existed, with no active or archived call-log change. The released Specwright 0.39.1 binary and notices passed checksum verification and were installed only in this worktree; the binary reported interface 3. The gate did not switch the main checkout.

## Decision Making

DECISION_MAKING: all
- **Source:** setting. Dispatch delegates inner design decisions to the author and reserves scope decisions for the coordinator.

### S1: Read delivery before SSO

- **Choice:** implement and verify own-row and admin aggregate reads at the data-access interface, taking a trusted viewer resolved by the caller. No client RPC in this change. `esi-sso` owns exposing both reads to the app once validated identity is available.
- **Rejected:** publish RPC signatures that necessarily reject all production callers until SSO; use a shared key or accept viewer identity from a client.
- **Reversal cost:** low; a later authenticated adapter can call the scoped interface without altering its predicates.
- **Important:** yes, defines the delivery surface for this change.
- **Chosen by:** user (option A).

### S2: Worker database lifecycle

- **Choice:** ship the shared scheduler receipt sink and server data-access logging, retention and privacy now. The first production ESI worker binds the sink to its own job-owned PostgreSQL connection under ADR 0012.
- **Rejected:** introduce worker-specific PostgreSQL transaction integration and its SQL compatibility tests without a production ESI worker job.
- **Reversal cost:** low.
- **Important:** yes, defines integration scope.
- **Chosen by:** user, 2026-11-25 (Ormy item 51): “Yes, cut it” in answer to “cut the background-job logging layer and leave it to the first real ESI background job?”
