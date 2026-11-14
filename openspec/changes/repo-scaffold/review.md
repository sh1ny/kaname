# Review

## Metadata

- **Round:** 1
- **Prior round:** none
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer)
- **Reviewed:** openspec/changes/repo-scaffold/proposal.md, design.md, specs/workspace-layout/spec.md, specs/contribution-policy/spec.md, specs/third-party-notices/spec.md; openspec/roadmap.md (M0), openspec/architecture.md (shared-package rows); docs/adr/0001, 0002, 0003, 0010; cited ranges in mise.toml, .gitignore, .gitattributes, AGENTS.md:61, .claude/skills/specwright-commit/SKILL.md:46, .claude/skills/UPSTREAM.json, brand/fonts/OFL-NOTICE.md; `git ls-files '*.dart'`; openspec/specwright.yaml. Every cited path is tracked and none is a symlink. Skills loaded: codebase-design, serverpod-overview, dart-run-static-analysis, dart-add-unit-test, dart-build-cli-app, dart-use-pattern-matching, dart-write-documentation, flutter-add-widget-test (all loaded). Re-check run: proposal.md, design.md and the three specs re-read after the author applied Required Changes 1-6. Only those items and the three Suggestions were re-checked.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

**M1. Root analysis and format would cover tracked Dart files that are not workspace members, and the spec requires reformatting vendored files.** (Fixed)
`dart analyze` at the root would also analyse `brand/flutter/*.dart` and the vendored skill examples under `.claude/skills/*/examples/`, which fail to resolve. The spec's "every Dart file" also covered vendored copies that must stay unmodified.
Re-check: fixed. D1 (design.md:33) adds `analyzer: exclude:` for `.claude/**`, `brand/**`, `**/build/**` and `**/.dart_tool/**`, and limits the format check to member directories, never `.`. The Context section (design.md:25) records the non-member files. A1 (design.md:129) covers the exclude list and gives a fallback. In the workspace-layout spec, "Analysis and formatting are clean" now reads "every Dart file in a workspace member" and says non-member files are neither analysed nor formatted (spec:62). The new scenario "Files outside the workspace members" (spec:72-74) asserts that nothing under `.claude/` or `brand/` is analysed, reported or changed.

**M2. The workspace check's discovery rule would fail once the app has a plugin.** (Fixed)
Flutter plugin symlink trees and build folders under `app/` hold `pubspec.yaml` files, and the check would have flagged them as unlisted packages.
Re-check: fixed. D2 (design.md:41) defines discovery: it does not follow symlinks and skips `build/`, `.dart_tool/`, `**/flutter/ephemeral/`, `**/.symlinks/` and `.plugin_symlinks/`. The Mechanism Ledger has a matching row (design.md:220). The workspace-layout spec adds the scenario "Generated plugin trees are ignored" (spec:20-22).

**M3. It is unclear which command finds a vendored source missing from the notices, and how it decides a source is "mentioned".** (Fixed)
The spec, the design and the State & Ownership table named different commands, the matching rule was undefined, and the all-checks task left out the notices check.
Re-check: fixed. D2 (design.md:41) and D9 (design.md:98) make `notices --check` the only owner and define the match: the repository URL, `license` and `repository_license` where present, and each `brand/fonts/OFL-*.txt`. It reports every gap. The State & Ownership row (design.md:187) now names `notices --check`. In the third-party-notices spec, the scenario (spec:16-18) and the check-mode requirement (spec:40) agree. The workspace-layout requirement "One task runs every local check" (spec:81) now includes the notices staleness check.

**M4. `git commit -s` contradicts D8's trailer order and AGENTS.md's ending rule.** (Fixed)
Re-check: fixed. D8 (design.md:89) says owner and agent commits write the `Signed-off-by` line explicitly and never use `-s`. CONTRIBUTING keeps `-s` as the example for outside contributors. In the contribution-policy spec, the requirement (spec:32) carries the agent placement rule. The "Signed commit" THEN now says "in its final trailer block" (spec:36). The new scenario "Agent-made commit" (spec:38-40) asserts the order.

**M5. Deferred CI enforcement has no carried-constraint entry.** (Fixed)
Re-check: fixed. C6 (design.md:142) is a deliberate-gap entry with exactly one destination, the third-party-notices requirement "A stale dependency section is detectable". That requirement now says "Running it in CI belongs to `ci-matrix`" (spec:40). CONTRIBUTING no longer claims automated enforcement: the "Unsigned commit" scenario now says such PRs "are not merged (an automated check is added with CI in `ci-matrix`)" (contribution-policy spec:44).
Residual, non-gating: the chosen destination states only the notices part of C6. The DCO part is carried in the contribution-policy "Unsigned commit" scenario, and the licence check by ADR 0002 (`docs/adr/0002-licence-clean-room-and-eula-boundary.md:16`). So all three now live in in-force documents, but C6's destination names only one of them. See S4.

**M6. Serverpod skills have two licence files, but the spec takes one per source.** (Fixed)
Re-check: fixed. The third-party-notices requirement and scenario (spec:10, 14) require every licence file a source records, `license` and `repository_license`, and name both the SSPL-1.0 and the BSD-3-Clause texts for Serverpod. The design Context (design.md:24) records both files and the owner's condition.

### Suggestions

**S1.** The citation `.claude/skills/UPSTREAM.json:6-140` stopped short of the tenth source. Taken up: it now reads `:6-147`, which covers every source entry (the array closes at line 146).

**S2.** Add an assumption that `pubspec.lock` in a pub workspace leaves out the workspace members themselves. Taken up as A5 (design.md:130), with a fallback that skips member roots.

**S3.** Say which `analysis_options.yaml` applies `public_member_api_docs`. Taken up: D1 (design.md:33) gives each package under `packages/` its own file that includes the root file and adds the rule.

**S4 (new, non-gating).** Two small mismatches remain after the fixes:
- C6's destination holds only the notices-in-CI part. Point it at the roadmap's `ci-matrix` line instead, or name the contribution-policy "Unsigned commit" scenario alongside it, so a `ci-matrix` planner finds the DCO check from C6.
- Flow & State Gaps (design.md:211) still says the `workspace` check "finds every `pubspec.yaml` under the package folders". Add "per D2's discovery rule" so it matches D2.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **M1.** In design.md D1, add an `analyzer: exclude:` list to the root `analysis_options.yaml` covering at least `.claude/**`, `brand/**` and `**/build/**`. State that the format check runs only on workspace member directories, never on `.`. Rewrite A1, change the spec wording to "every Dart file in a workspace member", and add a scenario for files outside the members. **Fixed.**
2. **M2.** Define how the `workspace` check discovers packages: no symlink following, and skip lists for build and plugin folders. Add the scenario "Generated plugin trees are ignored". **Fixed.**
3. **M3.** Name one owner for the vendored-source coverage check, define the match, and add `notices --check` to the all-checks requirement. **Fixed.**
4. **M4.** Agents write `Signed-off-by` explicitly before `Co-authored-by`; `-s` stays the contributor example, and its THEN says "final trailer block". **Fixed.**
5. **M5.** Add a deliberate-gap carried constraint with one destination for the CI enforcement left to `ci-matrix`, and stop CONTRIBUTING from claiming enforcement before it exists. **Fixed** (see the residual note under M5 and S4).
6. **M6.** The notices spec requires every licence file a source records, including both Serverpod texts, and the design Context is corrected. **Fixed.**

CHANGES_APPLIED: yes

## Rebuttals

None. Every Required Change was applied and re-checked by the reviewer.
