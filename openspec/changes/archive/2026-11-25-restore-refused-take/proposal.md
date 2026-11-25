# Proposal

## Why

When the server definitively refuses a new desktop take, the desktop leaves the character in `taking`. That blocks native sign-in and skills authorization and makes Return retry the refused take ([#39](https://github.com/sh1ny/kaname/issues/39)). This M2 ESI platform and SSO follow-up protects the one-holder exit criterion with automated regressions. The milestone's live sign-in check is unchanged.

## What Changes

- Restore the local character and selection that existed before a new take when the server confirms it made no reservation for that take.
- Keep the journal and proof if the server may already have committed. Do not change the holder gate, reclaim policy, or sign-in and return rules for established assignments.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `esi-sso`: Define what the desktop restores after a definitive refusal and what it retains if the outcome is uncertain.

## Impact

Desktop ESI handoff, the connected take response adapter, the local character journal, the device keyring boundary and native handoff tests. No new service, package or credential exchange.

The branch already existed in the assigned Orca worktree. The pinned `sw` 0.39.1 binary was missing, so the worktree-local bootstrap and manual branch gate followed the approved workaround for [specwright#258](https://github.com/sh1ny/specwright/issues/258). The tree was clean, `HEAD` matched local and freshly fetched `origin/main` at `6003445`, and neither main ref had an archive entry for this change.

## Decision Making

DECISION_MAKING: all
- **Source:** user: "Scope is only this; anything else you notice goes in a new issue, not this PR." and "Inner design details you decide yourself; the design review checks them." Scope decisions stay with the owner. Internal design decisions are delegated.

### S1: Refused new takes only

- **Choice:** Restore the previous local state on definitive refusal. Retain the journal and proof when the outcome is uncertain or the server may already have committed.
- **Rejected:** Clear every unsuccessful take or change the holder gate. A missing reply does not show that the server made no reservation.
- **Reversal cost:** medium.
- **Important:** yes, changes behavior users see and protects a holder boundary.
- **Chosen by:** user.

### S2: M2 follow-up

- **Choice:** Label the proposal as an M2 ESI platform and SSO follow-up. Leave the roadmap and manual acceptance gates unchanged.
- **Rejected:** Treat the fix as standalone maintenance. It protects the M2 one-holder exit criterion.
- **Reversal cost:** low.
- **Important:** no.
- **Chosen by:** user.
