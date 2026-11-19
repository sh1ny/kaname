# Spec Delta

## MODIFIED Requirements

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

### Requirement: An import starts when no build is active
On start in the development, staging or production run mode and the monolith role, a server with no active build SHALL run a build check, which imports CCP's latest build. A server with an active build SHALL import on start only when its start-up check finds a newer build. The test run mode and the maintenance role SHALL start no import on start. A development task SHALL run the same import against a local zip.

#### Scenario: First start
- **WHEN** the server starts with no stored build and CCP is reachable
- **THEN** an import of CCP's latest build runs, and the server answers requests while it runs

#### Scenario: First start offline
- **WHEN** the server starts with no stored build and CCP cannot be reached
- **THEN** the server still starts and serves, no import record is written, and a failed check record names CCP as unreachable

#### Scenario: Restart with an active build
- **WHEN** the server starts with an active build
- **THEN** no import starts unless the start-up check finds that CCP's latest build is newer than the active build and not held

#### Scenario: Test run mode or migration step
- **WHEN** the server starts with no stored build in the test run mode, or as the maintenance migration step
- **THEN** no import starts and no request goes to CCP
