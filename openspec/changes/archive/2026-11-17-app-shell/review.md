# Review

## Metadata

- **Round:** 4 (re-check after amendment 3d1b2db, which applies round 3's M-a, with the owner choosing option (a), and M-b, plus suggestions S-n, S-o, S-p and S-q; S-r was not adopted)
- **Prior round:** round 3 (not recorded) ended APPROVE_WITH_CHANGES with M-a and M-b
- **Reviewer:** fresh-context subagent (Claude Code)
- **Reviewed:** `git show 3d1b2db` and `git show 01934ef`. Files: openspec/changes/app-shell/proposal.md (Modified Capabilities, Impact), design.md (D11 and the decision summary; the D4 text is unchanged), tasks.md (test map, group 6 including 6.4), and specs/ember-ui/spec.md (the new MODIFIED delta). Main spec: openspec/specs/ember-ui/spec.md ("Keyboard focus is always visible"). Also DESIGN.md "Segmented controls" (339-340) and line 369. Source: app_packages/kaname_ember_ui/lib/src/ember_theme.dart (19-22), lib/src/focus_ring.dart (the paint method), lib/kaname_ember_ui.dart, pubspec.yaml (description), test/focus_test.dart, test/support/focus_check.dart, and app/lib/settings/ui/theme_segmented.dart and appearance_section.dart.
- **Validation:** `mise exec -- openspec validate app-shell --strict` reports "Change 'app-shell' is valid".
- **Skills:** the request named no skills, so none were loaded.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Earlier findings, re-checked

- **M-a: fixed with option (a).**
  - The delta `specs/ember-ui/spec.md` modifies "Keyboard focus is always visible". I compared it with the main spec, and it differs in three places only:
    1. The placement sentence now reads "Buttons, icon buttons, chips and segmented-control options show a 2-pixel outline 2 pixels outside their shape".
    2. The THEN line of "Tab to each control" now reads "each button, icon button and segmented-control option paints ...".
    3. One new scenario, "Segmented-control option beside the selected one".
  - "Focus leaves a control" and "A control without a focus indicator" match the main spec word for word.
  - The requirement body is 366 characters, under the 500-character limit for main specs.
  - The test map has three new ember-ui rows that point to the package focus test and are marked as outside `app/test/`.
  - The proposal now lists `ember-ui` under Modified Capabilities, which also settles S-l from round 2.
  - D11 no longer says "no requirement changes".
- **M-b: fixed.**
  - D11 now says: "The focused option's ring is painted above its neighbours, so a selected or hovered neighbour cannot cover it."
  - Task 6.4 asks for a focus-test case in both themes that tabs to an option whose right-hand neighbour is selected. It also adds the options to the "focus leaving a control" test.
  - The new scenario's THEN can be tested with the existing checker. For an `outsideRing`, focus_check.dart:85 and 99 sample the right edge 3px outside, which is a pixel inside the right-hand neighbour. Finding Focus there therefore shows that the ring is painted above that neighbour.
  - The existing "focus leaving" loop (focus_test.dart:239-284) asserts each control's indicator as it tabs, then asserts that the previous control's indicator is gone. Adding the options to `_controlList` covers both halves of that scenario for the options.
- **S-n: adopted.** D11 now contrasts the control with D4's shell widgets (no routing or slot behaviour) and names the second consumer. DESIGN.md:369 does name a "tabbed segmented header".
- **S-o: adopted.** D11 is marked "Important: yes", with a reason, and the summary row matches.
- **S-p: adopted.** Each option's key now comes from the caller, so the app keeps `SettingsKeys.themeOption`. D11 and the 6.4 widget test carry the semantics over: the group label, and on each option the button role, label, selected state and mutual exclusion. This matches theme_segmented.dart:40-42 and 97-103.
- **S-q: adopted.** Task 6.4 now updates the library doc in lib/kaname_ember_ui.dart (line 3) and the pubspec description (line 2), and runs analyze as `mise exec -- dart analyze --fatal-infos`.
- **S-r: not adopted.** This was optional and leaves no gap in the requirements: "Material controls take Ember's shapes and states" lists only Material controls, and the delta does not add the segmented control to it.
- **Earlier rounds (M1-M7, N1, S-i to S-m):** the amendment does not touch them, so their status is unchanged.

### Claims (D11, as amended)

- **"drawn as DESIGN.md's 'Segmented controls'":** supported by DESIGN.md:340: pill track, Hairline border, 2px inset, 24px pill options, and `segment-on`, Ink and Seated for the selected option.
- **"2-pixel Focus outline 2 pixels outside the focused option through `EmberFocusBorder.pill`":** supported. The paint method in focus_ring.dart draws a DRRect between `inflate(ringOffset + ringWidth)` and `inflate(ringOffset)` for outside placement.
- **"the package's theme doc comment ... says the first change that needs one builds it in the package with its own focus test":** supported by ember_theme.dart:19-22.
- **"DESIGN.md already names a second consumer (the inspector's tabbed header)":** supported by DESIGN.md:369.
- **"the caller gives each option's key, so the app keeps `SettingsKeys.themeOption`":** consistent with the code. The only use of the app control is appearance_section.dart:45, and in the current code the key sits on each option widget (theme_segmented.dart:58).

### New in this amendment

The amendment adds no contradiction with D4, with the other ember-ui requirements or with DESIGN.md. Its delta keeps the existing scenarios, apart from naming the segmented options, and validation passes.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

**S-s.** The test-map row "Tab to each control" (tasks.md:56) names the test as "segmented-control options paint the outside outline in both themes". No such test exists in focus_test.dart, and task 6.4 does not create one. Task 6.4 lists only two focus-test additions: the case for the option beside the selected one, and the options in the "focus leaving a control" test.

In practice the scenario is still covered:
- the leaving test asserts each control's indicator as it tabs (focus_test.dart:245-250);
- adding the options to `_controlList` also puts them in the existing "tab to each control paints its Focus indicator in both themes" test (focus_test.dart:207-221).

But whoever turns that row green has no named test to check it against. The fix can be either of these:
- in 6.4, say that the options join `_controlList`, so they run in both existing tests;
- in the row, name the existing test.

This is optional.

## Verdict

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals
