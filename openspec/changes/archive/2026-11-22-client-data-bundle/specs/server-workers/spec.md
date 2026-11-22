# Spec Delta

## MODIFIED Requirements

### Requirement: The server runs a compute worker isolate
In the monolith role and the development, staging or production run mode, the server SHALL start one compute worker isolate when it starts, and SHALL run every static-data job the server runs on it (build checks, imports, build comparisons, switches and bundle builds), never on the isolate that answers endpoints. The maintenance role and the test run mode SHALL start no worker; tests start one explicitly.

#### Scenario: Endpoints answer during an import
- **WHEN** an import is running on the compute worker and a client calls the health endpoint
- **THEN** the call answers in under 1 second and the import goes on

#### Scenario: Endpoints answer during a build comparison
- **WHEN** the compute worker is comparing two builds and a client calls the health endpoint
- **THEN** the call answers in under 1 second and the comparison goes on

#### Scenario: Endpoints answer during a bundle build
- **WHEN** the compute worker is building a bundle and a client calls the health endpoint
- **THEN** the call answers in under 1 second and the bundle build goes on

#### Scenario: Maintenance step
- **WHEN** the server runs as the maintenance migration step
- **THEN** no worker isolate starts and the step exits when its migrations are done

#### Scenario: Worker fails to start
- **WHEN** the compute worker cannot start
- **THEN** the server still serves requests, the failure is logged with the worker's name, and no import starts
