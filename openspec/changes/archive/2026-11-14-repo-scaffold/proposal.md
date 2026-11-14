# Proposal

## Why

Kaname has no code yet: there is no workspace to build, analyse or test, and nothing tells contributors the project's clean-room, EULA and security rules. This is the first change of **M0 - Walking skeleton**. Every later M0 change builds on it: `serverpod-skeleton`, `ember-theme` and `app-shell` add packages to this workspace, and `ci-matrix` builds and tests it.

It advances these M0 exit criteria (all agent-verified):
- "The workspace layout of ADR 0003 exists. `dart analyze --fatal-infos` and the format check are clean." Fully, for the packages that exist after this change. Later changes keep it clean as they add packages.
- "CONTRIBUTING (no-copy rule, EULA boundary) and SECURITY.md exist." Fully.
- "`LICENSE`, `THIRD_PARTY_NOTICES`, a licence check … and an SBOM." Partly: `LICENSE` already exists, and this change adds `THIRD_PARTY_NOTICES` and the task that regenerates its dependency section. The licence check, the staleness check and the SBOM belong to `ci-matrix`.

It advances no user-verified criterion. One owner action, enabling GitHub private vulnerability reporting, is a `[user]` task.

## What Changes

- A root **pub workspace** (ADR 0003) with:
  - `app/`: a Flutter app (package `kaname_app`), created for web, Windows, Linux, macOS, Android and iOS with application ID `io.github.sh1ny.kaname`. It shows a placeholder screen only; the shell comes in `app-shell`.
  - `packages/kaname_core/`: the first pure-Dart shared package, empty apart from its library entry point and a test.
  - `tools/kaname_tools/`: a pure-Dart command-line package with the workspace, purity, required-files and notices checks.
  - A guard that fails when a pure-Dart package depends on or imports Flutter or Serverpod.
- Shared **analysis options** and a **format check** that pass with `--fatal-infos` across the workspace.
- **mise tasks** to resolve, analyse, check formatting, test, and regenerate third-party notices, plus one task that runs all the checks.
- **`THIRD_PARTY_NOTICES`**: hand-written sections for bundled fonts and vendored tooling skills, and a section for pub dependencies that a mise task regenerates from the lockfile.
- **`CONTRIBUTING.md`**: the no-copy (clean-room) rule, the EULA boundary, the Developer Certificate of Origin with a `Signed-off-by` line on every commit, the toolchain through mise, and the branch and PR flow.
- **`SECURITY.md`**: report vulnerabilities privately through GitHub's private vulnerability reporting; no versions are supported until release 0.1.
- A **pull request template** with checks for the no-copy rule, the EULA boundary and DCO sign-off.
- **AGENTS.md** and **README.md** updates: commits carry a `Signed-off-by` line for the author; the new mise tasks and the status change from "no product code".

## Capabilities

### New Capabilities
- `workspace-layout`: the repository's pub workspace, its package placement and naming, the pure-Dart boundary of shared packages, and the clean analysis and format bar every package meets.
- `contribution-policy`: what a contribution must satisfy and how it is made (no-copy rule, EULA boundary, DCO sign-off, PR checklist) and how vulnerabilities are reported.
- `third-party-notices`: the notices file that names every bundled third-party asset and dependency with its licence, and how its dependency section is regenerated.

### Modified Capabilities
None (no specs exist yet).

## Impact

- New: root `pubspec.yaml` and `pubspec.lock`, `analysis_options.yaml`, `app/`, `packages/kaname_core/`, `tools/kaname_tools/` (the checks and the notices generator), `THIRD_PARTY_NOTICES`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/pull_request_template.md`.
- Changed: `mise.toml` (tasks), `AGENTS.md` (sign-off rule, tasks), `README.md` (development section), `.gitignore` if the Flutter platform folders need entries.
- Dependencies: Flutter SDK packages, `lints`/`flutter_lints`, `test`, all pinned through the workspace lockfile. No Serverpod dependency yet.
- Follow-ups on other changes: `ci-matrix` adds the DCO check, the notices staleness check, the licence check and the SBOM. Its roadmap line does not list the DCO check yet; that change's proposal picks it up (S8).
- `ember-theme` names its package `kaname_ember_ui` and places it in `app_packages/` (S9). Its roadmap line still says `ember_ui`; that change's proposal uses the new name.
- Owner: enable private vulnerability reporting on `sh1ny/kaname` (`[user]` task).

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Packages this change creates

- **Choice:** Root workspace, `app/` (Flutter, all six platforms) and one pure-Dart shared package with the import guard. Other shared packages are created by the change that first needs them; `server/` comes in `serverpod-skeleton` and `ember_ui` in `ember-theme`.
- **Rejected:** Empty stubs for every planned shared package now (they stay empty for months and their APIs would be guessed); core only, with no app (`ci-matrix` would have no Flutter targets to build).
- **Reversal cost:** low
- **Important:** yes, binds future changes (where every later package goes)
- **Chosen by:** user

### S2: Package and folder naming

- **Choice:** `kaname_` prefix for every package, with no exception. `app/` holds `kaname_app`; `server/` will hold `kaname_server` and `kaname_client`; pure-Dart shared packages live in `packages/kaname_<name>/`, shared Flutter packages in `app_packages/kaname_<name>/` (design D6), tooling in `tools/kaname_<name>/`. The roadmap's `ember_ui` becomes `kaname_ember_ui` in `app_packages/` (S9).
- **Rejected:** Short names such as `core` (they clash easily on pub and in imports); a flat top level with no `packages/` folder.
- **Reversal cost:** medium (renames touch every import)
- **Important:** yes, binds future changes
- **Chosen by:** user

### S3: Contributor sign-off

- **Choice:** Developer Certificate of Origin. Every commit carries a `Signed-off-by` line, the owner's and agent-made commits included.
- **Rejected:** No sign-off (no provenance statement per commit); a CLA (heavier, needs a bot, puts contributors off).
- **Reversal cost:** medium (history stays as signed)
- **Important:** yes, changes behaviour users see (every contributor signs off)
- **Chosen by:** user

### S4: Vulnerability reporting channel

- **Choice:** GitHub private vulnerability reporting only, with no published email. Supported versions: none until release 0.1.
- **Rejected:** Adding a contact email (one more inbox to watch); email only (outside GitHub's advisory workflow).
- **Reversal cost:** low
- **Important:** yes, changes behaviour users see
- **Chosen by:** user

### S5: Scope of THIRD_PARTY_NOTICES

- **Choice:** Hand-written sections for bundled fonts and vendored skills, plus a pub-dependency section regenerated by a mise task from the lockfile. `ci-matrix` fails CI when the section is stale.
- **Rejected:** Vendored assets only, until `ci-matrix` (the file would be incomplete as soon as dependencies land); a fully generated file (more machinery than needed now).
- **Reversal cost:** low
- **Important:** yes, binds future changes (every dependency change regenerates the section)
- **Chosen by:** user

### S6: Application identifier

- **Choice:** `io.github.sh1ny.kaname` for the Android applicationId and the iOS and macOS bundle IDs.
- **Rejected:** An owner domain (none chosen); `org.kaname` (implies a domain the project does not own).
- **Reversal cost:** high once published to a store
- **Important:** yes, high reversal cost
- **Chosen by:** user

### S7: Community files

- **Choice:** A pull request template only, besides CONTRIBUTING and SECURITY.md. No Code of Conduct or issue forms yet.
- **Rejected:** Issue forms and a Code of Conduct now (no outside contributors yet); no template.
- **Reversal cost:** low
- **Important:** yes, changes behaviour users see
- **Chosen by:** user

### S8: DCO enforcement

- **Choice:** This change documents DCO and updates AGENTS.md's commit rules; `ci-matrix` adds a workflow step that fails PRs with unsigned commits. No third-party app.
- **Rejected:** The DCO GitHub App (an external app with repository access); documentation only (unenforced).
- **Reversal cost:** low
- **Important:** yes, binds future changes (`ci-matrix` scope and every commit)
- **Chosen by:** user

### S9: Name of the theme package

- **Choice:** `kaname_ember_ui`, following S2 with no exception; the roadmap's `ember_ui` names the component.
- **Rejected:** `ember_ui` as an exception (breaks the one naming rule for a kit that is not published separately); `kaname_ui` (drops the Ember name that DESIGN.md documents).
- **Reversal cost:** medium (renames touch every import)
- **Important:** yes, binds future changes (`ember-theme`)
- **Chosen by:** user
