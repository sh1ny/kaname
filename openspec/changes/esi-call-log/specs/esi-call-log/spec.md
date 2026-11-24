# ESI call log

## Purpose

Provides recent ESI diagnostics without retaining credentials or delivering other members’ individual call histories.

## ADDED Requirements

### Requirement: Secret-free scheduler history

The call log SHALL record terminal scheduler outcomes with a timestamp, catalogue operation, outcome, HTTP status when known, cost, elapsed latency and catalogue bucket when applicable. It SHALL distinguish intentional not-sent refusals from errors. It SHALL NOT persist tokens, request targets, parameters, headers, bodies, raw exceptions or arbitrary upstream strings.

#### Scenario: Upstream response
- **WHEN** a scheduled ESI exchange receives a successful response with valid cost metadata
- **THEN** one row records the catalogue operation and bucket, observed cost, status and latency

#### Scenario: Refusal and failure
- **WHEN** one request is refused before dispatch and another exchange fails after dispatch
- **THEN** the refusal is recorded as not sent with zero cost and the exchange failure is recorded as an error

#### Scenario: Unknown operation
- **WHEN** the requested operation is not in the catalogue
- **THEN** the scheduler refuses it and writes no row

#### Scenario: Secret-bearing inputs
- **WHEN** credentials, request arguments, response headers or bodies, or a thrown exception contain secret markers
- **THEN** no marker appears in any persisted column

#### Scenario: Unusable success response
- **WHEN** generated decoding fails on an HTTP 2xx response for either a poll or a non-poll call
- **THEN** the log records an error with the received HTTP status

#### Scenario: Log write cannot complete
- **WHEN** storage rejects a write or the logging capacity is exhausted
- **THEN** the caller receives its original ESI outcome, the request is not replayed, and a fixed diagnostic is reported

### Requirement: Seven-day retention

Reads SHALL omit rows at least seven days old. Storage SHALL remove expired rows through routine pruning.

#### Scenario: Retention boundary
- **WHEN** the clock reaches exactly seven days after a row was recorded
- **THEN** reads omit the row and the next successful prune deletes it, while the younger row remains visible and is not deleted

#### Scenario: Pruning resumes after interruption
- **WHEN** the next successful prune runs after the server misses a scheduled prune
- **THEN** it removes rows already expired, including those that expired during the interruption

### Requirement: Privacy-scoped call-log reads

Individual reads SHALL return only the trusted viewer’s calls for currently owned characters, including for admins. Remote reads require genuine viewer identity, never a shared key. Admins SHALL receive only route totals and error counts (excluding refusals from errors), without period or subgroup filters. Private routes require at least five distinct trusted members, configurable upward. Counts cover five complete UTC days and update one minute after UTC midnight.

#### Scenario: Own rows only
- **WHEN** a viewer reads a log containing own, other and unattributed rows
- **THEN** only the viewer’s own rows are returned, even when the viewer is an admin

#### Scenario: No trusted viewer or admin grant
- **WHEN** a read lacks a trusted viewer, or a non-admin requests route aggregates
- **THEN** access is denied without returning call-log data

#### Scenario: Sufficient and insufficient contributors
- **WHEN** an admin requests route totals and one route meets the contributor threshold while another falls below it
- **THEN** only the qualifying route is returned with its total and error count, with no per-character fields and no refusal counted as an error

#### Scenario: Character ownership changes
- **WHEN** a new member acquires a character for which a previous member has call-log rows
- **THEN** the previous member’s rows do not appear in the new member’s history

#### Scenario: Several alts of one member
- **WHEN** five characters from the same member are the only contributors to a private route
- **THEN** the route is suppressed under a threshold of five members

#### Scenario: Stable closed periods
- **WHEN** an admin reads counts on either side of a late, pre-midnight insert completing during the one-minute grace
- **THEN** the released counts stay unchanged through the grace, and at release only the next complete window is returned

#### Scenario: Public probe
- **WHEN** the only observation for a public route is a status probe in a closed day
- **THEN** the route counts include the observation without applying the private contributor threshold

#### Scenario: Unattributed authenticated call
- **WHEN** an authenticated call is recorded without a trusted member association
- **THEN** it is excluded from individual reads and from private route counts and threshold qualification

#### Scenario: Write misses its deadline
- **WHEN** a receipt stamped before midnight reaches the database after its ten-second deadline
- **THEN** no row is stored, a fixed diagnostic is reported, and the released counts do not change

#### Scenario: Slow commit spans release
- **WHEN** a pre-midnight append passed its deadline check but remains uncommitted when an admin reads counts after release
- **THEN** the read includes that row or fails unavailable, and later reads do not vary totals for that window
