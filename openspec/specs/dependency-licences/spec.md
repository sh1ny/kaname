# dependency-licences Specification

## Purpose
Keeps every pub dependency of Kaname under a licence that is compatible with AGPL-3.0, and describes the locked dependency set in a machine-readable SBOM, both derived from the root `pubspec.lock`.

## Requirements

### Requirement: Locked packages are classified by licence
A licence check SHALL classify every package in the root `pubspec.lock` by an SPDX identifier, matching its normalised licence text (found as the notices task finds it) against the licence texts the tool knows. Packages taken from the Flutter SDK SHALL take the Flutter SDK's licence, BSD-3-Clause, except `sky_engine`, which bundles the engine's third-party licences and SHALL be accepted with the licence reference `LicenseRef-flutter-engine-bundle`.

#### Scenario: Known licence
- **WHEN** a locked package's licence file is the MIT licence with its own copyright line
- **THEN** the check classifies it as `MIT`, whatever the copyright holder or year

#### Scenario: Separate rights line
- **WHEN** a BSD-3-Clause text has `All rights reserved.` on its own line after its copyright line
- **THEN** the check classifies it as `BSD-3-Clause`

#### Scenario: Engine bundle
- **WHEN** the check meets the locked SDK package `sky_engine`
- **THEN** it accepts it without an exception and records `LicenseRef-flutter-engine-bundle`, not `BSD-3-Clause`

#### Scenario: Other Flutter SDK packages
- **WHEN** the check meets a locked SDK package other than `sky_engine`, such as `flutter_localizations` or `flutter_web_plugins`, which has no licence file in its package directory
- **THEN** it classifies it as `BSD-3-Clause` without an exception and reports no missing licence file

#### Scenario: Holder named inside a clause
- **WHEN** two BSD-3-Clause texts differ only in the holder named in the "Neither the name of … nor the names of its contributors" clause (for example "Google LLC" and "Google Inc.")
- **THEN** the check classifies both as `BSD-3-Clause`

#### Scenario: Optional title or appendix
- **WHEN** an MIT text starts with the title line "The MIT License (MIT)", or an Apache-2.0 text includes or omits the "APPENDIX: How to apply the Apache License to your work" section
- **THEN** the check classifies it as `MIT` or `Apache-2.0` as if the optional part were absent

#### Scenario: Changed clause
- **WHEN** a licence text matches a known licence except for a changed word in one of its clauses
- **THEN** the check classifies it as unrecognised, not as that licence

#### Scenario: Unrecognised licence text
- **WHEN** a locked package's licence text matches none of the known licences
- **THEN** the check fails, names the package and version, and says its licence is unrecognised

#### Scenario: No licence file
- **WHEN** a locked non-SDK package has no licence file
- **THEN** the check fails and names the package and version

#### Scenario: Not resolved
- **WHEN** the check runs before the workspace was resolved
- **THEN** it exits non-zero with a message to run the resolve task first

### Requirement: Only AGPL-compatible licences pass
The licence check SHALL fail when any locked package is classified with an SPDX identifier outside a committed allowlist of AGPL-3.0-compatible licences, unless an exception covers that package. Its output SHALL list every failing package, not only the first.

#### Scenario: All allowed
- **WHEN** every locked package is classified with an allowed identifier
- **THEN** the check exits 0 and prints each identifier with its package count

#### Scenario: Disallowed licence
- **WHEN** a locked package is classified with a known licence that is not on the allowlist
- **THEN** the check exits non-zero and names the package, its version and its SPDX identifier

### Requirement: Exceptions are explicit and owner-reviewed
A committed exceptions file SHALL be the only way to accept a package the check would fail. Each entry SHALL name the package, its exact version, the SPDX identifier or `unrecognised`, a reason, and the date of the owner's approval. An exception SHALL cover only that package at that version.

#### Scenario: Excepted package
- **WHEN** a locked package with an unrecognised licence has an exception entry for its exact version
- **THEN** the check passes for it and lists it as excepted with the entry's reason

#### Scenario: Version bumped past the exception
- **WHEN** an excepted package is upgraded to a version the entry does not name
- **THEN** the check fails for the new version as if no exception existed

#### Scenario: Stale exception
- **WHEN** an exception entry names a package or version that is not in `pubspec.lock`
- **THEN** the check fails and names the stale entry

#### Scenario: Exception records the wrong licence
- **WHEN** an exception entry's licence differs from the classification the check finds for that package and version
- **THEN** the check fails and names the entry, the recorded licence and the found one

#### Scenario: Redundant exception
- **WHEN** an exception entry covers a package whose licence is on the allowlist
- **THEN** the check fails and names the entry as not needed

#### Scenario: Malformed exceptions file
- **WHEN** the exceptions file cannot be parsed or an entry lacks a required field
- **THEN** the check fails, names the file and the entry, and classifies nothing as excepted

### Requirement: The licence policy file is validated
The allowlist and the exceptions SHALL live in one committed policy file. The check SHALL refuse a policy file with an unknown key, or with an allowlist entry that names a licence the check cannot recognise or that is not AGPL-3.0-compatible, and SHALL then classify nothing as allowed.

#### Scenario: Valid policy
- **WHEN** the policy file has only the known keys and every allowlist entry names a licence the check knows
- **THEN** the check loads it and applies it

#### Scenario: Unknown key
- **WHEN** the policy file has a key the check does not define, such as a misspelt `exceptons:`
- **THEN** the check fails and names the file and the key

#### Scenario: Incompatible allowlist entry
- **WHEN** an allowlist entry names a licence the check knows but that is not AGPL-3.0-compatible, such as `GPL-2.0-only`
- **THEN** the check fails, names the entry, and does not treat any package as allowed by it

#### Scenario: Unknown allowlist entry
- **WHEN** an allowlist entry names an SPDX identifier the check has no licence text for
- **THEN** the check fails, names the entry, and does not treat any package as allowed by it

### Requirement: An SBOM is generated from the lockfile
An SBOM task SHALL write a CycloneDX JSON document describing every package in the root `pubspec.lock`: its name, version, a `pkg:pub` package URL, its source, its SPDX licence identifier or licence reference (none when excepted as unrecognised) and, for hosted packages, the lockfile's SHA-256. The same lockfile SHALL produce byte-identical output.

#### Scenario: Generate
- **WHEN** the SBOM task runs after a resolve
- **THEN** it writes valid CycloneDX JSON with one component per locked package, sorted by name, and the `sky_engine` component carries `LicenseRef-flutter-engine-bundle`

#### Scenario: Deterministic
- **WHEN** the SBOM task runs twice with the same lockfile
- **THEN** the two outputs are byte-identical

#### Scenario: Not resolved
- **WHEN** the SBOM task runs before the workspace was resolved
- **THEN** it exits non-zero with a message to run the resolve task first and writes no file
