# self-host-stack Specification

## Purpose
Defines the Docker Compose stack that self-hosters and developers run: its services, how Caddy serves the web app and routes API traffic to the server, and how the stack's secrets are supplied without being committed.

## Requirements

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

### Requirement: The fallback-font path never serves the web app
Caddy SHALL answer every request under the web app's fallback-font path with 404 Not Found and an empty or plain-text body, never with the app's `index.html`, so the web engine's fallback-font requests fail fast on the app's own origin.

#### Scenario: Fallback font requested
- **WHEN** a request is sent to a file under the fallback-font path, for example `http://localhost/<fallback path>/roboto/v1/x.woff2`
- **THEN** Caddy answers 404, and the body is not the web app's `index.html`

#### Scenario: Ordinary app route still falls back
- **WHEN** a request is sent to an app route such as `http://localhost/settings` that has no file in the web build
- **THEN** Caddy serves the web app's `index.html` as before

### Requirement: The stack's server trusts only Caddy as proxy
The stack SHALL run its internal network on a fixed subnet whose dynamic address range excludes Caddy's fixed IPv4 address, and SHALL pass Caddy's address, and nothing else, to the server as its trusted proxies, so that the server identifies each client by the address Caddy forwards. Caddy SHALL NOT trust any forwarded-address header sent to it by a client. The deploy guide SHALL require any proxy an operator trusts to append the address it received the connection from.

#### Scenario: Two clients through Caddy
- **WHEN** a client on the stack host, reaching Caddy through the loopback port, holds 16 open announcement streams, and a client in a container on the stack's internal network, with its own address, subscribes through Caddy
- **THEN** the second client's subscription is admitted and receives the current announcement, because the server counts each client for its own address and never for Caddy's

#### Scenario: Client sends its own forwarded header
- **WHEN** a client on the stack host opens 17 announcement streams through Caddy, each on its own WebSocket connection whose upgrade request sends a different `X-Forwarded-For` value
- **THEN** the first 16 receive the current announcement and are still open after the refusal, the 17th completes normally with no event and no error, and a client in a container on the stack network still receives the announcement, because Caddy replaces the client's header and the server counts every stream for the address the connection to Caddy came from

#### Scenario: Configuration check
- **WHEN** the stack's Compose configuration is checked
- **THEN** the internal network has a fixed subnet and a dynamic address range inside it, Caddy has a fixed IPv4 address in the subnet but outside that range, and the server's `KANAME_TRUSTED_PROXIES` is exactly Caddy's address

#### Scenario: Local client through Docker's gateway
- **WHEN** a browser on the stack host reaches Caddy through the loopback port, and the connection arrives from the network's gateway address
- **THEN** the server counts the browser's streams for the gateway's address and logs no warning about the forwarded header

### Requirement: Caddy routes the confidential SSO callback to Kaname

Caddy SHALL route `/auth/esi/callback` to the server without serving the SPA or logging callback parameters. Confidential sign-in SHALL require the configured HTTPS callback, except when explicitly enabled for the loopback-only development stack at `http://localhost/auth/esi/callback`. An external TLS proxy SHALL preserve the callback route without logging its query.

#### Scenario: Browser returns to a configured self-host
- **WHEN** CCP sends the browser to the registered HTTPS callback path
- **THEN** Caddy routes it to the SSO handler, the response is not the app's `index.html`, and the callback query is absent from access logs

#### Scenario: Callback cannot be processed
- **WHEN** sign-in is disabled or the routed callback has no live authorization attempt
- **THEN** the route fails without reflecting callback parameters or serving the SPA, and the public health and static-data reads still work

#### Scenario: Owner uses the loopback stack without TLS
- **WHEN** the operator enables local HTTP sign-in and registers `http://localhost/auth/esi/callback`, and the browser uses the stack at `http://localhost/`
- **THEN** Caddy forwards the callback on that origin and the browser-binding requirement still applies

#### Scenario: Plain HTTP is configured for a non-local host
- **WHEN** the server is configured with a non-local HTTP callback, even with the loopback flag set
- **THEN** confidential sign-in stays disabled, public reads still work, and the response does not disclose credentials

### Requirement: Confidential SSO credentials reach only the running server

The stack SHALL take the confidential CCP client secret and the dedicated ESI vault key from deployment-only secret configuration. It SHALL NOT pass them into builds, migrations, Caddy or the client app. Missing or invalid SSO configuration SHALL NOT enable confidential exchanges or an admin-key fallback.

#### Scenario: Fully configured opt-in
- **WHEN** the operator configures the CCP registration and the dedicated vault key in the ignored deployment environment file
- **THEN** only the running server receives those secrets and can offer confidential sign-in

#### Scenario: Missing registration or vault key
- **WHEN** required SSO or vault configuration is absent or malformed
- **THEN** confidential sign-in is unavailable with no secret-bearing error, no shared-key admin fallback and no loss of anonymous read access
