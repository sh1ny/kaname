# Windows secure-storage evidence (#49)

All runs used an isolated temporary clone of this branch on the owner's Windows machine, not the user's Windows clone, with Flutter 3.47.9 through mise. Every value was synthetic. No test read or wrote the user's keyring. This file records no keys, proofs, fixture bytes or private paths.

## Packages

- Hosted baseline: `flutter_secure_storage_windows` 4.2.2 from pub.dev, lockfile sha256 `471951813a97006d899db4948acc654a4f28c440083ea08178935ce20b173ec1`. Its `lib/` matches the upstream tag `flutter_secure_storage_windows-v4.2.2` (peeled commit `bd602d0a47bea9088cd40bd87fcbf7d2c67f7e60`). Only `pubspec.yaml` differs: the tag carries `resolution: workspace` and newer constraints.
- Patched pin: `https://github.com/sh1ny/flutter_secure_storage.git`, branch `fix/windows-atomic-save-4.2.2`, commit `f87ea6e365fb321288ef2e9256a8be5a5e3171ca`, path `flutter_secure_storage_windows`. `pubspec.lock` records `resolved-ref: f87ea6e365fb321288ef2e9256a8be5a5e3171ca`. The first pin was `ecd6627b06ee5686880ca6bbe213ea111b785660`. PR review feedback round 1 added two fork commits on the same branch: `68b93dec82b25d0936b7a3629f4f063e704c90de` and `f87ea6e365fb321288ef2e9256a8be5a5e3171ca`. Together they retry the publish rename after `ERROR_ACCESS_DENIED` or `ERROR_SHARING_VIOLATION`, for up to five attempts 50 ms apart, and then fail closed. A `beforeRetry` test hook replaces the pause. On Windows, `.dart_tool/package_config.json` resolves the package to the pub git cache directory `flutter_secure_storage-f87ea6e365fb321288ef2e9256a8be5a5e3171ca/flutter_secure_storage_windows`, and `git rev-parse HEAD` in that directory prints `f87ea6e365fb321288ef2e9256a8be5a5e3171ca`.
- A1 is confirmed. The hosted `DpapiJsonFileMapStorage.load` deletes the file after a DPAPI, UTF-8 or JSON failure. `save` rewrites the committed file in place through `File.writeAsBytes` and retries in a loop. Write and exact-key delete both call `save` with the whole map.

## Red: hosted 4.2.2

Command, from `app/` after `flutter pub get --enforce-lockfile` with the base lockfile:

```
mise exec -- flutter test --no-pub test/esi_sso/windows_secure_storage_preservation_test.dart
```

Outcome: exit 1. The facade reached the fixture directory and the read failed, as the test requires. Then the file-preservation assertion failed with `The backend removed the unreadable committed file.` The backend's own diagnostic reported a `CryptUnprotectData` failure and the deletion. There was no registration, compilation or setup error.

## Green: fork pin

Command, from `app/` after `flutter pub get --enforce-lockfile` with this branch's lockfile:

```
mise exec -- flutter test --no-pub test/esi_sso/windows_secure_storage_preservation_test.dart test/esi_sso/windows_secure_storage_crash_test.dart
```

Outcome: exit 0, 6 tests passed. After the pre-ship review added or tightened tests in rounds 1, 2, 4 and 5, the same command on the same pin passed all 9 tests with exit 0. After PR review feedback round 1, the same command on pin `f87ea6e` passed all 10 tests with exit 0.

| Test | Result |
|---|---|
| An unreadable committed Windows credential file stays intact | Passed, with the test unchanged from the red run. The read fails and the committed bytes remain. |
| The default Windows facade reopens the complete credential set | Passed. `const FlutterSecureStorage()` wrote and deleted one key. Each reopen through the storage read the full expected map with unrelated entries unchanged. No staged file remained and no synthetic secret appeared in diagnostics. |
| A partial staged file is never read and is replaced | Passed. A partial `.staged` sibling was ignored on read and replaced by the next write. |
| A complete staged file never supplies credentials | Passed (pre-ship round 1). With no committed file, a complete staged map was not read or promoted. The next write published only the new entry and removed the staged file. |
| A malformed decrypted credential file fails without exposing it | Passed (pre-ship round 1). For DPAPI-protected invalid JSON, a JSON list and a map with a non-string value, read, write and (since pre-ship round 4) exact-key delete each returned a fixed `PlatformException`. The committed bytes were unchanged, and neither the error nor the diagnostics held the synthetic secret. |
| A committed file that cannot be read is not empty storage | Passed (pre-ship round 2). While a handle denied read sharing, a plugin read returned a fixed `PlatformException`, not an empty map. After release the original bytes and map were unchanged. |
| A failed replacement keeps the committed bytes | Passed. A handle without delete sharing made the rename fail. Since pre-ship round 5 the test also confirms through the `beforePublish` hook that the write reached the rename. Since PR feedback round 1 the `beforeRetry` hook also confirms that the held file blocked every bounded attempt (attempts 2 to 5 were retried). The write returned the fixed `PlatformException` with code `StorageWriteFailed`. The committed bytes were unchanged, the staged file was removed, and neither the error nor the diagnostics held a synthetic secret. |
| A briefly held committed file is replaced on retry | Passed (PR feedback round 1). A handle without delete sharing blocked the first rename. The `beforeRetry` hook released it before attempt 2, with no timing involved. The write published the full new map, only attempt 2 was retried, and no staged file remained. |
| Interrupted Windows write preserves the old or new map | Passed for both barriers. Since pre-ship round 2 the parent also inspects the files while the child waits at its barrier, as the next section describes. |
| Interrupted Windows delete preserves the old or new map | Passed for both barriers |

## Process exits

Each case ran a child `flutter test` host. At the barrier the child reported its process ID and stage over loopback. The parent opened that process with `SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION` before acknowledging. Still before acknowledging, it decoded the files. At the barrier before publication, the committed path held the complete old map and the staged sibling held the complete new map. At the barrier after publication, the committed path held the new map and no staged file remained. After the acknowledgement the child called `exit(73)` without unwinding the save. The parent waited for the handle to signal, read the exit code, closed the handle and reaped the runner before reopening the store. Since PR feedback round 1, a teardown ends the runner's process tree with `taskkill /T /F` and awaits its exit if the test timeout fires first, so a stalled child cannot keep the case directory open. The child output held no synthetic secret.

| Operation | Barrier | Observed host exit | Map on reopen |
|---|---|---|---|
| write | before publication | handle signalled, exit code 73 | complete old map |
| write | after publication | handle signalled, exit code 73 | complete new map |
| delete | before publication | handle signalled, exit code 73 | complete old map |
| delete | after publication | handle signalled, exit code 73 | complete new map |

## A3 outcome

`flutter test` on Windows does not run the generated Dart plugin registrant. The root and background isolates both kept the method-channel defaults, even after `DartPluginRegistrant.ensureInitialized()`. The tests therefore call the package's own `FlutterSecureStorageWindows.registerWith()`, which is what the app's registrant calls. Tests also report Android as `defaultTargetPlatform`, so the facade would send Android options and enable the legacy method-channel lookup. Both facade tests set `debugDefaultTargetPlatformOverride` to Windows so the facade sends the Windows options the app sends.
