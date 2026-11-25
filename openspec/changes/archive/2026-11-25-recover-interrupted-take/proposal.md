# Proposal

## Why

A desktop take can stay in `taking` when the server's refusal never reaches the desktop or the process exits before restoring local state ([#40](https://github.com/sh1ny/kaname/issues/40)). This M2 ESI platform and SSO follow-up protects the one-holder rule without changing the roadmap or adding a manual acceptance gate.

## What Changes

- Save the previous character and selection durably before sending a new take. Use the pending intent's original proof when reconciling with the same source.
- Restore local state only when the source confirms that the exact intent never took the holder and cannot be accepted later. Keep the proof if the source accepted the intent or the outcome remains unknown.
- Preserve the existing reservation-resume path for pre-upgrade journals. Do not infer a prior row or selection that an older desktop did not save.
- Keep the holder gate, source parking, release and reclaim policy unchanged. This change does not address account refresh versus sign-out (#41) or unreferenced proof cleanup (#43).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `esi-sso`: Add safe recovery of interrupted desktop takes when the desktop saved a recoverable intent and the source can settle it.

## Impact

Desktop take and Return, the credential-only SQLite journal and keyring, the authenticated server handoff routes, and one additive column on the server's holder assignment. No new dependency or service.

The assigned Orca branch already existed. The worktree-local binary was missing, so the manual branch gate used the approved [specwright#258](https://github.com/sh1ny/specwright/issues/258) workaround. The worktree was clean, the verified local `sw` was `0.39.1` with interface 3, and `HEAD` matched local and freshly fetched `origin/main` at `e719e62`. The base had no change or archive entry for `recover-interrupted-take`.

## Decision Making

DECISION_MAKING: all
- **Source:** The owner gates cover scope, apply, the review round cap and merge. The assignment delegates internal design decisions: "Inner design details you decide yourself; the design review checks them."

### S1: Interrupted takes only

- **Choice:** Prove what happened to the exact pending take before restoring its local state. Keep the proof when the outcome cannot be established.
- **Rejected:** Treat a later refusal or timeout as a cancellation, or change the holder and reclaim rules. Neither outcome proves that the source made no assignment.
- **Reversal cost:** medium.
- **Important:** yes, this changes what happens to pending takes without weakening the holder gate.
- **Chosen by:** user.

### S2: M2 follow-up

- **Choice:** Label the proposal as an M2 ESI platform and SSO follow-up. Leave the roadmap and manual acceptance gates unchanged.
- **Rejected:** Treat the fix as standalone maintenance. It covers the M2 one-holder rule.
- **Reversal cost:** low.
- **Important:** no.
- **Chosen by:** user.

### S3: Restore only newly journaled takes

- **Choice:** Preserve pre-upgrade `taking` rows and proofs and keep their existing reservation-resume path. The owner confirmed on item 77: "Yes, only new ones".
- **Rejected:** Repair pre-upgrade rows by choosing a substitute prior state. The earlier desktop did not save the previous row or selection.
- **Reversal cost:** medium.
- **Important:** yes, a pre-upgrade journal can still remain pending.
- **Chosen by:** user.
