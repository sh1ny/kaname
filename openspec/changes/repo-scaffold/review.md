# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1, APPROVE_WITH_CHANGES. Required Changes M1-M6 were applied and re-checked by the reviewer. Commit 06fe534 voided that verdict by taking up half of suggestion S4: it aligns the Flow & State Gaps line with D2's discovery rule.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer)
- **Reviewed:**
  - Change artifacts: proposal.md, design.md, specs/workspace-layout/spec.md, specs/third-party-notices/spec.md, specs/contribution-policy/spec.md and tasks.md under openspec/changes/repo-scaffold/.
  - Earlier review and amendment: the round-1 review (`06fe534~1:…/review.md`) and the amendment diff (`git show 06fe534`).
  - In-force ADRs: docs/adr/0001, 0002, 0003 and 0010.
  - Cited ranges, re-read on `feat/repo-scaffold` and `main`:
    - mise.toml:4-5, 9 and 17-23
    - .gitignore:2, 6 and 10-11
    - .claude/skills/UPSTREAM.json:6-147, 68 and 94-96
    - brand/fonts/OFL-NOTICE.md:5-9
    - AGENTS.md:61
    - .claude/skills/specwright-commit/SKILL.md:46

    Every cited path is tracked.
  - Code evidence, read from the branch with `git show feat/repo-scaffold:…`:
    - root pubspec.yaml, pubspec.lock, analysis_options.yaml and .gitattributes
    - app/pubspec.yaml, app/lib/main.dart and app/analysis_options.yaml
    - packages/kaname_core/analysis_options.yaml
    - tools/kaname_tools/pubspec.yaml
    - tools/kaname_tools/lib/src/{file_system,real_file_system,workspace,purity,notices}.dart
    - tools/kaname_tools/test/notices_test.dart (the expected `flutter-sdk` note)
    - THIRD_PARTY_NOTICES (the markers and the `flutter-sdk` lines)
  - Uncommitted working-tree diffs: the group 6 diff to mise.toml, and the Required Change edits to design.md and tasks.md (`git diff -- openspec/changes/repo-scaffold/`).
  - Skills loaded: dart-use-pattern-matching, dart-write-documentation, dart-run-static-analysis, dart-add-unit-test, dart-build-cli-app and flutter-add-widget-test. All six loaded.
  - Referenced stores: none.
  - Re-check: design.md and tasks.md were re-read after the author applied Required Change 1. Only that item was re-checked; the Suggestions were not taken up this round.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

**M1. The `flutter-sdk` notice reference pointed to the wrong file for the engine's bundled third-party licences.** (Fixed)

D9 and C5 said SDK packages get the ref `flutter-sdk`, "pointing to the Flutter SDK's own LICENSE … because the Flutter SDK's LICENSE is large". The generated section on the branch made this concrete:
- `sky_engine 0.0.0 sdk flutter-sdk` (THIRD_PARTY_NOTICES:137) resolved to the note "Their licence is the LICENSE file at the root of the Flutter SDK" (THIRD_PARTY_NOTICES:159).
- That note comes from `NoticesGenerator.flutterSdkNote` (tools/kaname_tools/lib/src/notices.dart:94-96).

The root LICENSE is Flutter's own short BSD-3-Clause notice. The notices for the engine's bundled third-party components are in `bin/cache/pkg/sky_engine/LICENSE`. A reader who followed the reference would therefore miss them, which conflicts with ADR 0002's rule that every bundled dependency is listed (docs/adr/0002-licence-clean-room-and-eula-boundary.md:16).

Re-check: fixed. The working-tree diff makes three changes to design.md:
- **D9:** SDK packages still get the ref `flutter-sdk` with no text copied, and the note now "names both the Flutter SDK's root `LICENSE` and `bin/cache/pkg/sky_engine/LICENSE`, which holds the notices for the engine and its bundled third-party components". The "reference, not copy" decision and its format contract are unchanged.
- **C5:** the rationale is replaced with the requested wording, "because `sky_engine`'s LICENSE, which aggregates the engine's third-party notices, is very large". It still has exactly one destination, the `NoticesGenerator` doc comment.
- **Context:** a new line records the SDK licence layout. The author checked it in the pinned SDK: the root `LICENSE` is a 25-line BSD-3-Clause notice and `sky_engine/LICENSE` has 29,844 lines. The line also says that neither file is in the repository. The claim is now recorded where the rule asks for it. It follows the precedent of the existing `flutter --version` Context line, and I did not open the files outside the repository.

The code follow-up is tasks.md task 6.8. It updates `flutterSdkNote` and the C5 doc comment. The test is written first, and that red step works: `notices_test.dart:108-114` asserts the literal note text, not the constant, so changing the expected string first fails as intended. Then it regenerates with `notices --write` and confirms `notices --check` and the tools tests pass. No spec change is needed, because the third-party-notices requirement says only "a reference to the SDK's licence" (spec:21) and the amended D9 meets it.

Non-gating: task 6.8 sits between 6.6 and 6.7 in the list. Its ID is unique, so it does not affect group commits.

### Suggestions

These were not taken up this round; they are kept unchanged.

**S1. "One task runs every local check" literally includes resolve.**
- The requirement (workspace-layout spec:81) lists "resolve, analyse, …" and then "one task that runs all of them".
- Task 6.1 and the planned `check` task (mise.toml working tree, `[tasks.check]`) deliberately leave resolve out ("resolve-free checks").
- The scenario "on a clean clone after resolving" (spec:84) implies the intent, but the requirement sentence does not.

Rewording it to "one task that runs all of them except resolve" removes a mismatch that a pre-ship or archive verifier could flag.

**S2. Record the outcomes of the assumptions the tasks have now settled.**
- A1, A2, A4 and A5 (design.md:130-134) still say "Not checked", but tasks 2.2, 2.5 and 3.1 are ticked and the code now settles them.
- For example, the branch's pubspec.lock has no `kaname_*` entries, so A5 holds. `NoticesGenerator` correctly does not implement A5's member-skip fallback.

A one-line "Checked in task X: holds" on each would keep the design from describing a fallback the code does not have.

**S3. The test map covers only half of "Files outside the workspace members".**
- The scenario (workspace-layout spec:72-74) asserts that nothing under `.claude/` or `brand/` is analysed, reported or changed.
- Its only row (tasks.md:19) is the unit test "format directories are workspace members only", which covers the format scope.
- The analysis half rests on the root `analyzer: exclude:` list and is exercised only by task 6.2's `mise run check` run.

Adding `evidence/check-task.md` (task 6.2) to that row would make the mapping complete.

**S4. C6's destination still covers only part of C6** (carried from round 1, unchanged).
- Commit 06fe534 applied the second half of round-1 S4. The first half is still open: C6's single destination (third-party-notices "A stale dependency section is detectable") states only the notices-in-CI part.
- The DCO part is carried by the contribution-policy "Unsigned commit" scenario, and the licence check by ADR 0002:16, so nothing is lost.

This finding is non-gating, as before.

**Claims re-check.** Every other citation supports its claim:
- ADR 0003:9, 12-16, 17, 20 and 23; ADR 0001:17; ADR 0002:13, 15 and 16.
- mise.toml:4-5, 9 and 17-23, identical on main and the branch HEAD.
- .gitignore:2, 6 and 10-11.
- UPSTREAM.json:6-147 (ten sources), 68 and 94-96.
- OFL-NOTICE.md:5-9.
- specwright-commit SKILL.md:46.
- AGENTS.md:61. On the branch this line now carries the group 1 sign-off rule. It still supports the owner-identity and single-`Co-authored-by` parts of the claim.

**Amendment re-check.**
- The amended Flow & State Gaps line now matches D2 and the implementation. `WorkspaceCheck._discover` skips links, `build`, `.dart_tool`, `.symlinks`, `.plugin_symlinks` and `*/flutter/ephemeral` (tools/kaname_tools/lib/src/workspace.dart:88-93, 142-165).
- C4 and C5 are present at their doc-comment destinations (purity.dart:18-21; notices.dart:66-69). Task 6.8 updates C5's text to the amended rationale.
- The THIRD_PARTY_NOTICES markers rely on LF line endings. `.gitattributes` (`* text=auto eol=lf`) protects them on a Windows checkout.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **M1.** In design.md D9, the `flutter-sdk` reference should name both the Flutter SDK's root `LICENSE` and `bin/cache/pkg/sky_engine/LICENSE`, the notices for the engine and its bundled third-party components. The C5 rationale should change to "because `sky_engine`'s LICENSE, which aggregates the engine's third-party notices, is very large". A Context or Assumptions line should record the SDK licence layout, and the code follow-up should be added as a task.

   **Fixed.** The owner accepted the change ("Reference both files"). D9, C5 and a new Context line are updated in design.md, and task 6.8 is added to tasks.md. Re-checked by the reviewer.

CHANGES_APPLIED: yes

## Rebuttals

None. The one Required Change was applied and re-checked by the reviewer.
