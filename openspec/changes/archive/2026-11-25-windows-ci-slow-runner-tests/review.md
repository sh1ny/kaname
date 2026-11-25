# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 returned `APPROVE_WITH_CHANGES` with one Critical finding (the ten Windows CI rules had no source or wording), one Moderate finding (the resumed writers could hang, and the suspended-save clock could break the test) and one Suggestion (keep the truncated-file scenario).
- **Reviewer:** cross-model CLI (Claude)
- **Reviewed:** `openspec/changes/windows-ci-slow-runner-tests/design.md`, `proposal.md`, `.openspec.yaml` and the round 1 `review.md`; `openspec/schemas/specwright/templates/review.md`; `AGENTS.md:15-42`; `docs/adr/0010-flutter-app-state.md:1-25`; `docs/adr/0013-client-data-bundle.md:1-25`; all of `app/lib/static_data/logic/static_data_sync.dart` and `app/lib/static_data/data/file_bundle_store.dart`; `app/lib/static_data/data/bundle_store.dart:118-147`; `app/test/static_data/static_data_notifier_test.dart:1-200,500-660`; all of `app/test/static_data/file_bundle_store_test.dart` and `app/test/static_data/support/bundle_fixture.dart`; `app/test/static_data/support/static_data_fakes.dart:85-245` plus a search for the hold and subscription members. I re-read every range the design cites, and each says what the design claims. I could not compare the quoted rules with issue #24 itself, because this review reads only repo files. I checked that the design names #24 as the source and gives the rules word for word.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

None. Each new ordering claim matches the code:

- **Truncated file (D1).** `NoBundle(Downloading)` can only appear after the kept load has settled. An announcement that arrives before the load only sets `_waiting`, and the target stays `_NoTarget`, so the reason stays `Starting` (`static_data_sync.dart:255-266,551`). `_take` runs only once `_keptLoaded` is true (`:183-188,268`). It calls `_pump`, which calls `downloader.start` synchronously, before `_refresh` publishes `Downloading` (`:298-299,331-347,548`). The replacement therefore stays the first announcement, and the waited-for state confirms both the settled load and the started transfer. The fake `emit` delivers synchronously (`static_data_fakes.dart:106`), and the subscription exists once the provider is built (`static_data_sync.dart:124`). The test needs no wait on the subscription count.
- **Persistence.** The design does not treat `BundleReady` or `updating: false` as proof of a save. `_swapIn` clears the attempt and publishes `DownloadSaving` before the save starts (`:431-445,507`). Only `_saveLoop` sets `DownloadSucceeded` or `DownloadNotSaved`, after `_store.save` returns (`:459-476`). `FileBundleStore.save` returns `BundleSaved` only after the rename (`file_bundle_store.dart:106-107`). Waiting for `DownloadSucceeded` before reading the file or restarting offline is correct.
- **Rollback.** Announcing N+1 at revision 1 to a store that already holds N+1 creates no attempt (`static_data_sync.dart:293-297`), so "no download" can be checked. The later N at revision 2 is the only attempt, so no earlier terminal result can satisfy the wait by mistake.
- **Writers (D2).** After `load()` removes writer 1's stale temporary file, its rename fails. `exists()` returns false and the second attempt calls `beforeRename` again (`file_bundle_store.dart:99-117`). The one-shot hook then returns at once, and writer 1 completes with `BundleSaved`. Writer 2's temporary file is the recent one, so it survives, and writer 2 renames it after writer 1. Both writers close their sinks before the pause (`:138-149`), so `load()` can delete the stale file on Windows.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. Record the ten owner-approved Windows CI rules with their source and destination. **Applied:** `design.md:54-69` names [#24](https://github.com/sh1ny/kaname/issues/24) as the source and quotes the full wording: the preamble, rules 1-10 and the closing commit/PR line. The destination is a new `### Windows CI tests` subsection at the end of `## Dart and Flutter code` in `AGENTS.md`, which today runs from line 25 to line 37.
2. Define how each writer ends and fix the suspended-save clock. **Applied:** `design.md:34` gives each writer its own store and hook. Each hook signals and pauses only on its first call, and the design cites the second `beforeRename` call. After the interrupted-save assertions, the test releases writer 1 and asserts `BundleSaved`, then does the same for writer 2. Every stale or recent temporary-file timestamp is set relative to the injected `now`, including the file the suspended-save test expects another store to remove. Release and join also run on failure (`design.md:102,127`).

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals

- **Round 1 Critical 1 (rules not recorded or sourced):** fixed (`design.md:54-69`). The full wording is quoted from #24, and the `AGENTS.md` destination is named.
- **Round 1 Moderate 1 (resumed writer can hang; suspended-save clock):** fixed (`design.md:34`). The hooks are one-shot and per-writer, the saves settle one after the other with `BundleSaved` asserted, and the timestamps are relative to the injected `now`.
- **Round 1 Suggestion 1 (keep the truncated-file scenario):** fixed (`design.md:26,113`). The replacement stays the first announcement, and `NoBundle(Downloading)` is the event that confirms the settled load and the started transfer (`static_data_sync.dart:182-190,293-299,330-348,539-549`).