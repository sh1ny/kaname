# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| esi-sso → The desktop restores local state after a definitively refused take | A definitive refusal restores the desktop state | `app/test/esi_sso/native_sso_test.dart` | `A definitive refusal restores the desktop state`; `A definitive refusal removes only the temporary character`; `A refused take leaves the connected holder gate in place` | green |
| esi-sso → The desktop restores local state after a definitively refused take | An uncertain take keeps the original proof | `app/test/esi_sso/native_sso_test.dart` | `An uncertain take keeps the original proof` | green |

## 1. Restore a refused take without losing a pending proof

- [x] 1.1 Write the native regressions first, using the connected HTTP adapter, a temporary SQLite store and an offline keyring. Run `native_sso_test.dart` before editing production code. Confirm the refusal tests fail because the old journal is not restored, and record the baseline result for the uncertain-take safety cases. Cover a missing or existing row, restoring the selection, no repeated take on Return, and the live connected holder check. Exercise lost and unreadable responses, a 403 without the fixed refusal body, and a refused retry after reopening the store. Compare proof identity without putting proof values in test output.
- [x] 1.2 Implement the typed take outcome and the atomic restore for a confirmed refusal of a fresh intent. Keep the journal and proof for every uncertain or resumed take; delete only the rejected proof after committing a restore. Keep the holder checks and HTTP contract unchanged. Carry C1 in the delta spec and document C2 and C3 at their Dart interfaces. Run `native_sso_test.dart` and the existing `skills_refusal_test.dart` caller coverage. Verify the touched Dart files with scoped static analysis and turn both map rows green.

## Workflow follow-up

- Run Claude pre-ship review, ship the PR with `Fixes #39`, and watch CI and review feedback.
- Archive and sync the spec on the PR branch before reporting readiness. The owner merges.
