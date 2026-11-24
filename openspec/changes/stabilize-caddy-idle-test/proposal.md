# Proposal

## Why

The Caddy idle-download stack test in [#31](https://github.com/sh1ny/kaname/issues/31) failed upstream-close detection on an unchanged test and passed on the same commit on a different runner. Make this an M1 maintenance change that preserves the delivered stalled-download coverage without reopening M1 or changing M2 exit criteria. It is part of the wider slow-runner work in [#24](https://github.com/sh1ny/kaname/issues/24).

## What Changes

- Make the probe independent of runner buffering and the time taken for the request and body to reach the blocked-write stage.
- Keep the real pinned Caddy and the shipped `write_idle` setting under test. Require a stall-induced, non-immediate close of both sockets, with no downstream reads until upstream termination.
- Include Caddy logs, upstream admission and write progress in failure diagnostics. Leave the production configuration, runtime behavior, and other tests unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The existing `client-data-bundle` requirement for the deploy proxy to close stalled connections is unchanged; only its test changes.

## Impact

`server/kaname_client/test/stack/caddy_idle_test.dart` and its documentation. No dependency, deploy topology, or API changes.

Pre-created Orca worktree: branch gate step 4 checked by hand with owner approval for this branch only: HEAD `f7f0dd4` matched freshly fetched `origin/main`, status was clean, and no archived change had this name.

## Decision Making

DECISION_MAKING: all

Source: setting

### S1: Milestone placement

- **Choice:** M1 maintenance, without reopening M1 or adding an M2 exit criterion.
- **Rejected:** M2 exit work; M2 does not govern CI timing.
- **Reversal cost:** low.
- **Important:** no.
- **Chosen by:** user.

### S2: Coverage and diagnostics

- **Choice:** Fix the existing real-Caddy test for both late backpressure and missed closure; preserve both closes and the non-immediate stall, and keep actionable failure evidence.
- **Rejected:** Increasing the wait, replacing Caddy with a fake, or changing production behavior.
- **Reversal cost:** low.
- **Important:** no.
- **Chosen by:** user.
