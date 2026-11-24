## Test map

Test paths below are relative to the workspace. `shared` = `packages/kaname_esi_scheduler/test/scheduler_conformance_test.dart` and the same conformance suite invoked by `server/kaname_server/test/integration/esi/redis_scheduler_test.dart` with real Redis; `redis` refers to that integration file alone. `client` = `packages/kaname_esi/test/contract_test.dart`.

| Requirement | Scenario | File | Named test | State |
|---|---|---|---|---|
| Shared atomic admission | Last tokens under contention | shared; redis | admits exactly one last reservation; admits exactly one last reservation across server isolates | green |
| Shared atomic admission | State unavailable | redis | refuses when Redis cannot confirm | green |
| Shared atomic admission | Redis was replaced or restarted | redis | quarantines stale state from a prior incarnation | green |
| Shared atomic admission | Product transport bypass | `tools/kaname_tools/test/esi_boundary_test.dart` | reports direct production ESI access | green |
| Shared atomic admission | Delivery is uncertain | shared | never replays an ambiguous send | green |
| Response reconciliation | Response changes available capacity | shared | charges outstanding work against observed remaining | green |
| Response reconciliation | Retry and reset | shared | distinguishes group cooldown from connection reset | green |
| Response reconciliation | Older observation arrives late | shared | settles late response without replacing ceiling | green |
| Governor tiers and priorities | Increasing pressure | shared | applies all four tiers at exact thresholds | green |
| Governor tiers and priorities | Waiting requests contend | shared | chooses highest eligible live waiter before FIFO peers | green |
| Governor tiers and priorities | Queue is full of backfill | shared | displaces newest lowest-priority waiter | green |
| Governor tiers and priorities | Capacity stays occupied | shared | expires a lease and never sends an expired ticket | green |
| Shared negative result suppression | Another isolate repeats a denied read | shared; redis | shares suppressed 403 and 404 without sending; shares negative cache across server isolates | green |
| Shared negative result suppression | Suppression does not cross identities | shared | isolates authorization and expires at logical deadline | green |
| Conditional polling and downtime | Unchanged page | shared | forwards retained page validator and wire 304 | green |
| Conditional polling and downtime | Tranquility is unreachable | shared | grants one shared status probe per retry opportunity | green |
| Conditional polling and downtime | Fresh page and stale worker | shared | distinguishes not due from no local representation | green |
| Conditional polling and downtime | Probe fails | shared | does not resume for failed or VIP probe | green |
| Conditional polling and downtime | ESI reachable but every route answers 503 | shared | pauses only after distinct poll routes fail within window | green |
| Equivalent corporation polls | Two qualified holders poll the same corporation page | shared | deduplicates corp representation across holders | green |
| Equivalent corporation polls | Poller fails before releasing its claim | shared | reclaims expired corp lease | green |
| Typed results, never thrown | Success | `packages/kaname_esi/test/result_test.dart` | Success: 200 with ETag, Expires, Last-Modified and X-Pages 3 | green |
| Typed results, never thrown | No content | `packages/kaname_esi/test/result_test.dart` | No content: 204 is a success without a body | green |
| Typed results, never thrown | Not modified | `packages/kaname_esi/test/result_test.dart` | Not modified: 304 carries ETag and Expires | green |
| Typed results, never thrown | ESI error with body | `packages/kaname_esi/test/result_test.dart` | ESI error with body: 404 with an error message | green |
| Typed results, never thrown | ESI error without a readable body | `packages/kaname_esi/test/result_test.dart` | ESI error without a readable body: 502 with a non-JSON body | green |
| Typed results, never thrown | Scheduler refuses before dispatch | client | decodes scheduler refusal without wire status | green |
| Typed results, never thrown | Negative suppression is not a wire result | client | preserves suppressed status separately | green |

## 1. Record the boundary and extend the typed client

- [x] 1.1 Check A1 against Compose and SSO ownership in the ADRs; write ADR 0016 (C4, C8) and update the architecture index and scheduler ownership row. Verify cited deployment has one ESI egress assumption, with no new process.
- [x] 1.2 Add refusal contract tests red first; add stable reasons, typed transport/result cases and exhaustive decoding (C7). Verify new and unchanged client cases; no change to the pinned catalogue or generated operations.

## 2. Implement scheduling and solo state

- [x] 2.1 Add the pure-Dart workspace module and shared conformance fixture; test atomic admission, uncertain delivery, reconciliation, tiers and priority red first. Implement the synchronous state transition and bound scheduled transport; verify the solo conformance cases and the no-replay invariant C6.
- [x] 2.2 Test shared negative metadata, freshness/304, outages and corp leases red first; implement them in the scoped transitions. Verify fake-time conformance including FIFO, dead heads, expiry, capped cache, page isolation and corp ownership (C2, C3, C5, C9).

## 3. Wire server and native transports

- [x] 3.1 Add real Redis conformance red first; implement atomic scripts, bounded isolate-owned connections and restart quarantine. Verify the suite with independent server isolates, readiness barriers and injected time, without a wall-clock timing assertion. Refresh notices when dependency resolution changes.
- [x] 3.2 Add the private native HTTP adapter and wire server and reusable solo factories; prove through generated calls with a loopback fixture that the scheduler alone sends (C1), with install User-Agent, pinned compatibility date, bounded response, no redirects or replay. Add architecture guard with an intentional bypass fixture and document composition.

## 4. Verify integrated behavior

- [x] 4.1 Run strict OpenSpec validation, package contract checks and the server Redis integration check. Run the gaming guard before heavy work; when gaming, obtain the heavy suite results from CI instead of running locally.
