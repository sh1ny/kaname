## MODIFIED Requirements

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
