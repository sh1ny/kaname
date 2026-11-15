# Spec Delta

## ADDED Requirements

### Requirement: CI runs the server tests on Linux
CI SHALL run the server packages' tests and the generated-code drift check in a separate job named `server` on a Linux runner. The job SHALL create the test secrets with the setup task, start Redis from the server package's development container, and use the embedded Postgres. No other runner OS SHALL run the server tests.

#### Scenario: Server tests pass
- **WHEN** a pull request leaves the server tests passing
- **THEN** the `server` job succeeds on the Linux runner

#### Scenario: Redis container missing
- **WHEN** the `server` job's Redis container fails to start
- **THEN** the job fails before the tests report success, and its log names Redis

#### Scenario: Generated client stale
- **WHEN** a pull request changes an endpoint or model without regenerating the client
- **THEN** the `server` job fails and names the generated files that differ

#### Scenario: A server test fails
- **WHEN** a server test fails
- **THEN** the `server` job fails and names the failing test in its log, and the `check` jobs on the three OSes still report their own results

### Requirement: CI checks the self-host stack on Linux
CI SHALL build and start the Compose stack from `deploy/` in a job named `stack` on a Linux runner, using placeholder secrets generated in the job, and SHALL fail unless the health answer read through Caddy holds Postgres `up` and Redis `up`. The job SHALL stop the stack and remove its volumes when it ends, whether it passed or failed.

#### Scenario: Stack healthy
- **WHEN** the stack starts and the health call through Caddy returns Postgres `up` and Redis `up`
- **THEN** the `stack` job succeeds

#### Scenario: Stack never becomes ready
- **WHEN** the server does not answer ready within the job's time limit
- **THEN** the `stack` job fails, prints the logs of every stack service, and removes the stack and its volumes
