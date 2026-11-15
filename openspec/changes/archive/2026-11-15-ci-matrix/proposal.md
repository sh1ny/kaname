# Proposal

## Why

Kaname has no CI. The checks `repo-scaffold` added (`mise run check`, the notices staleness check) run only when someone runs them locally. Nothing yet proves that the app builds on all six targets, nothing checks DCO sign-off, and no dependency is checked against AGPL compatibility. This change serves roadmap **M0 - Walking skeleton** (change 2 of 6). It advances two agent-verified exit criteria: "CI on Linux, Windows and macOS runners builds web, Windows, Linux, macOS, Android and iOS (no codesign), and runs every package's tests", and the CI half of "`LICENSE`, `THIRD_PARTY_NOTICES`, a licence check that fails CI on dependencies that are not AGPL-compatible, and an SBOM". It also closes the gap that `repo-scaffold` deliberately left to this change (its C6): running notices `--check` in CI, the licence-compatibility check and the DCO check. It follows ADR 0001 (every target, Windows included, on three runner OSes; toolchain pinned in `mise.toml`) and ADR 0002 (CI fails on licences that are not AGPL-compatible).

## What Changes

- A GitHub Actions workflow runs on every pull request and every push to `main`, and cancels superseded runs. It:
  - runs `mise run check` on Linux, Windows and macOS runners;
  - builds web, Linux and Android on Linux, Windows on Windows, and macOS and iOS (`--no-codesign`) on macOS;
  - runs strict OpenSpec validation (`mise run spec:validate`) on Linux;
  - runs the licence-compatibility check and publishes a CycloneDX SBOM as a build artifact;
  - on pull requests, checks the DCO sign-off of every commit.
- The toolchain in CI comes from `mise.toml` through mise, as in local development. No version is duplicated in workflow files.
- `kaname_tools` gains a licence check. It classifies each package's licence text in the root `pubspec.lock` against a small set of known SPDX licences and fails on any licence that is unknown or not AGPL-compatible. The only override is a committed, owner-reviewed exceptions file. A mise task runs it locally.
- `kaname_tools` gains an SBOM generator that writes CycloneDX JSON from `pubspec.lock`. It is not committed.
- `kaname_tools` gains a DCO check: every non-merge commit in a range needs a `Signed-off-by` line matching its author's name and email. The only exemption is Dependabot's own commits in pull requests Dependabot opened.
- CONTRIBUTING no longer says the sign-off check is manual. It describes the CI checks.
- The owner marks the CI checks required on `main` (a `[user]` task).

## Capabilities

### New Capabilities
- `continuous-integration`: what CI runs, on which runners and events, how it gets its toolchain, and what makes it fail.
- `dependency-licences`: the AGPL-compatibility classification of locked dependencies, its exceptions file, and the SBOM generated from the same lockfile.

### Modified Capabilities
- `contribution-policy`: the DCO requirement is enforced by an automated CI check and no longer says one will be added later.
- `third-party-notices`: the staleness check runs in CI and is no longer described as not yet enforced.

## Impact

- New: `.github/workflows/ci.yml`, `.github/dependabot.yml`, `licence-policy.yaml` (allowlist and exceptions), `mise.lock` with its `.mise/locks/` sidecars, new `kaname_tools` subcommands (`licences`, `sbom`, `signoff`) with tests, new mise tasks.
- Changed: `CONTRIBUTING.md` (DCO, CI and toolchain wording), `mise.toml` (tasks, `java` pin, `min_version`), possibly `THIRD_PARTY_NOTICES` if new tool dependencies are added.
- GitHub: Actions minutes on public-repo runners (free); main's branch protection gains required checks (owner setting).
- Known gap, outside this change: native platform dependencies (Gradle, CocoaPods/SwiftPM, the Flutter engine's bundled components) are neither licence-checked nor in the SBOM.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: When the full matrix runs

- **Choice:** Every pull request and every push to `main`, with superseded runs cancelled.
- **Rejected:** Linux-only on PRs with the full matrix after merge (breakage on Windows/macOS/iOS lands on main); full matrix on a PR label (easy to forget).
- **Reversal cost:** low
- **Important:** yes, changes behaviour users (contributors) see
- **Chosen by:** user

### S2: Where the checks and tests run

- **Choice:** `mise run check` on Linux, Windows and macOS.
- **Rejected:** Linux only (the portability of the tooling would never be tested).
- **Reversal cost:** low
- **Important:** yes, binds future changes (every check task must stay portable)
- **Chosen by:** user

### S3: How licences are classified

- **Choice:** A `kaname_tools` subcommand that matches licence texts against a small set of known SPDX licences and an AGPL-compatible allowlist, with overrides only through a committed, owner-reviewed exceptions file.
- **Rejected:** a third-party licence checker (a new dependency to vet, fits the workspace less well).
- **Reversal cost:** medium
- **Important:** yes, binds future changes (every new dependency passes it; exceptions file format)
- **Chosen by:** user

### S4: Dependency scope of the licence check and SBOM

- **Choice:** Every package in the root `pubspec.lock`, as for THIRD_PARTY_NOTICES (repo-scaffold D3). Native platform dependencies are a named gap for a later change.
- **Rejected:** also enumerating Gradle and CocoaPods/SwiftPM dependencies (much larger, per platform).
- **Reversal cost:** low
- **Important:** yes, chosen on weak evidence (native dependency licences are not yet surveyed)
- **Chosen by:** user

### S5: SBOM form

- **Choice:** CycloneDX JSON generated from `pubspec.lock` in CI and uploaded as a build artifact; not committed.
- **Rejected:** SPDX JSON (equally valid, more verbose); a committed file with a staleness check (more churn on every dependency change).
- **Reversal cost:** low
- **Important:** yes, binds future changes (an output format)
- **Chosen by:** user

### S6: DCO check rule

- **Choice:** Every non-merge commit in the pull request's range has a `Signed-off-by` line matching its author's name and email. Commits with Dependabot's identity in pull requests Dependabot opened are exempt and reported as skipped, because the DCO certifies human contributions and the owner reviews each bump before merge (added after design review round 1, limited to Dependabot's own pull requests after round 2). CONTRIBUTING describes the check and the exemption.
- **Rejected:** any `Signed-off-by` line regardless of whom it names (does not match CONTRIBUTING's rule); no exemption, with the owner signing off each Dependabot commit (a manual step on every bump); dropping Dependabot (stale pins). The DCO App was already rejected in repo-scaffold S8.
- **Reversal cost:** low
- **Important:** yes, changes behaviour users see (contributor PRs fail without matching sign-off)
- **Chosen by:** user

### S7: Required checks on `main`

- **Choice:** In scope as a `[user]` task: after the workflow runs green on this change's PR, the owner marks its jobs as required status checks for `main`. Agents never change repository settings.
- **Rejected:** leaving branch protection out of the change (CI could be bypassed by merging red).
- **Reversal cost:** low
- **Important:** yes, changes settings users see
- **Chosen by:** user

### S8: Toolchain in CI

- **Choice:** mise on every runner (`mise install`, then `mise run …`), with its tool cache kept between runs.
- **Rejected:** `subosito/flutter-action` with the version copied from `mise.toml` (a duplicated pin, and the tasks need mise anyway).
- **Reversal cost:** low
- **Important:** yes, binds future changes (CI and local use one pin)
- **Chosen by:** user

### S9: OpenSpec validation in CI

- **Choice:** One Linux job runs `mise run spec:validate` (strict).
- **Rejected:** keeping it only in Specwright's pre-push hook (contributor PRs would bypass it).
- **Reversal cost:** low
- **Important:** yes, changes behaviour users see
- **Chosen by:** user
