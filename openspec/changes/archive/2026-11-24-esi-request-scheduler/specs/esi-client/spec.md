## MODIFIED Requirements

### Requirement: Typed results, never thrown
Each call SHALL return one result of a closed set: success, not modified, ESI error, malformed response, invalid request, transport failure or scheduler refusal. The client SHALL NOT throw for any HTTP status or response body.

Stable refusal reasons SHALL be `budget`, `stopped`, `queueFull`, `waitExpired`, `negativeCached`, `notDue`, `outage`, `stateUnavailable`, `corpBusy`, `scopeCapacity`, `routeConflict`, `invalidContext` and `stateRecovering`.

#### Scenario: Success
- **WHEN** the transport answers 200 with a body that matches the operation's schema and headers `ETag`, `Expires`, `Last-Modified` and `X-Pages: 3`
- **THEN** the result is a success holding the typed body, the status, those header values and a page count of 3

#### Scenario: No content
- **WHEN** an operation whose spec answers 204 gets a 204
- **THEN** the result is a success with no body

#### Scenario: Not modified
- **WHEN** the transport answers 304
- **THEN** the result is not modified, carrying the response's `ETag` and `Expires` when present

#### Scenario: ESI error with body
- **WHEN** the transport answers 404 with `{"error":"Character not found"}`
- **THEN** the result is an ESI error with status 404 and the message `Character not found`

#### Scenario: ESI error without a readable body
- **WHEN** the transport answers 502 with a body that is not JSON
- **THEN** the result is an ESI error with status 502 and no parsed message

#### Scenario: Scheduler refuses before dispatch
- **WHEN** the transport reports that scheduler policy refused to send a call
- **THEN** the client returns a distinct not-sent result with a stable reason and any supplied retry deadline, without an HTTP status

#### Scenario: Negative suppression is not a wire result
- **WHEN** the transport refuses with `negativeCached`
- **THEN** the not-sent result carries the suppressed 403 or 404 separately and has no wire HTTP status
