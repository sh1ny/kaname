# Spec Delta

## Purpose

Defines the Docker Compose stack that self-hosters and developers run: its services, how Caddy serves the web app and routes API traffic to the server, and how the stack's secrets are supplied without being committed.

## ADDED Requirements

### Requirement: One Compose file runs the whole stack
The repository SHALL hold one Compose file under `deploy/` that runs four services, `server` (built from the repository), `postgres`, `redis` and `caddy`, plus a one-shot migration step. The migration step SHALL run once Postgres and Redis are healthy, and the server SHALL start only after it succeeds. Postgres and Redis data SHALL live in named volumes.

#### Scenario: Stack comes up
- **WHEN** a developer copies the environment example, fills in its values and runs `docker compose up` in `deploy/` on a machine with Docker
- **THEN** all four services start, the server's readiness probe answers 200 within 5 minutes of a cold build, and the health answer read through Caddy holds Postgres `up` and Redis `up`

#### Scenario: Data survives a restart
- **WHEN** the stack is stopped with `docker compose down` (without removing volumes) and started again
- **THEN** the server starts on the existing database without re-creating it, and no migration is applied twice

#### Scenario: Migration fails
- **WHEN** the migration step exits non-zero, for example on a database that holds a migration the server does not know
- **THEN** the `server` service does not start, and the migration step's log names the failure

#### Scenario: A backing service fails to start
- **WHEN** Postgres or Redis does not become healthy
- **THEN** the `server` service does not start, and `docker compose ps` shows the failing service as unhealthy

### Requirement: Caddy is the only published entry point
Caddy SHALL serve the app's web build at `/`, route requests under `/api/` to the server's API with that prefix removed, and pass `/livez` and `/readyz` to the server. Only Caddy SHALL publish a port on the host; Postgres, Redis and the server SHALL be reachable only on the stack's internal network. Locally the stack SHALL serve plain HTTP, published on the loopback address `127.0.0.1` only.

#### Scenario: Web app and API through one origin
- **WHEN** a browser opens `http://localhost/` on the host running the stack
- **THEN** it loads the app's web build, and a health call through the generated client with server URL `http://localhost/api/` reaches the server and returns its answer

#### Scenario: Unknown path under the API prefix
- **WHEN** a request is sent to `http://localhost/api/no-such-endpoint`
- **THEN** the server's not-found answer comes back, and Caddy never serves the web app's `index.html` for it

#### Scenario: Not reachable from the network
- **WHEN** another machine on the same network connects to the stack host's port 80
- **THEN** the connection is refused, because Caddy is published on `127.0.0.1` only

#### Scenario: Internal services are not published
- **WHEN** a client on the host connects to the Postgres, Redis or server ports directly, bypassing Caddy
- **THEN** the connection is refused, because no port other than Caddy's is published

### Requirement: Stack secrets are never committed
The stack SHALL read every password and secret from an environment file that git ignores. The repository SHALL hold an example of that file with placeholder values only. The stack SHALL refuse to start when a required secret is missing or empty.

#### Scenario: Example file only
- **WHEN** the repository's tracked files are listed
- **THEN** the environment example is tracked, holds no real secret, and the environment file itself is ignored

#### Scenario: Missing secret
- **WHEN** `docker compose up` runs with an environment file that leaves a required secret empty
- **THEN** Compose stops before starting any service and names the missing variable
