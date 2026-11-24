# Tasks

## Test map

No spec deltas (`skip_specs: true`). These tests cover the existing `client-data-bundle` requirement for the deploy proxy to close stalled downloads.

| Scenario | Test file | Test name | State |
|---|---|---|---|
| A non-reader stalls with the shipped `write_idle`; Caddy waits, then aborts and releases both legs | `server/kaname_client/test/stack/caddy_idle_test.dart` | Caddy closes a stalled download and its upstream connection while the client still reads nothing | green |
| The same path stalls with idle termination disabled, then delivers the entire download when the client drains | `server/kaname_client/test/stack/caddy_idle_test.dart` | Caddy completes a backpressured download when the client reads and write idle is disabled | green |

## 1. Stabilize the idle fixture

- [x] 1.1 Verify A1 locally before relying on it: check direct host access to the pinned Caddy's bridge address and namespaced socket bounds in the targeted fixture, then confirm the same test in the Ubuntu PR stack job during watch. For A2, adapt both scratch configurations with the pinned image and check that only the explicit idle value changes, then observe the live Caddy trace and the disabled-timer control's full drain.
- [x] 1.2 Update the assertions before replacing the old transport and guard. Record the controlled request-relative guard reproduction; require a deliberate early-expiry mutation after delayed body start to fail the matched-write minimum rather than the config assertion or guard. Then make both named tests pass with the bounded native Linux Docker fixture and normal configuration; verify Caddy, socket and upstream progress diagnostics on deliberate failure, and clean up all probe artifacts.
- [x] 1.3 Carry C1, C2 and C3 into the test library documentation; document native Linux Docker requirements in `deploy/README.md`. Verify with targeted formatting and static analysis, and capture the focused stack-test command and outcomes for the group commit.

## Workflow follow-up

- Verify CI's Linux stack result on the PR head, resolve review findings, and report readiness to the owner. Do not merge.
- Complete the OpenSpec archive and Specwright finish workflow at the owner-approved point in the PR lifecycle.
