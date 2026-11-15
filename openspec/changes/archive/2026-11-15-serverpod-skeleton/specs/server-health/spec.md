# Spec Delta

## Purpose

Defines how the server reports its health: a typed answer that apps read through the generated client, and the HTTP probes that the self-host stack and operators use to tell whether the server is alive and ready.

## ADDED Requirements

### Requirement: The health endpoint returns a typed answer
The server SHALL expose a health call through the generated client that needs no sign-in and returns a typed answer: the server's version, and the status of Postgres and of Redis, each `up` or `down`. The answer SHALL NOT include hostnames, credentials, connection strings or error text from the dependencies.

#### Scenario: All dependencies up
- **WHEN** a client calls the health endpoint while Postgres and Redis are reachable
- **THEN** the answer holds the server package's version, Postgres `up` and Redis `up`

#### Scenario: Redis down
- **WHEN** a client calls the health endpoint while Redis is unreachable and Postgres is reachable
- **THEN** the call still returns an answer, with Postgres `up` and Redis `down`, and the answer holds no host, port or error message

#### Scenario: Postgres down
- **WHEN** a client calls the health endpoint while Postgres is unreachable
- **THEN** the call returns an answer with Postgres `down` within 10 seconds, and the answer holds no host, port or error message

### Requirement: Liveness and readiness probes answer over HTTP
The server SHALL answer an unauthenticated liveness probe with 200 while the process runs, without checking dependencies, and an unauthenticated readiness probe with 200 only when Postgres and Redis are both reachable and startup has finished, and 503 otherwise. Unauthenticated probe answers SHALL carry no dependency details.

#### Scenario: Ready server
- **WHEN** an unauthenticated request hits the readiness probe on a started server with Postgres and Redis reachable
- **THEN** it answers 200

#### Scenario: Dependency lost
- **WHEN** Redis or Postgres becomes unreachable after startup and an unauthenticated request hits both probes
- **THEN** the liveness probe answers 200, the readiness probe answers 503, and neither body names the dependency's host or error
