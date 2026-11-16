# Spec Delta

## MODIFIED Requirements

### Requirement: Vendored assets are listed by hand
`THIRD_PARTY_NOTICES` SHALL have a hand-maintained section for every vendored third-party asset: the bundled fonts and each vendored skill source recorded in `.claude/skills/UPSTREAM.json`. Each entry SHALL give the component, its upstream repository URL, its licence, and the path of every licence text the source records.

#### Scenario: Current vendored assets listed
- **WHEN** the notices file is read after this change
- **THEN** it has an entry for Geist and for Literata naming `brand/fonts/OFL-geist.txt` and `brand/fonts/OFL-literata.txt` and the matching licence files bundled in `app_packages/kaname_ember_ui/`, and one entry per source in `UPSTREAM.json` with its repository URL and every licence file that source records (`license` and, where present, `repository_license`); the Serverpod entry names both the SSPL-1.0 and the BSD-3-Clause texts

#### Scenario: A vendored source without an entry
- **WHEN** a source's repository URL or one of its recorded licence files from `UPSTREAM.json`, a `brand/fonts/OFL-*.txt` file, or an `OFL-*.txt` file inside a package under `app_packages/`, does not appear in the hand-written sections
- **THEN** the notices check mode fails and names the missing source or file
