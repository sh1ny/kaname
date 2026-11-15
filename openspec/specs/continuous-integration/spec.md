# continuous-integration Specification

## Purpose
Defines what Kaname's continuous integration runs on every pull request and push to `main`: the local checks on three runner OSes, builds of all six app targets, spec validation, licence and sign-off checks, and the SBOM artifact.

## Requirements

### Requirement: CI runs on every pull request and push to main
A CI workflow SHALL run on every pull request targeting `main` and on every push to `main`. A newer run for the same pull request or ref SHALL cancel the older run that is still in progress.

#### Scenario: Pull request opened
- **WHEN** a pull request targeting `main` is opened or receives a new commit
- **THEN** the workflow runs every job in this specification against the pull request's head commit, and each job reports its own status on the pull request

#### Scenario: Superseded run
- **WHEN** a second commit is pushed to a pull request while the first commit's run is still in progress
- **THEN** the first run ends with the status `cancelled`, and the second commit's run reports the pull request's result

### Requirement: CI uses the toolchain pinned in mise.toml
Every CI job that runs Dart, Flutter, Java, Node or OpenSpec SHALL install them through mise from `mise.toml`, the committed `mise.lock` and its committed dependency-graph sidecars, in locked mode, and run project commands through mise tasks or `mise exec`. No workflow file SHALL state a Flutter, Dart, Java, Node or OpenSpec version of its own.

#### Scenario: Pin changed
- **WHEN** the Flutter version in `mise.toml` is changed and `mise.lock` is regenerated in the same pull request
- **THEN** every CI job uses the new version without any edit to a workflow file

#### Scenario: Lockfile out of date
- **WHEN** `mise.toml` names a tool or version that has no entry in `mise.lock` for the runner's platform
- **THEN** the job fails at its setup step with mise's locked-mode error, and no later step of the job runs

#### Scenario: npm dependency graph missing
- **WHEN** an npm tool's locked dependency graph that `mise.lock` references is missing or does not match its recorded digest
- **THEN** the job fails at its setup step with mise's locked-mode error

#### Scenario: Checksum mismatch
- **WHEN** a downloaded tool archive does not match the checksum recorded in `mise.lock`
- **THEN** the job fails at its setup step, and the tool is not used

### Requirement: The local checks run on three runner OSes
CI SHALL run `mise run check` (after `mise run resolve`) on Linux, Windows and macOS runners. Each OS is a separate job.

#### Scenario: All checks pass
- **WHEN** the workspace, purity, analysis, format, test and notices checks pass
- **THEN** the check job succeeds on each of the three OSes

#### Scenario: A test fails on one OS only
- **WHEN** a test passes on Linux but fails on Windows
- **THEN** the Windows check job fails and names the failing test in its log, and the Linux and macOS jobs still report their own results

#### Scenario: Notices stale
- **WHEN** a pull request changes `pubspec.lock` without regenerating `THIRD_PARTY_NOTICES`
- **THEN** the check jobs fail at the notices check and name the packages that are missing, extra or at a different version

### Requirement: CI builds all six app targets
CI SHALL build the app in release mode for web, Linux and Android on a Linux runner, for Windows on a Windows runner, and for macOS and iOS on a macOS runner. The iOS build SHALL run without code signing. Each target is a separate job.

#### Scenario: All targets build
- **WHEN** the app compiles on every platform
- **THEN** six build jobs succeed, one per target

#### Scenario: One target breaks
- **WHEN** a change compiles on every platform except Windows
- **THEN** the Windows build job fails with the build error in its log, and the other five build jobs report their own results

#### Scenario: No signing identity
- **WHEN** the iOS build runs on a runner with no signing certificate or provisioning profile
- **THEN** it still produces an unsigned build and succeeds

### Requirement: CI validates the OpenSpec specs and changes
CI SHALL run strict OpenSpec validation of every spec and active change (`mise run spec:validate`) on a Linux runner.

#### Scenario: Specs valid
- **WHEN** every spec and active change passes strict validation
- **THEN** the validation job succeeds

#### Scenario: Invalid change
- **WHEN** a pull request adds a requirement without a scenario
- **THEN** the validation job fails and its log names the change, the requirement and the problem

### Requirement: CI runs the licence check and publishes the SBOM
CI SHALL run the dependency licence check and SHALL upload the CycloneDX SBOM generated from `pubspec.lock` as a build artifact of the run. The artifact SHALL NOT be uploaded when the licence check fails.

#### Scenario: Compatible dependencies
- **WHEN** every locked package's licence is allowed or excepted
- **THEN** the licence job succeeds and the run has an SBOM artifact

#### Scenario: Incompatible dependency added
- **WHEN** a pull request adds a dependency whose licence is not AGPL-compatible and not excepted
- **THEN** the licence job fails, names the package, its version and its licence, and the run has no SBOM artifact

### Requirement: CI checks DCO sign-off on pull requests
On pull requests, CI SHALL check every non-merge commit between the base branch and the pull request's head for a `Signed-off-by` trailer, as git parses trailers, that matches the commit's author name and email. The only exemption is a commit with Dependabot's author identity in a pull request that Dependabot opened.

#### Scenario: All commits signed off
- **WHEN** every non-merge commit in the pull request has a matching `Signed-off-by` line
- **THEN** the sign-off job succeeds

#### Scenario: Missing or mismatched sign-off
- **WHEN** one commit has no `Signed-off-by` line, or its line names someone other than the author
- **THEN** the sign-off job fails and names the commit's short hash, its subject and what is missing or mismatched, and points to CONTRIBUTING's sign-off section

#### Scenario: Dependabot commit
- **WHEN** a pull request opened by `dependabot[bot]` has a commit whose author is exactly `dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>`
- **THEN** the sign-off job skips that commit, lists it as skipped (bot author), and does not fail for it

#### Scenario: Bot identity outside a Dependabot pull request
- **WHEN** a pull request opened by a person has a commit with the Dependabot author identity
- **THEN** the sign-off job checks that commit like any other and fails it when it has no matching `Signed-off-by`

#### Scenario: Push to main
- **WHEN** the workflow runs for a push to `main`
- **THEN** the sign-off job does not run, because the commits were checked on their pull request
