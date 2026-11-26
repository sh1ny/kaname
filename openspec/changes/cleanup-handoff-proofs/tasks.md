# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| esi-sso → The desktop removes unreferenced handoff proofs safely | A finished transition leaves an unused proof | `app/test/esi_sso/native_sso_test.dart` | `Reopen removes the obsolete proof after a take reservation` | red |
| esi-sso → The desktop removes unreferenced handoff proofs safely | Cleanup is interrupted or the keyring refuses deletion | `app/test/esi_sso/native_sso_test.dart` | `Failed proof cleanup does not undo the restored selection`; `Reopen acknowledges an already absent proof` | red |
| esi-sso → The desktop removes unreferenced handoff proofs safely | A live or pending journal still needs its proof | `app/test/esi_sso/native_sso_test.dart` | `Cleanup preserves a prior proof needed by a pending take`; `A pre-upgrade take cannot fabricate prior state` | red |
| esi-sso → The desktop removes unreferenced handoff proofs safely | A legacy key has no known journal reference | `app/test/esi_sso/native_sso_test.dart` | `Upgrade tracks referenced proofs without touching old orphans` | red |
| esi-sso → The desktop removes unreferenced handoff proofs safely | An unverified store deletes nothing | `app/test/esi_sso/native_sso_test.dart` | `A rejected journal does not run proof cleanup` | red |
| esi-sso → The desktop removes unreferenced handoff proofs safely | A proof that was never committed is removed later | `app/test/esi_sso/native_sso_test.dart` | `Reopen removes a proof whose journal never committed`; `Reopen retains cleanup work when the keyring cannot establish absence` | red |

## 1. Clean up tracked desktop proofs

- [ ] 1.1 Verify A1. Check the lockfile pins and released implementations of `delete` and `containsKey` for each desktop backend, including the `flutter_secure_storage_platform_interface` method channel. Confirm that deleting a missing key completes when storage is healthy, and do not use the Windows lookup as evidence after a thrown delete.
- [ ] 1.2 Write and run the failing regression first against a real, temporary SQLite journal and the injected keyring. Reopen after a refused delete, confirm the restored selection and notice did not change, then permit deletion and show that the old implementation leaves the rejected proof behind. Add the other mapped cases before editing production code. Use SQLite v1 and v2 fixtures, operation counts and awaited open/close ordering, not sleeps. Check pending, prior and live proof identity by boolean comparison so a failure cannot print it. Exercise delete failure followed by absent, present and unavailable results, a failed tracking-row acknowledgement after a successful delete, and a diagnostic sink that throws. Assert exact deletion eligibility and retention, and do not put secrets or raw errors in test output.
- [ ] 1.3 Implement the v3 migration and seed all three reference fields. Track new proof identities before writing the keyring. At verified open and after a committed refusal, delete only tracked, unreferenced proofs and acknowledge them only when deletion completes or the injected absence check succeeds. Keep open and inline rollback usable after a returned cleanup error. Document C2–C6 and C8 at their specified symbols, including why `_Keyring.contains` cannot confirm absence on Windows. Carry C1 and C7 in the delta spec. Verify the targeted native SSO and skills refusal tests, including unchanged v1 reservation resume, and analyze the touched Dart files. Update the test map after verification.

## Workflow follow-up

Run Claude pre-ship review, ship the PR with `Fixes #43`, and watch CI and reviews. Archive and sync on the PR branch before reporting readiness. The owner merges.
