# 0019. Member account and signing identity

- Status: accepted (2026-11-27)
- Date: 2026-11-27
- Supersedes: none.
- Chosen by: owner (`member-accounts`, item 96).

## Account and signing identity

A Kaname installation gives each member one account with a stable ID and one main character. A character belongs to at most one account. Changing the main changes neither the account ID nor the authority of existing sessions. Each session binds the account to the CCP-verified character that signed in. Signing in with another linked character reaches the same account, but grants, opt-ins, holder state and interim administrator access still follow the signing character ([ADR 0005](0005-run-modes-and-one-token-holder.md), [ADR 0017](0017-esi-holder-handoff.md), [ADR 0018](0018-scoped-static-data-administration.md)).

## Write order

Postgres owns the account, identity and session records. A membership mutation locks the affected CCP character IDs in ascending order, the affected account IDs in ascending order, then the acting session. Recheck membership and authority under those locks. All identity writers take the same character lock and update only the columns they own. Revoke affected sessions in the same transaction as a membership change. Never hold these locks while calling CCP, the token vault or the scheduler. Already admitted protected work can finish without holding the session lock.

## Account retirement

A signed-in member can link the only character of another account after obtaining fresh CCP proof for that character. The old account must have no durable account-owned product data. Retire its ID in the same transaction as the move and revocation; never reuse it or redirect it to the new account. Future product rows referencing accounts must use restrictive foreign keys so a link cannot delete or orphan them. Retained ESI receipts keep the old ID and do not prevent retirement.

## Transfer boundary

Linking and unlinking change membership, not ownership of the character's ESI grant or holder assignment. A signed owner-hash conflict blocks the identity and revokes its sessions; it does not transfer the character or change its holder. Character transfer and verified holder reclaim have their own decisions.
