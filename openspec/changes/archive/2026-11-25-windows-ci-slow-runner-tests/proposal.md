# Proposal

## Why

On [PR #44](https://github.com/sh1ny/kaname/actions/runs/45688516258/job/139476193782), Windows CI loaded build 101 after a rollback instead of build 100. The test restarted the notifier without confirming that build 100 had been saved. The truncated-file test has also read a file during its replacement and hit Windows error 32 ([#24](https://github.com/sh1ny/kaname/issues/24)).

This CI maintenance unblocks M2 ESI platform and SSO follow-ups. It does not change a milestone exit criterion or the roadmap.

## What Changes

- Replace elapsed-time waits and file probes in the two notifier tests with completion events; keep their real file stores and assertions.
- Replace the adjacent file-store tests' bounded polling with events from the opener and the existing pre-rename hook. Keep the real file operations and test stale-file cleanup with a fixed clock.
- Add the ten shared Windows CI test rules to `AGENTS.md`.
- Leave the socket deadlines, other Windows tests, Linux integration tests and CI speed work tracked in #24. Leave ESI, account, production static-data and workflow code unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The tests exercise existing `client-static-data` requirements. CI still runs the same checks; this change does not need a spec delta.

## Impact

`app/test/static_data/`, `AGENTS.md` and these planning artifacts. No API, dependency or file-format changes.

## Decision Making

DECISION_MAKING: all
- **Source:** setting. The dispatch states, "Inner design details you decide yourself; the design review checks them."

### S1: First PR scope

- **Choice:** The owner approved "A: two failed tests, file-store polling, rules" on item 80. The rest of #24 stays open.
- **Rejected:** Fix only the two notifier tests and add the rules. The nearby file-store tests already have an I/O hook that can remove their poll budget without changing production code.
- **Reversal cost:** low. The remaining tests can be fixed in later PRs.
- **Important:** no. The slice changes test synchronization and written test policy, not the product contract.
- **Chosen by:** user

## Branch gate

Orca already created `bugfix/windows-ci-slow-runner-tests`. The pinned `sw` was missing, so the branch gate used the approved [worktree bootstrap workaround](https://github.com/sh1ny/specwright/issues/258). After bootstrapping `sw` 0.39.1 locally, the manual check confirmed the clean branch, repo-local planning root, no prior archive with this name, and `HEAD`, `main` and refreshed `origin/main` at `e719e62`.
