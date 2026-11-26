# Proposal

## Why

A Windows process exit during a secure-storage rewrite can lose the desktop install key and handoff proofs, including entries the operation did not touch. Settings also treats a restored take as blocked, and the server does not bound repeated writes that close unused take epochs.

This is an off-milestone bugfix. It does not change the roadmap or its exit criteria.

## What changes

- [#49](https://github.com/sh1ny/kaname/issues/49): Patch and pin the Windows secure-storage backend to publish a flushed sibling file atomically. Keep the DPAPI format and location and leave unreadable committed data intact. Test interrupted writes and deletes with synthetic secrets on Windows.
- [#47](https://github.com/sh1ny/kaname/issues/47): In Settings, explain when a recovered take did not go through and a new Take can start. When the server cannot confirm the original outcome, explain that another retry may not resolve it. Keep the journal and original proof.
- [#48](https://github.com/sh1ny/kaname/issues/48): Bound repeated writes that close unused take epochs. Keep the safe retry after a lost closure reply. Do not treat throttling or refusal as proof of non-acceptance.
- Leave holder authority, parking and reclaim rules unchanged. Do not add a reset, clear uncertain intents, or change non-Windows keyrings.

## Capabilities

### New capabilities

None.

### Modified capabilities

- `esi-sso`: Windows desktop credential durability, Settings feedback after a Take recovery, and the bound on server-side take epoch closure.

## Impact

Windows secure storage and its dependency pin and licence notice, desktop account handling and localized Settings notices, and the server's authenticated take-intent handling. Existing desktop journals and the committed Windows keyring remain readable without losing their entries.

## Decision Making

DECISION_MAKING: all

Source: setting

### S1: One off-milestone bugfix

- **Choice:** Cover #49, #47 and #48 in one change on `bugfix/harden-desktop-take`, with #49 first. Use the assigned branch and leave the roadmap unchanged.
- **Rejected:** Split the issues, recreate the assigned branch, or edit the milestone roadmap.
- **Reversal cost:** Low during planning.
- **Important:** Yes. The choice defines the scope of the change.
- **Chosen by:** User.

### S2: Patch the Windows dependency

- **Choice:** Patch and pin the Windows package until upstream ships a fix. Keep the existing DPAPI format and location. Mark the patched code and keep its licence notice and attribution.
- **Rejected:** Replace the backend and migrate existing user secrets, or wait for an upstream release before fixing Windows.
- **Reversal cost:** Medium. The pinned patch is a dependency the project must maintain until upstream includes the fix.
- **Important:** Yes. The persisted data includes the install key and live handoff proofs.
- **Chosen by:** User, "Patch the package".

### S3: Keep the handoff rules

- **Choice:** Explain the two recovery outcomes and bound closure writes without changing who can park, activate or reclaim a holder. Retain the original journal and proof when the server cannot settle an intent.
- **Rejected:** Clear an uncertain intent on refusal, add a reset, or bypass normal parking and reclaim.
- **Reversal cost:** High once evidence is lost.
- **Important:** Yes. The journal and proof can be necessary to prove that an existing holder parked.
- **Chosen by:** User, through the issue scope.
