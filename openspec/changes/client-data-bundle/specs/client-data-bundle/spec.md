# Spec Delta

## Purpose

Defines the client data bundle: the compact, versioned file of static data that the server builds once per SDE build and that apps download, keep and search offline, and that later feeds the fit engine.

## ADDED Requirements

### Requirement: A bundle holds one build's client data
A bundle SHALL hold the data of exactly one SDE build: the typed columns of the 13 typed files, each type's `radius`, `factionID`, `raceID` and `variationParentTypeID`, the full JSON of each record of the five dogma files, and the full JSON of each buff, mutaplasmid and fighter-ability record. It SHALL name its format version, its build number, its release date and the locales its names cover, and SHALL hold no raw JSON for the other typed files.

#### Scenario: Build with every file
- **WHEN** a bundle is built from build N, which has the typed set, `dbuffCollections`, `dynamicItemAttributes`, `fighterAbilities` and `fighterAbilitiesByType`
- **THEN** the bundle names build N, its format version, build N's release date and the locale `en`, holds a section for each of those 17 files, and a type record carries its typed columns, `radius`, `factionID`, `raceID` and `variationParentTypeID`, and no description

### Requirement: Section presence follows accepted records
Each section SHALL record the count of its accepted records and SHALL be present only when that count is above zero, on both build paths, whatever import report is kept.

#### Scenario: Optional file missing
- **WHEN** a bundle is built from a build that has no `dynamicItemAttributes` file
- **THEN** the bundle is built, names that section as absent, and every other section is present

#### Scenario: Optional file with no accepted records
- **WHEN** a build's `dynamicItemAttributes` file is present but holds only unreadable lines, and its import report has since been pruned
- **THEN** the bundle built by the server and the bundle built from the zip with no server both name that section as absent and have the same bytes

### Requirement: Names are keyed by locale
Each name a bundle holds SHALL be stored under its locale. A bundle built by this change SHALL hold English names only, and a reader SHALL accept a bundle that holds further locales. This rule SHALL apply to the names a bundle projects; full raw JSON SHALL keep its fields as shipped.

#### Scenario: English names
- **WHEN** a type whose SDE name has English and German text is put in a bundle
- **THEN** the bundle holds that type's name under `en` only

#### Scenario: Name without English text
- **WHEN** a record's SDE name has no English text
- **THEN** the record is kept with no `en` name, and the build of the bundle does not fail

### Requirement: The builder is deterministic and runs without a server
With the same builder version and locked dependencies, the same build SHALL give byte-identical bundles on every native Dart runtime, built by the server from its stored build or from a local SDE zip with no server. Both paths SHALL keep the records and typed values the server's import keeps, raw duplicates in key then line order, and SHALL take the release date from the first `_sde` object whose build number numerically equals the build. Records SHALL be in key order and JSON keys sorted.

#### Scenario: Server and local zip agree
- **WHEN** build N is imported by the server and its bundle built, and the same build's zip is built into a bundle with no server
- **THEN** the two bundles have the same bytes and the same SHA-256

#### Scenario: Odd input agrees
- **WHEN** a zip has a typed file with a duplicate key and an integer column written as a float, and the raw-only `dbuffCollections` file has a duplicate key, and it is built by the server after import and with no server
- **THEN** both bundles keep the first typed record of that key, the same typed value for that column and both `dbuffCollections` records in line order, and have the same bytes

#### Scenario: Compiled builder agrees
- **WHEN** the same build's zip is built into a bundle by the builder on the Dart VM and by the AOT-compiled builder
- **THEN** the two bundles have the same bytes

#### Scenario: Unreadable input
- **WHEN** the local zip given to the builder is not a readable SDE zip
- **THEN** the builder fails with a reason naming the zip, and writes no bundle

### Requirement: Readers refuse a bundle they cannot read
A reader SHALL check a bundle's format version, build number and SHA-256 before using it, and SHALL refuse a bundle with an unknown major format version, a hash that does not match, or a build number other than the one it asked for, naming the reason.

#### Scenario: Valid bundle
- **WHEN** a reader opens a bundle whose format version it supports, whose build number is the one asked for and whose hash matches
- **THEN** it returns the bundle's types, solar systems and dogma data

#### Scenario: Newer major format
- **WHEN** a reader opens a bundle with a higher major format version than it supports
- **THEN** it refuses the bundle with reason "unsupported bundle format" naming both versions

#### Scenario: Wrong build
- **WHEN** a reader asks for build N and opens a bundle whose hash matches but whose header names build M
- **THEN** it refuses the bundle with reason "wrong build" naming both builds

#### Scenario: Corrupt download
- **WHEN** a downloaded bundle's SHA-256 does not match the announced hash
- **THEN** the reader refuses it with reason "hash mismatch" and the bundle is not used

### Requirement: Every stored build has its bundle
The server SHALL build a bundle for a staged build before switching to it, and for the active build when it has none, on the compute worker. Each bundle SHALL be stored with its build, with its size and SHA-256, and removed with its build. A first build, which has no build to switch from, SHALL have its bundle built in the same check right after it becomes active. A failed bundle build SHALL be recorded with its reason and SHALL NOT stop the switch.

#### Scenario: Switch to a new build
- **WHEN** an import of build N+1 succeeds while build N is active
- **THEN** build N+1's bundle is stored before build N+1 becomes active, and build N's bundle stays stored

#### Scenario: First import
- **WHEN** the first build ever imported becomes active
- **THEN** its bundle is built in the same check and announced once it is stored

#### Scenario: Bundle build fails
- **WHEN** the bundle build for build N+1 fails before the switch
- **THEN** the switch to build N+1 still happens, the failure is recorded with its reason for build N+1, the same check makes no second attempt, and the next 60-second repair, server start or build check builds the bundle again

#### Scenario: Build removed
- **WHEN** a switch removes the old previous build N-1
- **THEN** build N-1's bundle is removed in the same step

### Requirement: A missing active bundle is repaired
Every start of the monolith role in the development, staging or production run mode, every build check that holds the static-data lock, and every 60-second check while the bundle is still owed SHALL build the active build's bundle when it is missing, failed or of another format version. A check SHALL NOT build a bundle it already attempted in that check.

#### Scenario: Restart after an interrupted bundle build
- **WHEN** the server stops while it builds the active build's bundle, and starts again the same day after the daily check
- **THEN** the bundle is built during start-up, with no build check, and announced as soon as it is stored

#### Scenario: Lock held at start
- **WHEN** the server starts with no check due while another process holds the static-data lock, and that process exits without building the active build's missing bundle
- **THEN** a later 60-second tick at which no repair is outstanding attempts the repair, and the bundle is announced once it is stored

#### Scenario: Format version changed
- **WHEN** a server whose bundle format is 2.0 starts and the active build's stored bundle is format 1.0
- **THEN** it builds a format 2.0 bundle for the active build and announces it

### Requirement: The server serves a bundle by build
The server SHALL serve the announced bundle and the previous one, at most one per build, over plain HTTP under its base path, addressed by build number and SHA-256, without authentication, with caching headers that mark it immutable, deciding from the announcer's state and never from the database. It SHALL answer 404 for any other build, hash or format version, a stored bundle included.

#### Scenario: Download
- **WHEN** a client asks for build N's bundle with its announced hash
- **THEN** the server answers 200 with the bundle bytes, its length and an immutable cache header

#### Scenario: Bundle not held
- **WHEN** a client asks for a build whose bundle is neither announced nor the previous announcement, or for a staged build's stored bundle
- **THEN** the server answers 404 and sends no bytes

#### Scenario: No longer held while cached
- **WHEN** build N's bundle was just downloaded, so HTTP caches hold it, and later switches leave build N neither announced nor previous
- **THEN** a request for build N's bundle that reaches the server, with or without `If-None-Match`, answers 404

#### Scenario: Replaced bundle
- **WHEN** build N's bundle with hash H is announced, then rebuilt with hash H2, and H2 is announced
- **THEN** a request for build N with hash H answers 404 and one with hash H2 answers 200

#### Scenario: Old format after an upgrade
- **WHEN** a server that builds format 2 still stores the previous build's format 1 bundle and a client asks for it
- **THEN** the server answers 404, and a request for the active build's format 2 bundle answers 200

### Requirement: Bundle downloads are bounded
Above 16 bundle requests in flight the server SHALL answer 503 with a retry time. A request SHALL hold its place until its body has been written, has failed or was cancelled, and a transfer still running 2 minutes after admission SHALL be closed, freeing its place. A bundle request SHALL NOT read the database.

#### Scenario: Too many downloads
- **WHEN** 16 bundle responses are in flight and another client asks for a bundle
- **THEN** the server answers 503 with `Retry-After`, and the health endpoint still answers in under 1 second

#### Scenario: Stalled download
- **WHEN** 16 clients stop reading their bundle responses
- **THEN** after the 2-minute deadline their places are freed and the next request answers 200

#### Scenario: Database not answering
- **WHEN** Postgres stops answering while the announcer holds build N's bundle
- **THEN** requests for build N's bundle answer 200, and none of them waits on the database
