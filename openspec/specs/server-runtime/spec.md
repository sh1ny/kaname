# server-runtime Specification

## Purpose
Defines how the Kaname server is packaged and run: its packages in the workspace, the backing services each run mode uses, schema migrations at start, and the platforms on which the server is supported.

## Requirements

### Requirement: The server and its client are workspace packages
The repository SHALL hold the server as `kaname_server` at `server/kaname_server/` and its generated client as `kaname_client` at `server/kaname_client/`, both members of the root pub workspace. The Serverpod command-line tool SHALL be a development dependency of the server package, resolved through the root lockfile, and SHALL NOT be required as a globally installed tool.

#### Scenario: Server packages resolve with the workspace
- **WHEN** a developer runs the resolve task from the repository root on a fresh clone
- **THEN** `kaname_server` and `kaname_client` resolve into the root `pubspec.lock`, and the Serverpod tool runs through `mise exec -- dart run` from the server package

#### Scenario: Generated client out of date
- **WHEN** the server's endpoint or model definitions change and the generated client is not regenerated
- **THEN** the server package's check fails and names the generated files that differ

### Requirement: Redis is enabled in every server run mode
The server SHALL connect to Redis in the development, test, staging and production run modes. No server run mode SHALL disable Redis. The desktop and mobile apps SHALL NOT need Redis in any run mode.

#### Scenario: Run-mode configuration
- **WHEN** the server's run-mode configuration files are inspected
- **THEN** every run mode enables Redis with a host and port, and none leaves it disabled

#### Scenario: Redis unreachable at start
- **WHEN** the server starts in any run mode and Redis cannot be reached
- **THEN** the readiness probe answers 503 and the server log names Redis as the failing dependency

### Requirement: Each run mode uses its defined Postgres
The development and test run modes SHALL use an embedded Postgres whose data directory lives inside the server package and is never committed. The staging and production run modes, and the self-host stack, SHALL connect to an external Postgres of version 16 or later.

#### Scenario: Test run needs no external database
- **WHEN** the server tests run on a Linux machine with a reachable Redis and no Postgres installed
- **THEN** the tests start an embedded Postgres and pass

#### Scenario: Embedded data is not tracked
- **WHEN** the embedded Postgres has created its data directory and `git status` runs
- **THEN** no file under that data directory is listed as untracked or modified

### Requirement: Migrations are applied before the server serves
The repository SHALL hold the server's database migrations, and every committed migration SHALL be applied before the server serves requests, by one mechanism per run mode: a one-shot migration run in staging, production and the self-host stack; the developer's start with migrations applied in development; the test harness in test. The migration run SHALL exit non-zero on a database that does not match the server's migrations.

#### Scenario: Fresh database
- **WHEN** the migration run, then the server, starts against an empty database
- **THEN** every committed migration is applied before the server reports ready

#### Scenario: Database from a newer server
- **WHEN** the migration run starts against a database that holds a migration the server does not know
- **THEN** the migration run exits non-zero and its log names the mismatch

### Requirement: The server image takes its toolchain from mise
The server's container image SHALL install Flutter and Dart only through mise, from the committed `mise.toml` and `mise.lock` in locked mode, and SHALL resolve dependencies exactly as the committed `pubspec.lock` holds them. No Dockerfile SHALL state a Flutter or Dart version of its own.

#### Scenario: Image matches the pinned toolchain
- **WHEN** the server image is built
- **THEN** the Dart that compiled the server is the one mise installs from `mise.lock`, and the build log shows the workspace resolved with the lockfile enforced

#### Scenario: No secrets in the image
- **WHEN** the server image is built from a checkout that holds generated development secrets
- **THEN** the image contains no `passwords.yaml` and no `.env` file

#### Scenario: Lockfile out of date
- **WHEN** the image is built from a checkout whose `pubspec.lock` does not satisfy the pubspecs
- **THEN** the build fails at dependency resolution instead of resolving new versions

### Requirement: Insights and persistent session logs run only in development
The Insights server and persistent session logging SHALL be enabled only in the development run mode. In test, staging and production, and in the self-host stack, the Insights server SHALL be off and session logs SHALL go to the console only.

#### Scenario: Production configuration
- **WHEN** the production and staging run-mode configuration is inspected
- **THEN** the Insights server is disabled and persistent session logging is off, while console logging is on

#### Scenario: Calls in the stack
- **WHEN** the self-host stack serves health calls
- **THEN** no session log row is written to Postgres and no Insights port is listening

### Requirement: A fresh clone can start the server locally
The project SHALL offer a setup task that creates the development and test secrets of the server package when they are missing, from one ignored source file, and leaves existing secrets unchanged. The secrets SHALL never be committed.

#### Scenario: Fresh clone
- **WHEN** a developer runs the setup task on a fresh clone and then the server test task on Linux with Docker
- **THEN** the setup writes the ignored secrets, the development Redis starts with the generated password, and the server tests run

#### Scenario: Existing secrets
- **WHEN** the setup task runs again on a checkout that already has its secrets
- **THEN** the existing passwords are unchanged and `git status` lists no secret file

### Requirement: Agents reach the server through the Serverpod MCP entry
The project's Claude and OMP MCP configurations SHALL each hold a Serverpod entry that serves `server/kaname_server` through the package-local Serverpod tool run through mise, and Claude's project settings SHALL enable and allow-list it.

#### Scenario: Entry starts
- **WHEN** an agent harness starts the Serverpod MCP entry from the repository root
- **THEN** the bridge starts and names `server/kaname_server` as the package it serves

#### Scenario: Server not running
- **WHEN** an agent calls a Serverpod MCP tool while no runner is running for the package
- **THEN** the bridge answers with its explicit "the server is not running" error instead of failing to start

### Requirement: The server is supported only as a Linux container
The server SHALL be supported only when it runs in a Linux container, as the self-host stack runs it, or on Linux for development and tests. Running the server natively on Windows or macOS is not supported, and CI SHALL NOT run the server's tests there.

#### Scenario: Supported platform stated
- **WHEN** a self-hoster reads the deployment documentation
- **THEN** it states that the server runs as a `linux/amd64` container (on Windows and macOS, through a Linux container runtime, and on arm64 hosts under emulation) and that native Windows and macOS servers are unsupported

#### Scenario: Server tests on a non-Linux runner
- **WHEN** CI runs the local checks on a Windows or macOS runner
- **THEN** the server packages are analysed and format-checked there, and no server test runs on that runner
