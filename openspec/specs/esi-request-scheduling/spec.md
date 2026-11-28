# esi-request-scheduling Specification

## Purpose

Coordinates outbound ESI calls so server isolates and native solo protect upstream limits and avoid redundant polling.

## Requirements

### Requirement: Shared atomic admission

Every production ESI operation SHALL go through the scheduler. Before sending, it SHALL atomically reserve cost against the applicable route-group and connection error budgets in shared server state or the native solo store.

#### Scenario: Last tokens under contention
- **WHEN** concurrent callers contend for capacity sufficient for one reservation
- **THEN** exactly one reaches the sender in both separate server isolates and concurrent solo calls

#### Scenario: State unavailable
- **WHEN** shared server state cannot confirm a reservation
- **THEN** the scheduler refuses without sending or using a local fallback

#### Scenario: Redis was replaced or restarted
- **WHEN** a server has no scheduler state or detects a new Redis incarnation
- **THEN** it allows an otherwise eligible first request immediately and admits at most one in-flight request per recovering rate-limit bucket across isolates
- **AND** another request for that recovering bucket is refused immediately with `stateRecovering` and the in-flight request's lease deadline, without queueing
- **AND** it resumes normal admission for that bucket only after a response supplies valid `X-Ratelimit-*` headers for the bucket; missing or invalid headers leave that bucket in single-request mode
- **AND** connection error limits, 420 and 429 cooldowns, and the normal reservation rules still take precedence; old-incarnation completions and tickets cannot settle, grant, warm or reset new state even if reservation IDs are reused

#### Scenario: First server skills read on a fresh stack
- **WHEN** the viewer holds a valid skills grant and requests the first `char-detail` call on a fresh server stack
- **THEN** the otherwise eligible request is sent immediately without a Redis recovery pause

#### Scenario: Product transport bypass
- **WHEN** a production module adds a raw ESI sender or instantiates the generated client outside the scheduler composition
- **THEN** the architecture check fails and identifies the offending module

#### Scenario: Delivery is uncertain
- **WHEN** an admitted request times out after dispatch
- **THEN** the scheduler returns a transport failure and does not replay the operation

### Requirement: Response reconciliation

The scheduler SHALL reconcile reservations with valid ESI group and connection error headers. Late replies SHALL NOT overwrite newer constraints or release another call's reservation.

#### Scenario: Response changes available capacity
- **WHEN** ESI reports lower remaining capacity than the local estimate
- **THEN** subsequent admission uses the lower value, including outstanding reservations

#### Scenario: Retry and reset
- **WHEN** ESI returns 429 or 420
- **THEN** the scheduler blocks the applicable bucket or connection respectively until the reported retry or reset deadline, or a conservative fallback when it is absent

#### Scenario: Older observation arrives late
- **WHEN** an earlier admission's response arrives after a newer admission has set the remaining ceiling
- **THEN** it settles only its own debit without replacing the newer ceiling

#### Scenario: Response arrives at the caller lease boundary
- **WHEN** an admitted call reports 420, 429, 403, or 404 as its live lease expires or during the short completion grace period
- **THEN** the scheduler records the corresponding cooldown or negative observation without occupying a live slot or releasing another call's claim

### Requirement: Governor tiers and priorities

The scheduler SHALL select full, spaced, single or stopped based on bucket and error-budget pressure. When requests contend for an admission opportunity, interactive SHALL precede realtime, notifications, sync and backfill, in that order, with FIFO within a priority.

#### Scenario: Increasing pressure
- **WHEN** test inputs cross each pressure threshold
- **THEN** admission changes from normal bounded concurrency to paced dispatch, then one concurrent request, then no requests

#### Scenario: Waiting requests contend
- **WHEN** capacity becomes available with multiple priority classes waiting
- **THEN** the highest eligible priority is dispatched first without preempting any sent request

#### Scenario: Queue is full of backfill
- **WHEN** an interactive request arrives at a queue cap filled with backfill requests
- **THEN** the newest backfill ticket is refused and the interactive ticket can wait

#### Scenario: Capacity stays occupied
- **WHEN** an admitted queue ticket reaches its wait deadline without permission to send
- **THEN** it returns a not-sent wait-expired result and cannot later dispatch

### Requirement: Shared negative result suppression

The scheduler SHALL suppress repeat reads after a 403 or 404 for a bounded period, scoped to the same authorization and request representation. It SHALL NOT return cached failures as fresh upstream responses.

#### Scenario: Another isolate repeats a denied read
- **WHEN** a second isolate requests the same representation with the same authorization during suppression
- **THEN** it gets a not-sent result without a wire request

#### Scenario: Suppression does not cross identities
- **WHEN** authorization changes or the suppression expires
- **THEN** that suppression no longer prevents the request

### Requirement: Conditional polling and downtime

The scheduler SHALL preserve a caller's matching validator, honor valid Expires with bounded delay and install jitter, and suspend polls while Tranquility is unavailable until a successful recovery probe. It SHALL NOT manufacture a 304 from stored metadata.

Each page or cursor SHALL be scheduled independently. Callers own traversal and cross-page representation consistency.

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

### Requirement: Affiliation outage polling

The public `POST /characters/affiliation`, when marked as scheduled lookup work, SHALL share the outage pause and recovery probes with GET polls. It SHALL NOT create GET validator, freshness, or negative-cache metadata. No other POST is added to the outage policy. A recovery probe SHALL NOT replay the refused request.

Verify the shared affiliation outage and two-route `503` scenarios against both Redis and in-process scheduler state.

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

### Requirement: Equivalent corporation polls

Corporation recipes SHALL keep their shared representation independent of the selected role holder's identity.
The scheduler SHALL admit at most one concurrent equivalent poll for a corporation representation across its server isolates, using the qualified character supplied by the caller.

#### Scenario: Two qualified holders poll the same corporation page
- **WHEN** concurrent callers choose different qualified characters for an equivalent corporation poll
- **THEN** only one reaches ESI and spends that character's budget

#### Scenario: Poller fails before releasing its claim
- **WHEN** the first poller dies
- **THEN** a later poll can acquire the claim after its bounded lifetime without receiving the first poller's data
