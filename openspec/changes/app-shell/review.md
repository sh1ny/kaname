# Review

## Metadata

- **Round:** 2 (re-check after the drift amendment a19cde7, which voided the round-1 verdict)
- **Prior round:** round 1 ended APPROVE_WITH_CHANGES with CHANGES_APPLIED: yes (N1 fixed; S-i and S-j left as cosmetic suggestions)
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** `git show a19cde7`; openspec/changes/app-shell/proposal.md (Modified Capabilities, Impact), design.md (D10, the decision summary, Assumptions A3, Risks, ADRs), tasks.md (test map and task 1.1), specs/dependency-licences/spec.md (new MODIFIED delta); main specs openspec/specs/dependency-licences/spec.md and openspec/specs/third-party-notices/spec.md. Source, read at HEAD (committed) because the work tree holds uncommitted task 1.1 edits: tools/kaname_tools/lib/src/licences.dart (lines 1-30, 111-170, the `_evaluate` exception path), tools/kaname_tools/lib/src/notices.dart (C5 at 65-69, 91-106, 266-282), tools/kaname_tools/lib/src/sbom.dart (69, 127), tools/kaname_tools/test/licences_test.dart (66, 104-122). ADRs listed in docs/adr/ (0002 has nothing on SDK package licences). `openspec validate app-shell --strict` passes. Skills loaded: dart-add-unit-test, dart-write-documentation.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Earlier findings, re-checked

- **Round 1 M1-M7, N1:** fixed in earlier rounds. The amendment touches none of the text they concern (D2, D3, D5, D6, D9, Resource Bounds, the app-shell and app-server-connection specs). Not re-opened.
- **S-i (dependency count in Risks):** still open and cosmetic. The amendment did not touch the Risks bullet (design.md:275). It still names `flutter_localizations` but not `flutter_web_plugins`. The new A3 result (design.md:144) also names both SDK packages.
- **S-j (branch count at 10x):** still open and cosmetic. The amendment did not touch it.

### Claims (D10 and the A3 result)

- **"the check only special-cased `flutter` and `flutter_test`"**: supported. In licences.dart at HEAD, lines 149-152 are `case ('sdk', 'sky_engine')` and `case ('sdk', 'flutter' || 'flutter_test')`. Every other package then goes to `readLicenceText`, and a missing file gives `NoLicenceFile`.
- **"the notices check ... already references every SDK package as `flutter-sdk` (its C5)"**: supported. notices.dart:65-69 documents C5, and notices.dart:266-267 adds `flutterSdkRef` for any `source == 'sdk'` package, with no name filter.
- **Rejected option "owner exceptions in `licence-policy.yaml`"**: supported, and the code gives a stronger reason than the design states. In `_evaluate`, an exception on a `NoLicenceFile` package is itself a failure (`_readFailureNote`, "cannot cover a package whose licence was not read"). An exception could not have resolved A3 at all.
- **SBOM effect**: sbom.dart:127 reuses `classifyLockedPackages`, so SDK packages now get `BSD-3-Clause` in the SBOM. sbom.dart:69 handles only `sky_engine`. This matches the SBOM requirement ("its SPDX licence identifier or licence reference"), and its `sky_engine` scenario still holds.

### Spec delta

- The MODIFIED requirement keeps every existing scenario word for word, as a diff against the main spec shows, and adds only "Other Flutter SDK packages". So archiving drops no scenario.
- The requirement body is 452 characters, under the 500-character limit that strict validation applies to main specs after archive. The main spec's current body is 470 characters.
- It is consistent with the existing "No licence file" scenario, which already says "non-SDK". It is also consistent with third-party-notices, whose dependency requirement already gives SDK packages "a reference to the SDK's licence".
- The new scenario has a red-first row in the test map (tasks.md:55). Task 1.1 orders the failing test before the code change and runs `mise run test:tools`, which exists (mise.toml:56). The test fits the existing `_repo`/`_check` harness in licences_test.dart, and it asserts the exit code, an empty stderr and the `BSD-3-Clause: 2` count, which is enough to show both packages were accepted with no missing-file report.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

**S-k.** D10's rejection of policy exceptions (design.md:111) says exceptions "cover packages whose licence the check finds wrong". The code is stricter than that: `_evaluate` in licences.dart rejects any exception on a package with no licence file, so this route could not have worked. The current wording is correct but understates the reason. This is optional.

**S-l.** The proposal's Modified Capabilities section (proposal.md:46-47) now has a second bullet: "The `ember-ui` requirement already allows ... and `server-health` is unchanged." Because it sits in that list, a reader could take it as a modified capability. Turning it into a sentence after the list, or starting it "Not modified:", would avoid that. This is cosmetic. OpenSpec validation passes either way.

**S-m.** The doc comment on `flutterLicence` at HEAD (licences.dart:25), "The licence of the Flutter SDK packages `flutter` and `flutter_test`", and the doc on `classifyLockedPackages` (licences.dart:114-115) both need updating as part of task 1.1, under dart-write-documentation. The uncommitted work-tree edit already does this. This is noted only so the pre-ship review checks it.

## Verdict

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals
