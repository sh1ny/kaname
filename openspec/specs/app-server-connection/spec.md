# app-server-connection Specification

## Purpose
Defines how the app finds its server on each platform, calls the server's health endpoint through the generated client, and shows the answer, an unreachable server or a missing server address to the user.

## Requirements

### Requirement: The web app talks to the server on its own origin
A release web build SHALL reach the server's API at the `/api/` path of the origin it was loaded from, whatever server address the build was given, and SHALL make no request to any other origin to reach the server. A debug web build SHALL use a build-time server address instead when one is given, for development without the stack.

#### Scenario: Served by the stack
- **WHEN** the web app is loaded from `http://127.0.0.1:<port>/` served by the self-host stack
- **THEN** its health call goes to `http://127.0.0.1:<port>/api/` and no request reaches another origin

#### Scenario: Served under another host name
- **WHEN** the same web build is served from a different host name
- **THEN** its health call goes to that host's `/api/` path, with no rebuild

#### Scenario: Release web build given an address
- **WHEN** a release web build is made with a build-time server address and served by the stack
- **THEN** its health call still goes to its own origin's `/api/` path and never to the given address

### Requirement: Desktop and mobile take an optional build-time server address
Desktop and mobile builds SHALL read the server address from a build-time setting. A build without one SHALL make no server call and SHALL show that no server is configured. A build with an address that is not an absolute `http` or `https` URL SHALL also make no call and SHALL show that the configured address is invalid.

#### Scenario: Address given
- **WHEN** a desktop build is made with the server address `http://127.0.0.1:8080/` and started
- **THEN** its health call goes to that address

#### Scenario: No address
- **WHEN** a mobile build is made without a server address and started
- **THEN** the app makes no network call to a server and the status bar and Settings → Server show "No server configured"

#### Scenario: Invalid address
- **WHEN** a desktop build is made with the server address `localhost` (no scheme)
- **THEN** the app makes no server call and Settings → Server shows that the configured server address is invalid

### Requirement: The app calls the health endpoint at start and on request
With a server address, the app SHALL call the health endpoint through the generated client when it starts and when the user asks to check again from Settings → Server. A call SHALL be given up after 10 seconds. Only one call SHALL be in flight at a time; a request to check again while one is running SHALL NOT start another.

#### Scenario: Check again
- **WHEN** the user presses "Check again" in Settings → Server after a first answer
- **THEN** one new health call is made and the shown answer is replaced by its result

#### Scenario: Double press
- **WHEN** the user presses "Check again" twice while a call is still running
- **THEN** only one health call is in flight, and the control shows that a check is running

### Requirement: The app shows the health answer
The status bar SHALL show the server's state in short form: connected with all dependencies up, connected with a dependency down, checking, unreachable or not configured. Settings → Server SHALL show the full answer: the server's version and the status of Postgres and of Redis, each up or down.

#### Scenario: Everything up
- **WHEN** the health call returns version `0.1.0`, Postgres `up` and Redis `up`
- **THEN** the status bar shows the server as connected, and Settings → Server shows version 0.1.0, Postgres up and Redis up

#### Scenario: Redis down
- **WHEN** the health call returns Postgres `up` and Redis `down`
- **THEN** the status bar shows the server as connected with a dependency down, and Settings → Server shows Redis down in the theme's error colour, with text as well as colour

### Requirement: An unreachable server is shown without internal detail
When the health call fails (no answer, a network error, a time-out or an unexpected response), the app SHALL show the server as unreachable in the status bar and in Settings → Server, with a "Check again" control. It SHALL NOT show exception text, stack traces, host names or ports from the failure, and the shell SHALL stay usable.

#### Scenario: Server stopped
- **WHEN** the server is stopped and the app starts
- **THEN** within 10 seconds the status bar shows the server as unreachable, the shell's navigation still works, and no exception text is visible

#### Scenario: Server comes back
- **WHEN** the server was unreachable, is started again and the user presses "Check again"
- **THEN** the status bar and Settings → Server show the new answer
