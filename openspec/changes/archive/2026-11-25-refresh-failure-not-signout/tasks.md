# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| An inconclusive viewer refresh preserves the last known holder | The holder check survives a failed refresh | `app/test/esi_sso/native_sso_test.dart` | `An inconclusive Take refresh keeps the desktop holder check` (reply variants); `An inconclusive Return refresh keeps the desktop holder check`; `A handoff 401 does not report sign-out without viewer confirmation` | green |
| An inconclusive viewer refresh preserves the last known holder | A confirmed viewer update replaces the holder view | `app/test/esi_sso/native_sso_test.dart` | `A verified refresh replaces the retained holder view` | green |
| An inconclusive viewer refresh preserves the last known holder | A confirmed invalid session ends the connected view | `app/test/esi_sso/native_sso_test.dart` | `A confirmed invalid viewer session signs out` | green |
| An inconclusive viewer refresh preserves the last known holder | A temporary lookup error is not session invalidation | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | `A viewer lookup failure is unavailable, not sign-out` | green |
| An inconclusive viewer refresh preserves the last known holder | Sign-out wins over an in-flight refresh | `app/test/esi_sso/native_sso_test.dart` | `A late viewer reply cannot restore a signed-out session` | green |

## 1. Preserve the last known holder

- [x] 1.1 Add the regressions before changing production code. Extend the existing native test fixtures with scripted viewer replies and a positive variant that records native authorization without opening a browser. Exercise Take and Return, the response classes and the late-reply barrier listed in the design, and scoped completion's handling of an inconclusive viewer read. Prove that a missing reply keeps the viewer and that a desktop without a reservation cannot start authorization. Prove that a verified replacement without a holder permits an otherwise eligible desktop to start. In the server integration test, inject the lookup fault through the `SsoSessions` clock callback and check fixed 503, successful recovery with the same bearer, and fixed 401 after invalidation. Run `native_sso_test.dart` and the new named `connected_sso_test.dart` test before editing production. Record the failures for the behaviors that change and the baseline for the already-correct late-reply guard. Do not include credentials, reply details or fault text in assertion failures.
- [x] 1.2 Implement the three-way refresh result, migrate all refresh callers and keep the existing desktop holder check and epoch guards. On the server, use the error-propagating lookup only for the viewer route; validate the bearer shape before doing any lookup and preserve the guard for other callers. Do not edit `native_account.dart`. Carry C1 in the delta spec and document C2 and C3 at their Dart interfaces. Rerun `native_sso_test.dart`, `skills_refusal_test.dart`, and the `connected_sso_test.dart` cases for viewer lookup failure and connected sign-in. Verify with scoped static analysis. Mark the test map green only after the corresponding tests pass.

## Workflow follow-up

- Run Claude pre-ship review, ship the PR with `Fixes #41`, and watch CI and review feedback.
- Archive the change and sync the spec on the PR branch before reporting readiness. The owner merges.
