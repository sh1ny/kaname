# Spec Delta

## MODIFIED Requirements

### Requirement: Analysis and formatting are clean
Every package's hand-written code SHALL pass analysis with infos treated as fatal; Serverpod-generated code is excluded from analysis. Every Dart file in a workspace member, generated code included, SHALL already be in the formatter's output form. The shared analysis options SHALL enable strict casts, strict inference and strict raw types. Dart files outside workspace members (vendored skills, the brand kit) are neither analysed nor formatted.

#### Scenario: Clean workspace
- **WHEN** the check task runs on the repository after this change
- **THEN** analysis reports no issues, the format check changes no file, and the task exits 0

#### Scenario: An analysis info
- **WHEN** any package contains code that produces an analysis info, warning or error
- **THEN** the analyse task exits non-zero and prints the file and line

#### Scenario: Files outside the workspace members
- **WHEN** the analyse and format tasks run
- **THEN** no file under `.claude/` or `brand/` is analysed, reported or changed

#### Scenario: An unformatted file
- **WHEN** a Dart file differs from the formatter's output
- **THEN** the format check exits non-zero, names the file and leaves it unchanged

#### Scenario: Generated code
- **WHEN** Serverpod-generated code in a server package would produce an analysis info, and is in the formatter's output form
- **THEN** the analyse task does not report it, and the format check passes; an unformatted generated file still fails the format check

### Requirement: Packages follow the placement and naming rule
Every package SHALL carry the `kaname_` name prefix and its directory name SHALL equal its package name, except the app. The app SHALL be `app/` (`kaname_app`), pure-Dart shared packages SHALL live in `packages/`, shared Flutter packages in `app_packages/`, tooling packages in `tools/`, and server packages under `server/`.

#### Scenario: Current packages comply
- **WHEN** the workspace check runs after this change
- **THEN** it reports `kaname_app` at `app/`, `kaname_core` at `packages/kaname_core/`, `kaname_tools` at `tools/kaname_tools/`, `kaname_server` at `server/kaname_server/` and `kaname_client` at `server/kaname_client/`, and exits 0

#### Scenario: A misplaced or misnamed package
- **WHEN** a package under `packages/`, `app_packages/`, `server/` or `tools/` is named without the `kaname_` prefix, or its directory name differs from its package name
- **THEN** the workspace check fails and names the package and the rule it breaks

### Requirement: One task runs every local check
The project SHALL offer mise tasks to resolve, analyse, check formatting, test, run the workspace and purity checks, and check the notices for staleness, and one task that runs all of them and fails if any fails. The all-checks task SHALL run the tests of every package except the server packages, whose tests run in their own task because they need Redis.

#### Scenario: All checks pass
- **WHEN** a developer runs the all-checks task on a clean clone after resolving
- **THEN** each check runs, the tests of every package outside `server/` pass, the server packages are analysed and format-checked, and the task exits 0

#### Scenario: One check fails
- **WHEN** any single check in the all-checks task fails
- **THEN** the task exits non-zero and the failing check's output names what failed

#### Scenario: Server tests run on their own
- **WHEN** a developer runs the server test task on Linux with Redis reachable
- **THEN** the server packages' tests run and the task exits 0 when they pass, or non-zero naming the failing test
