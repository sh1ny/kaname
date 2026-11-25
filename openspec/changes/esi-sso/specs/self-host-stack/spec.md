## ADDED Requirements

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
