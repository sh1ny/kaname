# esi-client-generation Specification

## Purpose
Keeps Kaname's ESI contract pinned to one compatibility date: a committed snapshot of CCP's ESI OpenAPI spec, a deliberate fetch for date bumps, and reproducible, offline generation of the typed client and route catalogue with a drift check.

## Requirements

### Requirement: One pinned spec snapshot
The repository SHALL hold one ESI OpenAPI spec snapshot and one pin file. The pin file SHALL record the compatibility date, the source URL the snapshot was fetched from, and the snapshot's SHA-256. The compatibility date SHALL be stated in this one place; generated code SHALL take it from the pin.

#### Scenario: Pin matches snapshot
- **WHEN** the snapshot's SHA-256 is computed after this change
- **THEN** it equals the hash in the pin file, and the pin's date is `2026-11-19`

#### Scenario: Pin missing a field
- **WHEN** the pin file lacks its date, source URL or hash
- **THEN** the generate task and the check task each exit non-zero naming the missing field, and the generate task writes no file

### Requirement: Generation reads only pinned bytes
Before parsing, the generate and check tasks SHALL hash the exact bytes they then parse and refuse them when the hash differs from the pin. They SHALL also refuse a pin whose date differs from the snapshot's `info.version` or its `X-Compatibility-Date` enum.

#### Scenario: Pinned bytes accepted
- **WHEN** the generate task runs on a snapshot whose hash and date match the pin
- **THEN** it parses the snapshot and writes the generated output

#### Scenario: Pin date edited by hand
- **WHEN** only the pin file's date is changed, and its hash still matches the snapshot
- **THEN** the generate task and the check task each exit non-zero naming the pin's date and the snapshot's date, and the generate task writes no file

#### Scenario: Snapshot edited by hand
- **WHEN** a byte of the snapshot is changed without updating the pin file
- **THEN** the generate task and the check task each exit non-zero saying the snapshot does not match the pin's hash, and the generate task leaves the existing generated output untouched

### Requirement: Deliberate fetch for a date bump
A fetch task SHALL take a compatibility date, download ESI's spec for that date, and replace the snapshot and pin file only when the downloaded spec reports that date. It SHALL be the only project task that downloads the spec, and no CI job SHALL run it.

#### Scenario: Fetch a listed date
- **WHEN** the fetch task runs with a date ESI serves and the download succeeds
- **THEN** the snapshot holds the downloaded spec, the pin file holds that date, the source URL and the new SHA-256, and the task exits 0

#### Scenario: Spec reports another date
- **WHEN** the downloaded spec's version or compatibility-date parameter differs from the requested date
- **THEN** the task exits non-zero naming both dates, and the snapshot and pin file are unchanged

#### Scenario: Download fails
- **WHEN** the download fails, times out or returns a non-200 status
- **THEN** the task exits non-zero naming the status or error, and the snapshot and pin file are unchanged

#### Scenario: Bad date argument
- **WHEN** the fetch task runs without a date or with a value that is not `YYYY-MM-DD`
- **THEN** it exits non-zero with usage text and downloads nothing

### Requirement: Fetch writes and verifies
The fetch SHALL write each file to its own uniquely named temporary file and rename it into place, the snapshot first and the pin last, then re-read both from disk and fail when the snapshot's hash differs from the pin's. A passing re-read SHALL NOT be taken as a guarantee against a later write.

#### Scenario: Re-read passes
- **WHEN** a single fetch writes the snapshot and then the pin
- **THEN** its re-read finds the snapshot's hash equal to the pin's and it exits 0, leaving no temporary file behind

#### Scenario: Two fetches interleave in one checkout
- **WHEN** fetches A and B download snapshots with different SHA-256 hashes, fetch A renames its snapshot into place, fetch B then writes its snapshot and pin and passes its re-read, and fetch A then writes its pin
- **THEN** fetch A's re-read finds B's snapshot under A's pin and A exits non-zero saying the snapshot does not match the pin's hash, and the check task fails on the pair left on disk until a fetch is rerun

### Requirement: Reproducible generation
A generate task SHALL write the typed client and the route catalogue from the snapshot alone, without network access. The same snapshot SHALL give byte-identical output, already in the formatter's output form.

#### Scenario: Generate twice
- **WHEN** the generate task runs twice on the same snapshot
- **THEN** the second run changes no byte of the generated files

#### Scenario: Unsupported construct in the snapshot
- **WHEN** the snapshot uses a schema construct, format or parameter location the generator does not support
- **THEN** the generate task exits non-zero naming the construct and the JSON path where it occurs, and writes no generated file

### Requirement: Drift check
A check task SHALL regenerate into a temporary directory and fail when any generated file differs from the committed output, when a generated file is missing or extra, or when the snapshot does not match the pin. It SHALL need no network and SHALL be part of the all-checks task.

#### Scenario: Committed output current
- **WHEN** the check task runs right after the generate task
- **THEN** it exits 0 and writes nothing inside the repository

#### Scenario: Generated file edited by hand
- **WHEN** a committed generated file differs from what the snapshot generates
- **THEN** the check task exits non-zero and names the differing file

#### Scenario: Snapshot bumped without regenerating
- **WHEN** the snapshot and pin are replaced by a fetch and the generate task is not run
- **THEN** the check task exits non-zero and names the generated files that differ
