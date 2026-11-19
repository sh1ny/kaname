# server-workers Specification

## Purpose
Defines the server's worker isolates: which run, how long work is kept off the endpoint isolate, how a crashed worker is found and restarted, and how workers exchange messages with the main isolate and reach Postgres.

## Requirements

### Requirement: The server runs a compute worker isolate
In the monolith role and the development, staging or production run mode, the server SHALL start one compute worker isolate when it starts, and SHALL run static-data imports on it, never on the isolate that answers endpoints. The maintenance role and the test run mode SHALL start no worker; tests start one explicitly.

#### Scenario: Endpoints answer during an import
- **WHEN** an import is running on the compute worker and a client calls the health endpoint
- **THEN** the call answers in under 1 second and the import goes on

#### Scenario: Maintenance step
- **WHEN** the server runs as the maintenance migration step
- **THEN** no worker isolate starts and the step exits when its migrations are done

#### Scenario: Worker fails to start
- **WHEN** the compute worker cannot start
- **THEN** the server still serves requests, the failure is logged with the worker's name, and no import starts

### Requirement: A crashed worker is restarted and reported
When a worker isolate exits unexpectedly, the server SHALL log it with the worker's name and reason, record any import it was running as `failed` with reason "worker crashed" (or "interrupted" when the worker's lock is still held after a 30-second retry window), and start the worker again. Restarts SHALL wait 1 second, doubling to at most 60 seconds, so that a worker that fails at once does not restart in a tight loop.

#### Scenario: Crash during an import
- **WHEN** the compute worker exits while an import runs
- **THEN** once Postgres has released the worker's lock, the import record shows outcome `failed` with reason "worker crashed", no row of the import's build remains, and a new compute worker is running

#### Scenario: Worker fails repeatedly
- **WHEN** the compute worker exits right after each restart
- **THEN** the wait between restarts doubles up to 60 seconds, and each exit is logged

### Requirement: Workers exchange only typed messages
Messages between the main isolate and a worker SHALL be typed, serializable models with a version, never untyped maps. A message of an unknown type or version SHALL be rejected and logged, and SHALL NOT crash the receiver. A message carrying credentials SHALL NOT show them when printed or logged.

#### Scenario: Known message
- **WHEN** the main isolate asks the compute worker to run an import
- **THEN** the worker receives a typed import request and answers with a typed result

#### Scenario: Unknown message
- **WHEN** a worker receives a message of an unknown type or version
- **THEN** it logs the rejection, keeps running, and answers with a typed error when the message expected a reply

#### Scenario: Start message printed
- **WHEN** the worker's start message is converted to text
- **THEN** the text holds no database password

### Requirement: Workers reach Postgres through their own connections
A worker isolate SHALL reach Postgres only through a connection it opens itself from the settings in its start message, one connection per job, behind the same interfaces job code uses in solo. A worker SHALL NOT use a Serverpod session.

#### Scenario: Import writes to Postgres
- **WHEN** the importer running on the compute worker stores a build
- **THEN** the rows are written through the worker's own connection, and the same job code runs against an in-memory implementation in tests

#### Scenario: Postgres unreachable from the worker
- **WHEN** Postgres cannot be reached while a worker job runs
- **THEN** the job fails, the failure is logged with the worker's name and reason, and the worker stays running

#### Scenario: Postgres comes back
- **WHEN** a job failed because Postgres was down and Postgres is reachable again
- **THEN** the next job opens a new connection and succeeds without a server restart
