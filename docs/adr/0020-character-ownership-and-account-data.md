# 0020. Character ownership and account data

- Status: accepted (2026-11-28)
- Date: 2026-11-28
- Supersedes: [ADR 0019](0019-member-account-and-signing-identity.md).
- Qualifies: [ADR 0017, Recovery](0017-esi-holder-handoff.md#recovery), when CCP ownership changes.
- Chosen by: owner (`character-transfer`, item 117).

## Context

CCP can report a new owner for a character. The character keeps its CCP ID, but the new owner has no claim on the old Kaname account, its authorization or its private records.

## Decision

### Account, signing identity and holder

Kaname account IDs are independent of CCP characters. A character belongs to at most one account. A nonempty account has one linked main. Each connected session binds the account to the CCP-verified character that signed in. Signing in through another linked character reaches the same account, but grants, opt-ins, holder state and interim administrator access follow the signing character. Selecting a main changes neither the account ID nor existing session authority.

Postgres commits detachment, the new owner and ownership generation, signing-session revocation, opt-in removal and server vault retirement together. A transfer leaves the old account and its records under the old ID. If its main transfers, promote the lowest-ID unblocked character, or the lowest-ID blocked character if none are unblocked. Keep an empty account without a main or connected sign-in path when its last character transfers. Only ordinary connected sign-in starts a fresh account for the new owner. Linking and ordinary unlink still do not change CCP ownership, ESI grants, opt-ins or holder assignments.

A transfer never changes a durable device assignment. An unfinished Take cannot resume across owners or release as a device reservation. A completed reservation can use ordinary Return only when the original device kept its proof and generation and can park. If the desktop lost the reply before saving the reservation, its pending journal cannot recover the reservation by replay after transfer. The current owner must authorize a fresh server grant after Return. Verified reclaim remains in M7.

### Write order and account retirement

A short membership transaction locks the affected CCP character IDs in ascending order, the affected account IDs in ascending order, then the acting session when the operation has one. Take the vault and receipt release locks after these when needed. Identity writers recheck under the character lock and update only the fields they own. No external calls run inside a membership transaction. Work already admitted can finish under its existing rules; a revoked session cannot admit new work.

A member can link a character from another account after fresh CCP proof only if it is that account's sole character and that account has no durable account-owned product data. Retire the absorbed ID and revoke its sessions in the same commit. Never reuse or redirect the ID. Future product rows must reference account IDs with restrictive foreign keys. Existing ESI receipts keep their original account ID and do not prevent absorption.

### Private records

Private character data readers must establish the viewer's entitlement under [ADR 0006](0006-privacy-in-the-data-access-layer.md). Character ID or present membership alone does not establish ownership of an older record. If a record's authority depends on its owner at collection, retain and verify that authority across transfer. A new owner must not gain a prior owner's private rows by signing in or linking the same character. The ESI call log uses immutable receipt attribution and ownership generation. This decision does not define future storage or sharing policy.

## Consequences

A transfer invalidates prior authority without moving account records. The original device can still block server ESI after the new owner signs in. A signed but stale owner value from CCP can leave the former account without a connected sign-in path if no other eligible signer remains. A later correct proof can start a fresh account; it cannot restore the old account or grant access to its records.
