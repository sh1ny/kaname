# third-party-notices Specification

## Purpose

Keeps one `THIRD_PARTY_NOTICES` file at the repository root that names every bundled third-party asset and every resolved pub dependency with its licence, so Kaname's AGPL distribution honours each component's notice terms.

## Requirements

### Requirement: Vendored assets are listed by hand
`THIRD_PARTY_NOTICES` SHALL have a hand-maintained section for every vendored third-party asset: the bundled fonts, each vendored skill source recorded in `.claude/skills/UPSTREAM.json`, and the pinned ESI spec snapshot together with CCP's descriptions copied from it into the generated ESI client. Each entry SHALL give the component, its upstream repository URL (for the ESI spec, the source URL its pin file records), its licence, and the path of every licence text the source records.

#### Scenario: Current vendored assets listed
- **WHEN** the notices file is read after this change
- **THEN** it has an entry for Geist and for Literata naming `brand/fonts/OFL-geist.txt` and `brand/fonts/OFL-literata.txt` and the matching licence files bundled in `app_packages/kaname_ember_ui/`, and one entry per source in `UPSTREAM.json` with its repository URL and every licence file that source records (`license` and, where present, `repository_license`); the Serverpod entry names both the SSPL-1.0 and the BSD-3-Clause texts

#### Scenario: A vendored source without an entry
- **WHEN** a source's repository URL or one of its recorded licence files from `UPSTREAM.json`, a `brand/fonts/OFL-*.txt` file, or an `OFL-*.txt` file inside a package under `app_packages/`, does not appear in the hand-written sections
- **THEN** the notices check mode fails and names the missing source or file

#### Scenario: ESI spec snapshot listed
- **WHEN** the notices file is read after this change
- **THEN** it has an entry for CCP's ESI OpenAPI spec that names the snapshot's path and the generated folder `packages/kaname_esi/lib/src/generated/` as the CCP material, the source URL from its pin file, the licence name `EVE Developer License` with its URL, and CCP's proprietary notice, and says that Kaname's own code keeps its AGPL-3.0 licence

#### Scenario: ESI spec snapshot without an entry
- **WHEN** the ESI entry lacks the snapshot's path, the source URL recorded in its pin file, the licence name `EVE Developer License`, the licence URL, or CCP's proprietary notice line
- **THEN** the notices check mode fails and names each missing item

### Requirement: The dependency section is generated from the lockfile
A mise task SHALL regenerate a delimited dependency section of `THIRD_PARTY_NOTICES` from the root `pubspec.lock`: one entry per locked package with its name, version, source and licence text, or for SDK packages a reference to the SDK's licence. The task SHALL leave the hand-written sections unchanged.

#### Scenario: Regenerate after resolving
- **WHEN** the notices task runs after a resolve
- **THEN** the dependency section lists every package in `pubspec.lock`, sorted by name, and the text outside the section's delimiters is byte-for-byte unchanged

#### Scenario: Deterministic output
- **WHEN** the notices task runs twice with the same lockfile
- **THEN** the second run changes no byte of the file

#### Scenario: Licence file not found
- **WHEN** a locked non-SDK package has no licence file in its resolved location
- **THEN** the task exits non-zero, names the package and version, and leaves `THIRD_PARTY_NOTICES` unchanged

#### Scenario: Not resolved
- **WHEN** the notices task runs before the workspace was resolved
- **THEN** it exits non-zero with a message to run the resolve task first, and leaves the file unchanged

### Requirement: A stale dependency section is detectable
The notices task SHALL have a check mode that writes nothing and fails when the dependency section differs from what the current lockfile would generate, or when a vendored source is missing from the hand-written sections. CI SHALL run the check mode on every pull request and push to `main`.

#### Scenario: Up to date
- **WHEN** the check mode runs right after the notices task
- **THEN** it exits 0 and writes nothing

#### Scenario: Lockfile changed without regenerating
- **WHEN** a dependency is added or upgraded and the notices task is not rerun
- **THEN** the check mode exits non-zero and names the packages that are missing, extra or at a different version

#### Scenario: Stale notices in a pull request
- **WHEN** a pull request changes `pubspec.lock` without regenerating `THIRD_PARTY_NOTICES`
- **THEN** CI fails on that pull request with the check mode's message
