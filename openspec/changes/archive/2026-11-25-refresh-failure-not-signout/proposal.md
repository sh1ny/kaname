# Proposal

## Why

After Take or Return, an unreadable viewer reply can make Kaname forget a known ESI holder and skip the desktop check for that character ([#41](https://github.com/sh1ny/kaname/issues/41)). The viewer route also reports session lookup errors as sign-out, so the app cannot distinguish those errors from an invalid session. This M2 ESI platform and SSO follow-up protects the one-holder exit criterion with automated regressions. The milestone's live sign-in check is unchanged.

## What Changes

- Distinguish a confirmed invalid connected session from an unavailable or unreadable viewer refresh.
- Keep the last known holder available to the desktop authorization check when a refresh cannot verify a change. Use a verified new viewer when available and discard the old information on sign-out.
- Leave desktop journals and device proofs, the handoff protocol, and server-side authorization rules unchanged.
- Let the viewer route return its existing unavailable response for session lookup errors. Leave the other auth routes unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `esi-sso`: Keep the desktop holder check in effect when a viewer refresh cannot establish a new holder state.

## Impact

The Flutter connected-account adapter and account notifier change, as does the server's viewer lookup. Regression tests use `app/test/esi_sso/native_sso_test.dart` and `server/kaname_server/test/integration/esi/connected_sso_test.dart`. The fix adds no dependencies or wire formats.

Orca created this branch before the Specwright gate ran. The worktree lacked its pinned `sw` 0.39.1, so the approved [specwright#258](https://github.com/sh1ny/specwright/issues/258) workaround installed the verified release in this worktree only. The manual gate found a clean tree, `HEAD` equal to local `main` and freshly fetched `origin/main` at `e719e62`, and no matching archive on either main ref.

## Decision Making

DECISION_MAKING: all
- **Source:** user: "Scope is only this issue; anything else you notice goes in a new issue, not this PR." and "Inner design details you decide yourself; the design review checks them." The owner sets scope and delegates internal design choices.

### S1: Viewer-refresh failures only

- **Choice:** Retain the last known holder on an inconclusive refresh. Discard it when the session definitively ends and use a trustworthy update when one arrives. Leave desktop journal and proof recovery out of this change.
- **Rejected:** Treat every failed refresh as sign-out or rely on journal recovery to keep the connected holder check in effect.
- **Reversal cost:** Low.
- **Important:** Yes, changes what a desktop user can do after a failed refresh.
- **Chosen by:** user.

### S2: M2 follow-up

- **Choice:** Label this an M2 ESI platform and SSO follow-up. Leave the roadmap and manual acceptance gates unchanged.
- **Rejected:** Treat the refresh fix as unrelated to M2 or require a new live sign-in check.
- **Reversal cost:** Low.
- **Important:** No.
- **Chosen by:** user.

### S3: Viewer lookup errors

- **Choice:** Include the viewer route's session lookup. Send its existing 503 for a lookup error and reserve its fixed 401 for sessions the route can confirm are invalid. Do not change other auth routes.
- **Rejected:** Ship only the Flutter fix and file a follow-up. The app cannot distinguish a lookup error from invalidation when both return the same 401.
- **Reversal cost:** Low.
- **Important:** Yes, changes what the user sees on a server-side lookup failure.
- **Chosen by:** user, "Yes, include it".
