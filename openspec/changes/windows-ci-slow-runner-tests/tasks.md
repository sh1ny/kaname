# Tasks

## Test map

There are no delta specs. These existing `client-static-data` scenarios retain real file I/O.

| Requirement | Scenario | Test file | Test name | Before the fix |
|---|---|---|---|---|
| Native apps keep the bundle as a file | Offline restart after a rollback | `app/test/static_data/static_data_notifier_test.dart` | `a rollback announced at a higher revision downloads N, keeps it, and an offline restart loads N from the same file` | Windows red on PR #44 |
| Native apps keep the bundle as a file | Unreadable file | `app/test/static_data/static_data_notifier_test.dart` | `truncated kept file is rejected and kept, the announced bundle is downloaded, and its save replaces the file` | Windows rename race recorded in #24 |
| Native apps keep the bundle as a file | Interrupted save | `app/test/static_data/file_bundle_store_test.dart` | `save stopped before the rename loads the previous bundle and removes temporary files older than an hour` | Existing test; remove polling without changing the scenario |

## 1. Order static-data tests by events

- [ ] 1.1 Use the two existing Windows failures as the red cases before changing the tests. Record the PR #44 expected build 100 and actual 101, and #24's rename `errno 32`; trace them to the old waits and record the violated rule numbers in the group commit or PR. Do not rerun the unmodified tests to reproduce intermittent results.
- [ ] 1.2 In both real-store notifier tests, await the load or transfer state and then the terminal download result as described in D1. Assert a successful save of the expected build before opening the file or restarting offline. Preserve the identity, corrupt-file retention and download assertions. Verify `app/test/static_data/static_data_notifier_test.dart`.
- [ ] 1.3 Remove the file-store suite's polling. Verify that the held opener rejects its old read without removing the other writer's file, stale cleanup keeps the old bundle and removes only the stale temporary, both paused saves finish in order, and the suspended save writes again after cleanup. Use the fixed clock and one-shot gates in D2. Verify `app/test/static_data/file_bundle_store_test.dart` and other callers of `FakeBundleOpener` that use its hold behavior.
- [ ] 1.4 Add the ten rules to `AGENTS.md` under `### Windows CI tests` in `## Dart and Flutter code`. Compare the numbered text and closing sentence with the owner-approved wording quoted in `design.md`.

## Workflow follow-up

- Run Claude pre-ship review. Open the PR with a reference to #24 without closing it, and wait for reviews and Windows CI.
- Archive on the PR branch. Confirm the final archive head passes CI and leave merging to the owner.
