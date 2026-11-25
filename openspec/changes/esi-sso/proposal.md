# EVE SSO for connected and solo mode

## Why

This is change 5 of [M2](../../roadmap.md#now-m2---esi-platform-and-sso). It connects the generated ESI client, scheduler, vault and call log to real sign-in, replaces the interim static-data admin key, and records the owner's two-mode CCP sign-in check as a `[user]` task before archive.

## What Changes

- Add confidential CCP sign-in on a self-hosted server and authorization code with PKCE in native desktop solo mode. Validate CCP access tokens before accepting a character identity. The server maps the character to a Kaname identity that Serverpod can authenticate.
- Request ESI scopes only for enabled modules and permitted data classes. Optional classes require a recorded opt-in. Both modes use the generated skills read through the existing scheduler and vault to prove scoped ESI access.
- Expose the existing privacy-scoped call-log reads in the connected app. Members can read their own rows. Admins can also read route totals and error counts, without other members' rows or drill-down.
- Move the active ESI holder between a server and a native device, including taking a server-held character solo. Park the source before activating the destination with a fresh CCP authorization for that registration. No CCP token or client secret moves between installs.
- **BREAKING:** Replace the static-data admin key with signed-in Serverpod admin scope. Remove the key configuration, check RPC, key prompt and fallback. Public status, job status and the change report stay readable without sign-in.

## Capabilities

### New Capabilities

- `esi-sso`: CCP sign-in, validated character identity, scope selection, one scoped read in each mode and server/device token-holder handoff.

### Modified Capabilities

- `esi-call-log`: Add authenticated client reads through the existing privacy-scoped data-access interface.
- `static-data-admin`: Require a signed-in admin for mutations without changing public reads or job semantics.
- `static-data-settings`: Derive the admin controls from authenticated authority instead of a shared key.
- `self-host-stack`: Route the browser callback to Kaname and supply confidential credentials only to the running server.

## Impact

Shared Dart code handles CCP authorization and token validation. Serverpod supplies the connected identity, authenticated calls and holder state. Flutter supplies sign-in, holder and call-log controls, with the solo connection confined to native desktop. Deployment adds CCP app configuration and the vault key. M3 still owns organisation membership and character ownership changes. M4 still owns organisation sharing and consent and the general local-store choice. R45, a shared native client ID, stays open.

The branch gate used the owner's [worktree workaround](https://github.com/sh1ny/specwright/issues/258). Orca had already created the clean `feat/esi-sso` worktree at `e2f271b`. The pinned, checksum-verified `sw` 0.39.1 reported interface 3 from the ignored worktree-local install. The branch matched the freshly fetched `origin/main`, and neither local nor remote main had an archive named `esi-sso`. No existing branch was switched or recreated.

## Decision Making

DECISION_MAKING: all
- **Source:** `openspec/specwright.yaml`, with the owner's change-specific direction: "Inner design details (package layout, storage shape, cipher and HTTP wiring, caching) you decide yourself; the design review checks them."

### S1: Prove both sign-in modes against CCP

- **Choice:** Run the owner check against the local self-host stack at `http://localhost/` and a native desktop build on the same machine. The owner registers both CCP applications and signs in with the same test character. A scoped skills read succeeds on the server, then the device takes the holder and runs the solo read without concurrent holders.
- **Rejected:** A public test host is unnecessary for the owner check. A server-only check cannot verify native PKCE. Shipping a common native client ID would settle R45 before its review.
- **Reversal cost:** medium
- **Important:** yes; sets the M2 acceptance check and which registrations ship.
- **Chosen by:** user

### S2: Keep organisation sharing and the solo store choice in M4

- **Choice:** Read configured scope policy and recorded opt-ins now, with no organisation sharing or consent workflow. Keep native SSO credential storage separate from the M4 choice for the general solo store.
- **Rejected:** Decide policy-sharing UX, general sync or a general-purpose solo database in this change.
- **Reversal cost:** high
- **Important:** yes; binds later privacy and solo work.
- **Chosen by:** user

### S3: Complete the caller-facing parts of the call log and vault

- **Choice:** Wire connected call-log reads through the existing privacy interface and implement the server/device handoff. The handoff enforces one holder across the participating server and device. An independent offline install cannot observe the state of an install it never contacted.
- **Rejected:** Expose other members' rows to admins or treat changing modes as a second independent login for an already held character.
- **Reversal cost:** high
- **Important:** yes; affects privacy and which install may call ESI.
- **Chosen by:** user

### S4: End the interim static-data admin key

- **Choice:** Require a signed-in identity with the admin scope for static-data mutations and preserve anonymous reads, as described in ADR 0015 and the M2 roadmap.
- **Rejected:** Keep the shared key for existing callers or allow a key to grant a Serverpod identity.
- **Reversal cost:** medium
- **Important:** yes; changes operator configuration and the admin RPC contract.
- **Chosen by:** user

### S5: Keep a lost device's assignment blocked in M2

- **Choice:** The original device can resume or return an interrupted transfer. If it cannot prove it parked, the server remains blocked. Verified reclaim belongs to M7's [Solo to join](../../roadmap.md#later) work.
- **Rejected:** Reclaim in M2 without independently verifying that the previous device cannot use its CCP authorization.
- **Reversal cost:** high
- **Important:** yes; determines access after a device is lost or its credential store is erased.
- **Chosen by:** user (Ormy item 67, 2026-11-25): "Yes, blocked in M2; takeover later".
