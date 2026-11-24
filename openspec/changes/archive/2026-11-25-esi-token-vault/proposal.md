# Proposal

## Why

Refresh credentials can outlive a process and may rotate on every refresh. M2 change 4 advances the vault exit criterion: one holder per character, encrypted refresh credentials with a separately backed-up key, single-flight refresh, rotation recovery, and required re-login when a rotated token is lost. The owner's live demo in both modes remains an M2 close criterion after `esi-sso` wires the flows.

## What Changes

- Add a reusable vault that enforces one active holder for each character in its authoritative store. Refuse a different holder until the current one has parked, and never consult another store when that authority is unavailable.
- Add durable Postgres storage for the server. Encrypt refresh credentials before storage with a dedicated install key supplied outside the database. Supply the same vault logic behind a storage seam for native use without choosing the general solo store.
- Serialize refresh by character. Save a rotated refresh token before releasing its access token; recover once from a changed stored token, or persist a re-login requirement when the credential is confirmed dead. Report only typed, secret-free failures.

Out of scope: call logging, OAuth sign-in and refresh HTTP composition, JWT/JWKS, Serverpod identity, live server↔device handoff wiring, user-facing notifications, choosing the general M4 solo store, and deciding how future workers obtain vault access. This change provides the credential lifecycle and failure contract that later consumers wire; it does not claim to arbitrate independently provisioned offline stores.

## Capabilities

### New Capabilities

- `esi-token-vault`: exclusive holder and encrypted credential persistence, single-flight refresh and rotation recovery.

### Modified Capabilities

None. The scheduler's existing bearer callback stays unchanged.

## Impact

Shared Dart vault, server-only Postgres adapter and migration, out-of-database key configuration, dependency notices, and automated tests with synthetic credentials. The owner-approved Orca branch-gate workaround checked that the OpenSpec root is repo-local, `feat/esi-token-vault` was clean at the same commit as both `main` and the freshly fetched `origin/main` (`86904e724af4d46f02db5fd5810f8e87c8eec861`), and no change or archive already existed. Specwright 0.39.1 (interface 3) was bootstrapped in this worktree only.

## Decision Making

DECISION_MAKING: all
- **Source:** setting, with the dispatch's explicit override: “scope decisions … come back to me as an orchestration question … Inner design details (package layout, storage shape, cipher wiring, locking mechanics) you decide yourself”.

### S1: Vault authority and handoff scope

- **Choice:** Enforce one active holder per character in one authoritative vault. Refuse another holder until the current holder parks, and share vault logic with native consumers. No global exclusivity across independent stores. `esi-sso` owns the real server↔device handoff and wiring; the general solo store choice stays in M4.
- **Rejected:** Build cross-install handoff inside the vault change. Independent offline stores have no shared observation of the holder; moving handoff here would also move product wiring ahead of `esi-sso`.
- **Reversal cost:** medium.
- **Important:** yes, binds future consumers.
- **Chosen by:** user. The owner confirmed option A through Orca after the author drafted the same boundary.

### S2: Change boundary

- **Choice:** Implement vault and refresh policy without pulling in `esi-call-log` or `esi-sso` flows, JWT/JWKS, or Serverpod identity.
- **Rejected:** Add a product sign-in flow or a logging dependency to drive the vault; synthetic exchanges can verify the contract independently.
- **Reversal cost:** low.
- **Important:** yes, separates roadmap changes.
- **Chosen by:** user.
