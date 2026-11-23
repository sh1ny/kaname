# Spec Delta

## MODIFIED Requirements

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
