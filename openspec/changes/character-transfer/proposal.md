# Character transfer

## Why

Kaname currently blocks a known character when CCP reports a different owner hash. M3's second exit criterion requires Kaname to detach the character, revoke the old authorization and let the new owner sign in without seeing either owner's private records from the wrong account or bypassing a device holder.

## What Changes

- Detect a fresh, verified change of owner through connected sign-in, alt linking, scoped authorization or server vault refresh. Detach the character, revoke sessions that signed in through it, and remove its server vault credential and opt-ins.
- Let ordinary connected sign-in start a fresh account for the transferred character. A link, scoped authorization or refresh can detect the change but cannot claim the character.
- Keep the previous account and its data. If the transferred character was its main, promote a remaining character or leave the account without a main if none remain.
- Keep each ESI receipt with its original account and keep prior owners' individual rows hidden from the new owner. Preserve the detached-character rule for private aggregate eligibility.
- Preserve device holder assignments. The original device still has to prove it parked before the server can enable ESI, as required by [ADR 0017](../../../docs/adr/0017-esi-holder-handoff.md). Verified reclaim stays in M7.
- Leave ordinary unlink, the organisation tree, affiliation, member states, groups, capabilities, and M4 sharing and consent outside this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `esi-sso`: A verified owner change replaces the current conflict block with transfer and revocation. A transfer cannot grant ESI or clear a device assignment.
- `member-accounts`: Detach a transferred character, replace the old main if needed, and let only ordinary connected sign-in start the character's new account.
- `esi-call-log`: Keep receipts private across ownership changes, including a later link, and apply existing aggregate rules to transfer detachment.

## Impact

Connected SSO, member and session persistence, server ESI authorization, and private ESI history. Automated tests with recorded or fake CCP replies cover the transfer exit criterion without real credentials. The M3 local-stack check of affiliation, member state and capability changes still belongs at milestone close. No new CCP registration or deployment secret.

## Decision Making

DECISION_MAKING: all
Source: setting

### S1. First claim after a transfer

- Choice: A fresh signed owner change seen on any existing detection path can detach the character and revoke its old authority. Only ordinary connected sign-in can attach it to a new account. That sign-in can complete the transfer and start the new account in the same attempt. Linking becomes available after that sign-in.
- Rejected: Let a fresh alt link attach the transferred character directly to the requesting account. That would make a different account's live session part of the first claim.
- Reversal cost: Medium.
- Important: yes (sign-in and account access).
- Chosen by: user. "Plain sign-in only; it starts a fresh account, linking comes after."

### S2. Main replacement in the old account

- Choice: If the main transfers, promote the remaining unblocked character with the lowest CCP character ID. If only blocked characters remain, designate the one with the lowest ID without unblocking it. If none remain, keep the old account and its data without a main or sign-in path.
- Rejected: Leave the main unset until a surviving signer selects one. That would require connected Settings to handle a signed-in account with no main.
- Reversal cost: Medium.
- Important: yes (account state and roster behavior).
- Chosen by: user. "Auto-promote a remaining alt; keep an empty account only if none."

## Branch gate

Orca created `feat/character-transfer` before the branch gate ran. The approved manual gate used the pinned, checksum-verified, worktree-local Specwright 0.39.1 binary with interface 3. The worktree was clean and `HEAD` matched freshly fetched `origin/main` at `ad22241`, which contained the `member-accounts` archive. The local `main` ref was behind at `e177950`; neither main ref contained a `character-transfer` archive. No branch was switched or recreated.
