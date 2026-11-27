# Member accounts

## Why

M2 gives each signed-in EVE character its own Kaname identity. M3's first exit criterion needs one install-local account for a member, whether they sign in with their main or an alt. This change tests that criterion with automated migration, sign-in and account-management tests. The roadmap's live check with affiliation, member state and capability changes stays at the M3 close, when those changes exist.

## What Changes

- Create an account with one main for each M2 identity and for each previously unknown character that signs in. Any linked character reaches the same account through CCP sign-in. Never infer links from owner hashes.
- Let a signed-in member list their characters, link an alt with fresh CCP proof, choose a main and unlink a non-main character. One character can belong to at most one account.
- Keep ESI authorization and holder handoff bound to the signing character and its verified owner. Do not expand the static-data admin allowlist through account membership.
- Keep owner-hash conflict blocking in place. Character transfer, organisation trees and affiliation, member states, groups and capabilities are separate M3 changes. Organisation sharing and consent are M4; changes to solo storage and holder reclaim are out of scope.

## Capabilities

### New Capabilities

- `member-accounts`: Connected account membership, main selection, linking and unlinking, and upgrade from M2.

### Modified Capabilities

- `esi-sso`: Resolve a stable Kaname account from the verified signing character without treating the account as the ESI principal.
- `esi-call-log`: Scope own history by account and current membership. Keep prior receipt attribution, and prevent known membership splits from qualifying private aggregates.

## Impact

Server account and session persistence, the confidential SSO flow, the Flutter ESI account settings, and existing authenticated consumers of the member ID, including ESI call history. No new deployment secrets or CCP registration.

## Decision Making

DECISION_MAKING: all
Source: setting

Ormy approved S1–S4 on the owner's delegation. The owner confirmed all four and approved implementation in item 96 after design review. Archive remains a separate decision.

### S1. Existing standalone identity

- Choice: Seed one account per identity. After fresh signed-in SSO, allow an alt's standalone account to join the target only if it has no other characters or account-owned data. End the old account's sessions. Refuse other cross-account links.
- Rejected: Refuse all cross-account links and require a separate release workflow for already signed-in M2 characters.
- Reversal cost: High once accounts own durable data.
- Important: yes (membership contract and user-visible link behavior).
- Chosen by: user; approved by Ormy on the owner's delegation, 2026-11-27, owner to confirm.

### S2. Unlinking

- Choice: Unlink any non-main character and revoke its sessions. Require the member to choose another main before removing the old main. Keep the last character linked. A detached character can start a new account on a later sign-in or link again with fresh CCP proof.
- Rejected: Allow the last character to be removed and close the account.
- Reversal cost: Medium, because account deletion and recovery would need their own rules.
- Important: yes (user-visible removal and session behavior).
- Chosen by: user; approved by Ormy on the owner's delegation, 2026-11-27, owner to confirm.

### S3. M2 sessions

- Choice: Preserve valid sessions and their original signing characters. Keep blocked identities blocked.
- Rejected: Require everyone to sign in again after the upgrade.
- Reversal cost: Medium, because session loss cannot be undone from stored bearer digests.
- Important: yes (upgrade behavior).
- Chosen by: user; approved by Ormy on the owner's delegation, 2026-11-27, owner to confirm.

### S4. Account controls and existing character authority

- Choice: Put the roster and link, main and unlink actions in the connected ESI account settings on web and native. Leave solo unchanged. Keep skills, handoff and the current admin allowlist tied to the signing character under ADRs 0005, 0017 and 0018.
- Rejected: Add a separate account page or make character-specific authority account-wide.
- Reversal cost: Medium for authority and low for placement.
- Important: yes (user-visible settings and authority).
- Chosen by: user; approved by Ormy on the owner's delegation, 2026-11-27, owner to confirm.

## Branch gate

The Orca worktree already held `feat/member-accounts` at `e177950`. The pinned Specwright 0.39.1 binary was missing, so the worktree-local bootstrap permitted by the dispatch was used. The checked binary reported interface 3 and a clean worktree. `HEAD`, `main` and freshly fetched `origin/main` matched, and neither main ref contained an archive for this change. The existing branch was kept.
