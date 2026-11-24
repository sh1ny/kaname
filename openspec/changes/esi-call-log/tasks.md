# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| Secret-free scheduler history | Upstream response | `packages/kaname_esi_scheduler/test/call_log_test.dart` | captures status cost and elapsed latency | green |
| Secret-free scheduler history | Refusal and failure | `packages/kaname_esi_scheduler/test/call_log_test.dart` | refusals and failures retain distinct outcomes | green |
| Secret-free scheduler history | Unknown operation | `packages/kaname_esi_scheduler/test/call_log_test.dart` | unknown route never reaches sink | green |
| Secret-free scheduler history | Secret-bearing inputs | `server/kaname_server/test/integration/esi_call_log_test.dart` | no supplied secret reaches any stored column | red |
| Secret-free scheduler history | Unusable success response | `packages/kaname_esi_scheduler/test/call_log_test.dart` | poll and non-poll decode failures retain HTTP status | green |
| Secret-free scheduler history | Log write cannot complete | `packages/kaname_esi_scheduler/test/call_log_test.dart` | write failure and capacity never change or replay the exchange | green |
| Seven-day retention | Retention boundary | `server/kaname_server/test/integration/esi_call_log_test.dart` | exact cutoff filters and deletes only expired rows | red |
| Seven-day retention | Pruning resumes after interruption | `server/kaname_server/test/integration/esi_call_log_test.dart` | next sweep catches up using its current clock | red |
| Privacy-scoped call-log reads | Own rows only | `server/kaname_server/test/integration/esi_call_log_test.dart` | admins and members see only their own rows | red |
| Privacy-scoped call-log reads | No trusted viewer or admin grant | `server/kaname_server/test/integration/esi_call_log_test.dart` | missing viewer and member aggregate access denied | red |
| Privacy-scoped call-log reads | Sufficient and insufficient contributors | `server/kaname_server/test/integration/esi_call_log_test.dart` | private counts require enough members and exclude refusals from errors | red |
| Privacy-scoped call-log reads | Character ownership changes | `server/kaname_server/test/integration/esi_call_log_test.dart` | transfer does not expose prior member rows | red |
| Privacy-scoped call-log reads | Several alts of one member | `server/kaname_server/test/integration/esi_call_log_test.dart` | alts contribute one member | red |
| Privacy-scoped call-log reads | Stable closed periods | `server/kaname_server/test/integration/esi_call_log_test.dart` | late write cannot change released totals during grace | red |
| Privacy-scoped call-log reads | Public probe | `server/kaname_server/test/integration/esi_call_log_test.dart` | public probe aggregate does not require member attribution | red |
| Privacy-scoped call-log reads | Unattributed authenticated call | `server/kaname_server/test/integration/esi_call_log_test.dart` | no trusted member excludes a private row | red |
| Privacy-scoped call-log reads | Write misses its deadline | `server/kaname_server/test/integration/esi_call_log_test.dart` | expired append cannot alter released counts | red |
| Privacy-scoped call-log reads | Slow commit spans release | `server/kaname_server/test/integration/esi_call_log_test.dart` | uncommitted admitted append blocks or joins release | red |

## 1. Scheduler receipts

- [x] 1.1 Write and run the failing scheduler tests in the test map; confirm each fails for missing behavior, using controlled send/decode and writer-completion events.
- [x] 1.2 Implement allowlisted terminal receipts, shared runtime sink composition and bounded failure reporting; run `call_log_test.dart` and turn its rows green. Verify C1 against the delta and carry C8 in the sink contract.

## 2. Persistence and privacy

- [ ] 2.1 Write and run the failing integration tests in the map, using an injected UTC clock and completion barriers, not sleeps. Add a server architecture guard (ADR 0006) reporting any production reference to the call-log model class or its table class, and any string literal naming the call-log table, outside the call-log store and scoped reader files and `src/generated/`, with positive and negative source samples as `tools/kaname_tools/test/esi_boundary_test.dart:10-26` does.
- [ ] 2.2 Add the server-only model and migration, production writer and prune scheduling, and scoped readers. Run `esi_call_log_test.dart` and the architecture guard; turn the integration rows green, verify C2–C6 against the delta, carry C7 in the runtime documentation, and document the operator-visible retention, failure and access rules.

## Workflow follow-up

- Run Claude pre-ship review, ship and watch CI and review feedback, archive on this branch with the specs synced, then watch the archive head. Owner merges.
