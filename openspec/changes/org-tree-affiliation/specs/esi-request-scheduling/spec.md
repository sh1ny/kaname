# ESI request scheduling delta

## MODIFIED Requirements

### Requirement: Conditional polling and downtime

The scheduler SHALL preserve a caller's matching validator, honor valid Expires with bounded delay and install jitter, and suspend polls while Tranquility is unavailable until a successful recovery probe. It SHALL NOT manufacture a 304 from stored metadata.

Each page or cursor SHALL be scheduled independently. Callers own traversal and cross-page representation consistency.

The public `POST /characters/affiliation`, when marked as scheduled lookup work, SHALL share the outage pause and recovery probes with GET polls. It SHALL NOT create GET validator, freshness, or negative-cache metadata. No other POST is added to the outage policy. A recovery probe SHALL NOT replay the refused request.

Verify the shared affiliation outage and two-route `503` scenarios against both Redis and in-process scheduler state.

#### Scenario: Unchanged page
- **WHEN** a page becomes due and the caller has that page's ETag and representation
- **THEN** the sender includes If-None-Match and returns an upstream 304 as not modified

#### Scenario: Response body is incomplete or malformed
- **WHEN** a poll receives a 2xx response with Expires but cannot read or decode a usable representation
- **THEN** the previously retained representation keeps its original expiry, and valid rate and error headers still reconcile the reservation

#### Scenario: Tranquility is unreachable
- **WHEN** the scheduler observes an outage and subsequent eligible poll requests arrive
- **THEN** ordinary polls are not sent; one shared recovery probe is admitted at each retry opportunity until recovery

#### Scenario: Fresh page and stale worker
- **WHEN** a poll is early for a representation the caller still holds
- **THEN** the scheduler returns not due with a retry deadline, not 304
- **AND** a caller without a local representation can make a normally admitted unconditional request

#### Scenario: Probe fails
- **WHEN** the shared recovery probe fails or reports VIP mode
- **THEN** ordinary polling remains paused until a later successful recovery probe

#### Scenario: ESI reachable but every route answers 503
- **WHEN** two distinct explicitly polled operations return 503 within the outage observation window and the status probe also fails
- **THEN** subsequent ordinary polls are not sent until a recovery probe succeeds

#### Scenario: Affiliation uses the shared outage pause
- **GIVEN** an outage is recorded and its recovery probe is due and otherwise admissible
- **WHEN** a scheduled affiliation POST and a GET poll both receive an atomic refusal while the recovery probe is held open
- **THEN** the scheduler sends exactly one status exchange and no ordinary exchange for the refused requests
- **AND** releasing the healthy probe does not replay either refusal but lets a later scheduled affiliation POST send

#### Scenario: An affiliation connection failure pauses other polls
- **WHEN** an admitted scheduled affiliation POST reports a connectivity failure
- **THEN** the scheduler pauses ordinary polls through the existing shared outage state

#### Scenario: An affiliation 503 contributes to the shared outage
- **WHEN** a scheduled affiliation POST and a distinct GET poll return `503` inside the shared observation window and the status probe fails
- **THEN** subsequent ordinary polls remain paused

#### Scenario: POSTs do not share GET metadata
- **WHEN** the scheduler submits scheduled affiliation batches with different character IDs
- **THEN** one batch's freshness or negative status does not suppress the other through GET metadata
- **AND** an unrelated POST is not marked as subject to the polling outage policy
