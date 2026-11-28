# org-affiliation Specification

## Purpose

Let an installer declare its organisation tree and let the server read current public corporation and alliance observations independently of account membership and ESI token ownership.

## Requirements

### Requirement: Install organisation tree declaration

The server SHALL read `KANAME_ORG_TREE` at startup. It SHALL accept `corporation:<id>`, `alliance:<id>`, or `coalition:<id>,<id>[,...]` with positive decimal IDs and at least two distinct alliance IDs for a coalition. An unset or empty value SHALL leave the tree unconfigured. An invalid non-empty value SHALL prevent startup and identify the setting.

The Compose `server` service SHALL receive the declaration from the deployment environment.

#### Scenario: Declare each tree type
- **WHEN** an installer supplies a valid corporation, alliance, or coalition declaration
- **THEN** server readers get exactly the declared tree type and its IDs

#### Scenario: Upgrade without a tree
- **WHEN** a server starts with no tree declaration
- **THEN** it starts normally and server readers get an unconfigured tree
- **AND** if the affiliation scheduling prerequisites are met, the startup refresh is scheduled

#### Scenario: Invalid tree declaration
- **WHEN** a declaration has an unknown type, malformed or non-positive ID, wrong number of IDs, or duplicate coalition ID
- **THEN** the server refuses to start and the error names `KANAME_ORG_TREE`

### Requirement: Affiliation sweep registration

The monolith SHALL enqueue startup and hourly sweeps outside test mode when future calls, their execution, and Redis are enabled and a service secret is set. It SHALL repair enqueue failures without restart. Concurrent full sweeps coalesce; first-known calls do not.

Under its ADR 0009 exception, one timer per boot SHALL set cadence and enqueue Serverpod one-shots. Each call runs only its slot. Repair SHALL NOT retry failed ESI lookups. A prior boot's call SHALL NOT replace the startup sweep.

#### Scenario: Startup or hourly enqueue fails
- **WHEN** a startup or hourly enqueue fails and the database later accepts registration
- **THEN** the server queues the missing sweep without restart and queues later hourly sweeps even if the repaired slot's sweep failed

#### Scenario: Registration repair runs as dispatch claims a slot
- **WHEN** a queued sweep reaches dispatch while registration repair checks for it
- **THEN** the same slot starts at most one sweep and a later hourly slot reaches dispatch without restart

#### Scenario: A one-shot claim is abandoned before dispatch
- **WHEN** a current boot's due sweep entry is still present with a stale claim and its callback has not accepted the slot
- **THEN** Serverpod reclaims it, the slot starts one sweep, and a later hourly slot reaches dispatch without restart

#### Scenario: Shutdown begins during registration repair
- **WHEN** shutdown starts while the registrar awaits a presence check that returns a miss
- **THEN** the registrar does not enqueue the missing slot or arm another retry

#### Scenario: Lost acknowledgment leads to duplicate startup calls
- **WHEN** an ambiguous enqueue results in two startup entries for the same boot and Serverpod dispatches them serially
- **THEN** only one entry starts a sweep

#### Scenario: A sweep entry is left from a prior boot
- **WHEN** Serverpod dispatches a prior boot's sweep entry after restart
- **THEN** it starts no sweep and does not replace the current boot's startup sweep

#### Scenario: Hourly sweep dispatch overlaps another sweep
- **WHEN** Serverpod dispatches an hourly sweep while a full sweep is active
- **THEN** the new trigger starts no second sweep and a later hourly trigger remains eligible
- **AND** a first-known lookup can still run when an executor slot is available

#### Scenario: SSO is disabled
- **WHEN** the monolith has usable scheduler configuration but no valid SSO registration
- **THEN** scheduled refreshes still use the shared scheduler to read already known characters

#### Scenario: Scheduler prerequisites are missing
- **WHEN** the monolith starts without enabled Redis or its scheduler service secret
- **THEN** the server remains available, reports the configuration problem, sends no affiliation request, and leaves prior observations unchanged

#### Scenario: Future-call execution is disabled
- **WHEN** future calls or their execution are disabled
- **THEN** affiliation registers neither sweeps nor first-known lookups

#### Scenario: Persisted dispatch has no runtime
- **WHEN** a queued sweep or first-known call survives a restart into a mode or configuration with no active affiliation runtime
- **THEN** the call reports a skip without sending ESI or changing any observation

#### Scenario: Shutdown interrupts a sweep between batches
- **GIVEN** a sweep's first batch is still in flight and more batches remain
- **WHEN** shutdown begins and the first batch finishes
- **THEN** the sweep does not submit another batch, any valid first batch observations remain saved, and the server closes the shared ESI runtime once

### Requirement: Scheduled public character affiliation refresh

The job SHALL cover the verified character registry without filtering by account, blocked state, or token holder. It SHALL set an upper bound at sweep start and visit identities visible as it reads each page. It SHALL submit batches of at most 1,000 distinct IDs to ESI's public `POST /characters/affiliation` through the shared scheduler without an ESI token.

#### Scenario: Sweep the known characters on both triggers
- **GIVEN** the registry contains linked, blocked, unlinked, and device-held characters, and more than one batch of IDs
- **WHEN** the startup or hourly sweep runs
- **THEN** the batches together contain each registered ID exactly once, no outside ID, and no ESI authorization header or token lookup

#### Scenario: An identity commits behind the sweep cursor
- **WHEN** an identity commits after a sweep has passed its position in registry order
- **THEN** the current sweep omits it and the next sweep includes it

#### Scenario: No registered characters
- **WHEN** a sweep finds no registered character
- **THEN** it sends no affiliation request

#### Scenario: Scheduler refuses a batch
- **WHEN** the shared scheduler refuses a request before dispatch
- **THEN** no request for that batch reaches ESI, observations for that batch remain unchanged, and the job does not immediately retry it

#### Scenario: Shared scheduler pauses for downtime
- **WHEN** a sweep or first-known lookup tries to submit an affiliation request during the shared outage pause
- **THEN** the scheduler does not send the affiliation POST or change its observation
- **AND** after a healthy shared recovery probe a later scheduled lookup can refresh the observation

### Requirement: First-known character lookup

When affiliation is enabled, the server SHALL enqueue one public affiliation lookup after a verified sign-in or link first commits the character to the registry. The auth result SHALL NOT wait for ESI. An enqueue or lookup failure SHALL leave the character eligible for the next sweep without changing the auth result or starting an immediate retry.

#### Scenario: A first sign-in or link registers a character
- **WHEN** verified sign-in or linking commits a new identity
- **THEN** a queued job uses the shared scheduler to request just that character, without an ESI token
- **AND** sign-in or linking can complete before ESI replies

#### Scenario: Existing or uncommitted identity
- **WHEN** sign-in or linking uses an identity already in the registry, or the transaction that would create it rolls back
- **THEN** no first-known lookup is enqueued

#### Scenario: One-off work fails
- **WHEN** the post-commit enqueue or the one-off lookup fails
- **THEN** sign-in or linking remains successful and the next sweep includes the character

#### Scenario: An identity commits during shutdown
- **WHEN** sign-in or linking commits a new identity after shutdown starts
- **THEN** the auth result remains successful and no affiliation lookup is enqueued

### Requirement: Last valid affiliation observation

Public ESI affiliation SHALL stay available only to server readers in this change. The server-only model and migration SHALL enforce one observation per identity in PostgreSQL with a unique, cascading foreign key. Store corporation ID, optional alliance ID, observation time, and lookup order. No row means unknown; a null alliance means none. The greater order allocated before submission wins among valid results. Future delivery SHALL use the viewer's privacy scope under ADR 0006.

#### Scenario: Character moves and leaves its alliance
- **GIVEN** a stored observation has a corporation and an alliance
- **WHEN** ESI reports a different corporation and no alliance for the character
- **THEN** a server reader gets the new corporation, a null alliance, and the new observation time

#### Scenario: Reply omits a character
- **WHEN** a valid response covers only some IDs in the request
- **THEN** the job saves the returned observations, leaves omitted characters unchanged, and logs the omission count without character IDs

#### Scenario: Invalid or failed response
- **WHEN** a response cannot be decoded, has duplicate or unrequested IDs or an invalid ID, or the request fails
- **THEN** the job writes no observations for the batch and does not immediately retry it

#### Scenario: Lookup results finish out of order
- **WHEN** two lookups have allocated different orders and the valid result with the smaller order finishes after the valid result with the greater order
- **THEN** server readers get the observation from the lookup with the greater order

#### Scenario: The later lookup fails
- **WHEN** a later-started lookup fails and the earlier lookup returns a valid result
- **THEN** the failed attempt does not prevent the earlier result from being saved

#### Scenario: No observation yet
- **WHEN** a registered character has never had a valid affiliation result
- **THEN** the server reports unknown, not a known character with no alliance

#### Scenario: An identity is removed
- **WHEN** an identity that has an affiliation observation is deleted
- **THEN** the database removes its observation and a server reader reports unknown
