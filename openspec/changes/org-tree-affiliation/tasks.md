# Tasks

## Test map

| Alias | Test file |
|---|---|
| `tree` | `server/kaname_server/test/unit/affiliation/org_tree_config_test.dart` |
| `registrar` | `server/kaname_server/test/unit/affiliation/sweep_registrar_test.dart` |
| `runtime` | `server/kaname_server/test/integration/affiliation/affiliation_runtime_test.dart` |
| `refresh` | `server/kaname_server/test/integration/affiliation/affiliation_refresh_test.dart` |
| `identity` | `server/kaname_server/test/integration/affiliation/affiliation_identity_hook_test.dart` |
| `scheduler` | `packages/kaname_esi_scheduler/test/scheduler_conformance_test.dart` |
| `Redis` | `server/kaname_server/test/integration/esi/redis_scheduler_test.dart`, which also runs the shared `scheduler` cases |

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| Install organisation tree declaration | Declare each tree type | `tree` | parses all three tree declarations without mixing ID kinds | red |
| Install organisation tree declaration | Upgrade without a tree | `runtime` | starts unconfigured and queues the startup sweep | red |
| Install organisation tree declaration | Invalid tree declaration | `tree`, `runtime` | rejects invalid declarations and names the setting; invalid tree fails before the API listener | red |
| Affiliation sweep registration | Startup or hourly enqueue fails | `registrar` | repairs failed startup and hourly enqueues without replaying sweeps | red |
| Affiliation sweep registration | Registration repair runs as dispatch claims a slot | `registrar` | a dispatch during the presence check does not requeue that slot | red |
| Affiliation sweep registration | A one-shot claim is abandoned before dispatch | `runtime` | Serverpod reclaims the abandoned slot and dispatches the next hour | red |
| Affiliation sweep registration | Shutdown begins during registration repair | `registrar` | a presence miss arriving after stop cannot enqueue or rearm | red |
| Affiliation sweep registration | Lost acknowledgment leads to duplicate startup calls | `registrar` | serial duplicate startup dispatches start only one sweep | red |
| Affiliation sweep registration | A sweep entry is left from a prior boot | `registrar` | an old boot cannot satisfy this boot's startup slot | red |
| Affiliation sweep registration | Hourly sweep dispatch overlaps another sweep | `runtime` | coalesces a full sweep but permits first-known and the following hour | red |
| Affiliation sweep registration | SSO is disabled | `runtime` | refreshes known identities without a valid SSO registration | red |
| Affiliation sweep registration | Scheduler prerequisites are missing | `runtime` | missing Redis configuration or service secret does not stop the server | red |
| Affiliation sweep registration | Future-call execution is disabled | `runtime` | disabled future calls or execution registers no affiliation work | red |
| Affiliation sweep registration | Persisted dispatch has no runtime | `runtime` | persisted sweep and first-known calls skip with no active runtime | red |
| Affiliation sweep registration | Shutdown interrupts a sweep between batches | `runtime` | shutdown saves the active batch and closes the runtime without another send | red |
| Scheduled public character affiliation refresh | Sweep the known characters on both triggers | `runtime` | startup and hourly calls send bounded anonymous batches for the whole registry | red |
| Scheduled public character affiliation refresh | An identity commits behind the sweep cursor | `refresh` | the next sweep sees an identity that committed behind the cursor | red |
| Scheduled public character affiliation refresh | No registered characters | `refresh` | an empty registry sends no affiliation request | red |
| Scheduled public character affiliation refresh | Scheduler refuses a batch | `refresh` | a scheduler refusal leaves the batch unchanged without a retry | red |
| Scheduled public character affiliation refresh | Shared scheduler pauses for downtime | `runtime` | paused affiliation preserves the observation until a later scheduled call | red |
| First-known character lookup | A first sign-in or link registers a character | `identity` | first sign-in and link commit before the one-off; auth does not wait for ESI | red |
| First-known character lookup | Existing or uncommitted identity | `identity` | known or rolled-back identities cannot enqueue a one-off | red |
| First-known character lookup | One-off work fails | `identity` | failed enqueue or lookup leaves auth successful and the next sweep covers the identity | red |
| First-known character lookup | An identity commits during shutdown | `identity` | a successful identity commit during shutdown cannot enqueue | red |
| Last valid affiliation observation | Character moves and leaves its alliance | `refresh` | replaces the corporation and clears the alliance on a valid move | red |
| Last valid affiliation observation | Reply omits a character | `refresh` | saves valid returned rows and preserves omitted observations | red |
| Last valid affiliation observation | Invalid or failed response | `refresh` | malformed, duplicate, foreign or invalid responses change no observation | red |
| Last valid affiliation observation | Lookup results finish out of order | `refresh` | a lower-order valid result cannot replace the higher-order row | red |
| Last valid affiliation observation | The later lookup fails | `refresh` | a failed higher-order lookup does not block an earlier valid result | red |
| Last valid affiliation observation | No observation yet | `refresh` | an unknown character is distinct from one with no alliance | red |
| Last valid affiliation observation | An identity is removed | `refresh` | deleting an identity removes its unique observation | red |
| Conditional polling and downtime | Unchanged page | `scheduler` | forwards retained page validator and wire 304 | green |
| Conditional polling and downtime | Response body is incomplete or malformed | `scheduler` | incomplete body does not mark a retained poll fresh; malformed body does not mark a retained poll fresh | green |
| Conditional polling and downtime | Tranquility is unreachable | `scheduler`, `Redis` | grants one shared status probe per retry opportunity | green |
| Conditional polling and downtime | Fresh page and stale worker | `scheduler`, `Redis` | distinguishes not due from no local representation | green |
| Conditional polling and downtime | Probe fails | `scheduler`, `Redis` | does not resume for a failed probe; decoded VIP status does not resume polling (in-process) | green |
| Conditional polling and downtime | ESI reachable but every route answers 503 | `scheduler`, `Redis` | repeated failures refresh the outage window for distinct routes | green |
| Conditional polling and downtime | Affiliation uses the shared outage pause | `scheduler`, `Redis` | a GET and affiliation share one probe without replaying refused calls | red |
| Conditional polling and downtime | An affiliation connection failure pauses other polls | `scheduler`, `Redis` | affiliation connectivity failure pauses GET polling | red |
| Conditional polling and downtime | An affiliation 503 contributes to the shared outage | `scheduler`, `Redis` | affiliation and GET 503s share the outage signal | red |
| Conditional polling and downtime | POSTs do not share GET metadata | `scheduler`, `Redis` | affiliation posts share neither GET metadata nor outage behavior with unrelated posts | red |

## 1. Verify the pinned future-call manager

- [ ] 1.1 Verify A1 against the installed Serverpod 4.1.2 scanner, claim transaction, recurring successor insertion, execution flags and shutdown path. Add a focused PostgreSQL test using an existing one-shot callback and an already stale claim; drive dispatch via the executor and assert it runs once. Verify the test before relying on the selected adapter. Task 4.3 checks the same claim path with the actual affiliation timer, injected registrar time and next-hour dispatch.

## 2. Extend shared outage admission for affiliation

- [ ] 2.1 Write the four new scheduler scenarios red first. Use the same generated-client scenarios in Redis and in-process tests, hold the probe open until both admissions refuse, and inject time for the two-route `503` window. Confirm the failures are due to missing POST outage admission or observation, not fixture timing.
- [ ] 2.2 Implement D7 and C6 in the scheduler, in-process state and Redis state. Keep GET validators, freshness and negative caching unchanged; keep existing GET metadata compatible in persisted admission state. Re-run the two conformance files, including the unchanged rows, and mark the new tests green.

## 3. Store and refresh affiliation observations

- [ ] 3.1 Write the `refresh` tests before adding the job and store. Exercise PostgreSQL for ordering, migration constraints, cursor visibility and alliance clearing. Use deterministic upstream replies and a barrier for out-of-order lookups. Add a restored-sequence fixture that starts with a high stored order and a matching sequence position, and assert a new valid result advances it.
- [ ] 3.2 Add the server-only model and migration, then the pure-Dart job, bounded registry queries, typed observation read and order-checked upsert. Carry C2, C4, C5, and C9 into the spec and implementation. Verify no client model is generated, the unique identity foreign key cascades, the additive migration preserves known identities, and the `refresh` tests pass. Mark the covered tests green.

## 4. Configure and run affiliation on the server

- [ ] 4.1 Write `tree`, `registrar`, `runtime` and `identity` tests for the remaining red scenarios. Before production edits, run the tests and confirm they expose missing behavior. Drive hourly slots with an injected clock and wait for dispatch, commit, admission or response events rather than sleeping.
- [ ] 4.2 Implement the tree parser, server-only reader and Compose mapping (C1, C8). Update `deploy/.env.example` and `deploy/README.md` with the accepted forms, empty behavior and refresh cadence. Verify the tree tests and `docker compose config` with synthetic environment values, checking the declaration reaches the `server` service.
- [ ] 4.3 Implement the per-pod registrar and one-shot full-sweep adapter (C7), the shared ESI runtime binding and pre-drain shutdown. Generate the Serverpod dispatch. Verify the registrar and runtime tests, including A1's abandoned current-boot claim test: observe at most one sweep for the recovered slot and a subsequent hourly dispatch without restart. Verify startup and hourly scans hit the shared scheduler, not a direct sender.
- [ ] 4.4 Enqueue the first-known call only after the sign-in or link transaction that inserted the identity commits (C3). Skip it during shutdown. Run the identity tests, relevant existing connected SSO and member-account tests, and strict OpenSpec validation. Mark the remaining tested rows green.

## Workflow follow-up

- Run the pre-ship review at the completed code head. Ship and watch without merging.
- Get owner archive approval, archive on the pull request branch and verify the archive head. The owner merges.
