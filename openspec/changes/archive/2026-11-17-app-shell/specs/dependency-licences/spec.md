# Spec Delta

## MODIFIED Requirements

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
