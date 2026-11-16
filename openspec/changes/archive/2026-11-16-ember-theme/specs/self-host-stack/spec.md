# Spec Delta

## ADDED Requirements

### Requirement: The fallback-font path never serves the web app
Caddy SHALL answer every request under the web app's fallback-font path with 404 Not Found and an empty or plain-text body, never with the app's `index.html`, so the web engine's fallback-font requests fail fast on the app's own origin.

#### Scenario: Fallback font requested
- **WHEN** a request is sent to a file under the fallback-font path, for example `http://localhost/<fallback path>/roboto/v1/x.woff2`
- **THEN** Caddy answers 404, and the body is not the web app's `index.html`

#### Scenario: Ordinary app route still falls back
- **WHEN** a request is sent to an app route such as `http://localhost/settings` that has no file in the web build
- **THEN** Caddy serves the web app's `index.html` as before
