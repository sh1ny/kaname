# Proposal

## Why

A crash after SQLite commits a desktop handoff rollback, or a failed keyring delete, can leave a proof that the journal no longer references ([#43](https://github.com/sh1ny/kaname/issues/43)). This M2 ESI platform and SSO follow-up protects the one-holder exit criterion by cleaning up unused proofs without interfering with recovery; native tests cover the change and the milestone's live sign-in check stays at milestone close.

## What Changes

- Remove desktop handoff proofs that the journal can account for once no character row or rollback snapshot references them. Retry interrupted cleanup when the credential store next opens.
- Preserve the original proof of every unresolved take, return or join, including pre-upgrade takes without rollback snapshots. Cleanup does not settle holder moves or alter their outcome.
- Leave already-orphaned legacy keyring entries alone. Do not change the roadmap, add a manual acceptance gate or address #47 or #48. Windows secure-storage crash atomicity is tracked separately in [#49](https://github.com/sh1ny/kaname/issues/49).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `esi-sso`: Clean up unreferenced desktop handoff proofs without losing evidence that an existing journal can use.

## Impact

The native desktop credential store, its SQLite schema and native SSO tests. No new dependencies, UI, network calls or server changes.

Orca created the assigned branch before the gate ran. The worktree lacked the pinned binary, so the gate used the approved [specwright#258](https://github.com/sh1ny/specwright/issues/258) workaround. The worktree was clean, the worktree-local `sw` reported `0.39.1` and interface 3, and `HEAD`, local `main` and freshly fetched `origin/main` matched at `d7aa5ca`. Neither main ref had an archive entry for this change.

## Decision Making

DECISION_MAKING: all
- **Source:** The assignment reserves scope, apply, the review round cap and merge for the owner, and delegates internal design: "Inner design details you decide yourself; the design review checks them."

### S1: Clean up from this upgrade onward

- **Choice:** Track proofs the verified desktop journal references at upgrade or creates afterward. Leave legacy orphans without ownership evidence alone. The owner confirmed on item 79: 'A: leave old orphans, clean up from now on'.
- **Rejected:** Sweep old keys absent from the open journal. Their names do not identify the database that created them.
- **Reversal cost:** medium.
- **Important:** yes, this defines which durable secrets can be deleted and which legacy entries are left alone.
- **Chosen by:** user.

### S2: M2 follow-up only

- **Choice:** Keep holder recovery, UI and server policy unchanged. Label the proposal as an M2 follow-up without a roadmap edit or manual acceptance gate. Leave #47 and #48 out.
- **Rejected:** Resolve or reset pending moves as part of cleanup. Their outcomes require existing holder evidence, not the absence of a local proof.
- **Reversal cost:** low.
- **Important:** yes, this preserves the behaviour of interrupted holder moves.
- **Chosen by:** user.

### S3: Keep Windows secure-storage crash atomicity separate

- **Choice:** Fix the journal-side commit-to-delete gap in #43. File interruption inside the Windows keyring backend separately as [#49](https://github.com/sh1ny/kaname/issues/49). The owner confirmed on item 79: 'A: go ahead, file the plugin issue separately'.
- **Rejected:** Block journal cleanup on changing how the Windows backend persists secret writes.
- **Reversal cost:** low.
- **Important:** yes, this defines which crash boundaries the change covers.
- **Chosen by:** user.
