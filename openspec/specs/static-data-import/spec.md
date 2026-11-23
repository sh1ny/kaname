# static-data-import Specification

## Purpose
Defines how the server takes in an EVE static data export (SDE) build as data: where a build comes from, how it is stored side by side with the active build, how drift in CCP's format is kept and reported, and what each import records.

## Requirements

### Requirement: An import reads a build from CCP or a local zip
The importer SHALL read one SDE build in CCP's JSON Lines format, either downloaded from CCP by build number, with the latest build number read from CCP's `latest.jsonl`, or from a local zip file. Both sources SHALL give the same stored result for the same build. The build number SHALL come from the build's own `_sde` record, never from a file name.

#### Scenario: Latest build from CCP
- **WHEN** an import from CCP starts, `latest.jsonl` names build N, and the downloaded zip's `_sde` record holds build N
- **THEN** the import record holds build number N and source `ccp`

#### Scenario: Local zip
- **WHEN** an import starts from a local zip whose `_sde` record holds build N
- **THEN** the stored rows equal those of an import of build N from CCP, and the import record holds source `local`

#### Scenario: Build number disagrees
- **WHEN** `latest.jsonl` names build N but the downloaded zip's `_sde` record holds another number
- **THEN** the import fails with reason "build number mismatch" naming both numbers, and no row of that import remains

#### Scenario: Unreachable or corrupt source
- **WHEN** CCP cannot be reached, the download is cut off, or the zip cannot be read
- **THEN** the import fails with a recorded reason naming the source, and no build row or data row of that import remains

### Requirement: A build is imported side by side
The importer SHALL store each build under its own build number, next to any active build, and SHALL NOT change the active build's rows or which build is active, except through bootstrap activation. An import whose transaction aborts SHALL leave no rows of its build behind. An import whose commit landed SHALL keep its build and its `succeeded` record, even when the commit's acknowledgement was lost or the server stopped as it committed.

#### Scenario: New build next to the active one
- **WHEN** build N is active and build N+1 is imported successfully
- **THEN** both builds' rows exist, build N is still active, and build N+1 is staged

#### Scenario: Import fails partway
- **WHEN** build N is active and the import of build N+1 fails after some rows were written
- **THEN** build N is still active with its rows unchanged, and no row of build N+1 remains

#### Scenario: Server stops during an import
- **WHEN** the server stops while build N+1 is being imported, the import's transaction aborts, and the server starts again
- **THEN** no row of build N+1 remains, and that import's record changes from `running` to `failed` with reason "interrupted" before any new import starts

#### Scenario: Server stops as the import commits
- **WHEN** the server stops while build N+1's import transaction is committing, that commit lands, and the server starts again
- **THEN** build N+1 and its rows remain, its import record stays `succeeded`, and the start-up sweep does not mark it `failed`

#### Scenario: Commit acknowledgement lost
- **WHEN** build N+1's import commit lands but its acknowledgement is lost, and the importer then finishes that exact record conditionally on a new connection without the static-data lock
- **THEN** the conditional finish changes nothing, the record stays `succeeded`, and the import is reported as succeeded with the state its own transaction chose

### Requirement: Typed files keep typed columns and the full record
For each file of the typed set (categories, groups, types, market groups, meta groups, dogma attributes, dogma attribute categories, dogma effects, dogma units, type dogma, regions, constellations, solar systems), the importer SHALL store each record's known fields in typed columns and SHALL also store the record's full original content as JSON.

#### Scenario: Known fields are typed
- **WHEN** a type record holds its id, group id, name and published flag
- **THEN** those values are queryable as typed columns of that build, and the stored JSON equals the record as CCP shipped it

#### Scenario: Known field missing from a record
- **WHEN** a record of a typed file lacks an optional known field
- **THEN** the typed column holds no value for that row and the import continues

#### Scenario: Known field with the wrong type
- **WHEN** a record of a typed file holds a known field whose value has another JSON type than expected
- **THEN** the typed column holds no value, the full JSON keeps the value, and the import record reports the file, the field and the number of affected records

### Requirement: Other files are stored record by record
The importer SHALL store every file outside the typed set record by record as raw JSON, under its file name and the build number. Records of integer-keyed files SHALL keep their key.

#### Scenario: Known untyped file
- **WHEN** a build holds a file in the importer's list of known files that is outside the typed set
- **THEN** each of its records is stored as raw JSON for that build, and the file is not reported as new

#### Scenario: Empty file
- **WHEN** a file in a build has no records
- **THEN** the import continues and the import record lists the file with zero records

### Requirement: A bad record is skipped and reported
A record that is not valid JSON, or a record of a typed file whose key is missing, of the wrong type, or already seen in that file, SHALL be skipped and SHALL NOT stop the import. The import record SHALL list the file, line and reason of each skipped record, up to 100 per file, and the count per file.

#### Scenario: Invalid JSON line
- **WHEN** one line of a file is not valid JSON
- **THEN** the import succeeds without that line, and the import record lists the file, the line number and reason "invalid JSON"

#### Scenario: Duplicate key in a typed file
- **WHEN** two records of the types file hold the same type id
- **THEN** the first is stored, the second is skipped, and the import record lists the second's line with reason "duplicate key"

#### Scenario: Every line bad
- **WHEN** every line of a required file is skipped
- **THEN** the import fails as if that file were missing

### Requirement: Drift is kept and reported
A file outside the importer's list of known files, and a field outside the known columns of a typed file, SHALL be kept and reported in the import record. Neither SHALL stop the import.

#### Scenario: New file
- **WHEN** a build holds a file that is not in the list of known files
- **THEN** its records are stored as raw JSON, the import succeeds, and the import record lists the file as new

#### Scenario: New field in a typed file
- **WHEN** records of a typed file hold a field outside its known columns
- **THEN** the field's values stay in each record's JSON, the import succeeds, and the import record lists the file, the field and the number of records holding it

### Requirement: Only a missing required file stops an import
The required files SHALL be the typed set and the file holding the `_sde` record. The importer SHALL fail an import when a required file is missing, naming the missing files. A missing known file outside the required set SHALL be reported and SHALL NOT stop the import.

#### Scenario: Typed file missing
- **WHEN** a build lacks the types file
- **THEN** the import fails, the import record names the types file as missing, and no row of that build remains

#### Scenario: Build record missing
- **WHEN** a local zip holds no `_sde` record
- **THEN** the import fails with reason "no build number", and no row of that import remains

#### Scenario: Known untyped file missing
- **WHEN** a build lacks a file in the list of known files that is outside the required set
- **THEN** the import succeeds and the import record lists that file as missing

### Requirement: The known-ids table is checked against each build
The ids code must know SHALL live in one small table, never in code generated from SDE content. Each import SHALL check every id in it against the build and record which ids are missing or have a different kind than expected. A failed check SHALL NOT stop the import.

#### Scenario: All known ids present
- **WHEN** every id in the known-ids table exists in the build with its expected kind
- **THEN** the import record shows the known-ids check as passed

#### Scenario: Known id missing
- **WHEN** an id in the known-ids table does not exist in the build
- **THEN** the import succeeds and the import record lists that id, its name in the table and its expected kind as missing

### Requirement: No code is generated from SDE content
The repository SHALL hold no Dart enum, constant or class generated from SDE content, and no tool that reads SDE input to write Dart source. Taking a new build SHALL need no rebuild, migration or code change unless a typed file changes the meaning of a known field.

#### Scenario: New build with new content
- **WHEN** a build adds types, groups, attributes or a new file
- **THEN** the running server imports it without a rebuild, a new migration or a code change

#### Scenario: Id constants outside the known-ids table
- **WHEN** a Dart source file outside the known-ids table declares an integer constant, or an enum value with an integer, named as a type, group, category, attribute or effect id
- **THEN** the static-data source scan test fails and names the file and line

### Requirement: Each import checks the industry and logistics fields
The importer SHALL check each build against a declared list of fields that industry and logistics need, and record for each field whether the build has it and how many records hold it. A missing field SHALL be reported and SHALL NOT stop the import.

#### Scenario: All fields present
- **WHEN** a build holds every declared industry and logistics field
- **THEN** the import record shows each field as present, with its record count

#### Scenario: Field missing after a patch
- **WHEN** a build lacks a declared field, or no record holds it
- **THEN** the import succeeds and the import record lists that field as missing

### Requirement: Every import is recorded
Each import attempt SHALL leave one import record: build number when known, source, start and end time, outcome (`running`, `succeeded`, `failed`, `skipped`), the failure reason, record counts per file, and the drift, bad-record, known-ids and field-check reports. A `succeeded` outcome SHALL be stored atomically with the build's rows. Import records SHALL hold no credentials and no local paths outside the server's data.

#### Scenario: Successful import
- **WHEN** an import of build N succeeds
- **THEN** one import record holds build N, outcome `succeeded`, a record count for every file, and the four reports

#### Scenario: Build already present
- **WHEN** an import of build N starts while build N is already stored
- **THEN** no data is written and the import record holds build N with outcome `skipped`

### Requirement: Imports run one at a time within a storage bound
At most one import SHALL run at a time across every process that imports into the same database. At rest there SHALL be at most one active, one previous and one staged build. An import SHALL remove the staged build, if any, before it writes its first row, and SHALL never remove the active or the previous build.

#### Scenario: Second import requested
- **WHEN** an import is requested while another is running, in the server or the development task
- **THEN** no second import starts, and the request is recorded with outcome `skipped` and reason "import already running"

#### Scenario: Another build is staged
- **WHEN** build N is active, build N-1 is previous, build M is staged (older or newer than the new build), and an import of build N+2 starts
- **THEN** build M's rows are removed before the import writes its first row, and builds N and N-1 keep their states and rows

#### Scenario: Import fails after removing the staged build
- **WHEN** build M was staged and the import that removed it then fails
- **THEN** build M stays removed, no row of the failed import remains, and the active and previous builds are unchanged

### Requirement: An import starts when no build is active
On start in the development, staging or production run mode and the monolith role, a server with no active build SHALL run a build check, which imports CCP's latest build; a start-up pass failing before that check SHALL be retried every 30 seconds. A server with an active build SHALL import on start only when its start-up check finds a newer build. The test run mode and the maintenance role SHALL start no import on start. A development task SHALL run the same import against a local zip.

#### Scenario: First start
- **WHEN** the server starts with no stored build and CCP is reachable
- **THEN** an import of CCP's latest build runs, and the server answers requests while it runs

#### Scenario: First start offline
- **WHEN** the server starts with no stored build and CCP cannot be reached
- **THEN** the server still starts and serves, no import record is written, and a failed check record names CCP as unreachable

#### Scenario: First start while Postgres is briefly down
- **WHEN** the server starts with no stored build and its start-up sweep fails because Postgres does not answer, and Postgres answers 40 seconds later
- **THEN** a later start-up pass sweeps and runs the check, which imports CCP's latest build

#### Scenario: Worker cannot reach Postgres for the start-up check
- **WHEN** the server starts with no stored build, the start-up lookup succeeds, the worker receives the check but cannot open its own Postgres connection, and Postgres answers again 20 seconds later
- **THEN** the pass is retried 30 seconds after it started, and the retried check imports CCP's latest build

#### Scenario: Restart with an active build
- **WHEN** the server starts with an active build
- **THEN** no import starts unless the start-up check finds that CCP's latest build is newer than the active build and not held

#### Scenario: Test run mode or migration step
- **WHEN** the server starts with no stored build in the test run mode, or as the maintenance migration step
- **THEN** no import starts and no request goes to CCP

### Requirement: Only the first build is activated by the importer
The importer SHALL make a build active only when no build is active. Every other successful import SHALL leave the build staged, for the build switch to take it from there.

#### Scenario: Bootstrap
- **WHEN** an import of build N succeeds and no build is active
- **THEN** build N becomes active and no build is previous

#### Scenario: Later build
- **WHEN** an import of build N+1 succeeds while build N is active
- **THEN** the import itself leaves build N active and build N+1 staged, and the switch to build N+1 then follows as the build switch requires

#### Scenario: Failed first import
- **WHEN** the first import fails
- **THEN** no build is active and the next server start queues the import again
