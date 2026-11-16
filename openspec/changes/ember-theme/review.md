# Review

## Metadata

- **Round:** 4 (re-check of Required Changes)
- **Prior round:** Round 4's re-check confirmed Required Changes 1-4 applied and returned APPROVE_WITH_CHANGES with CHANGES_APPLIED: no, adding Required Change 5 (chip shape 75ms tween, chip checkmark draw-in, chip outlines in the theme-switch exceptions). The owner chose the recommended option and the author applied it.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - Change artifacts, limited to what Required Change 5 touches: openspec/changes/ember-theme/proposal.md (What Changes l.13 and l.20, S10 l.120-126), specs/ember-ui/spec.md (requirements "The app follows the system theme until the user chooses" l.87-96, "Material controls take Ember's shapes and states" l.98-115, and the "Tab to each control" THEN l.122 for consistency with the new wording), and design.md (D2 l.45, D5 l.69, the S10 summary row l.116, C7 l.143, C12 l.148, the Flow & State Gaps brightness bullet l.237). review.md (round 4 re-check) was read for Required Change 5 and the author's response.
  - The installed Flutter 3.47.9 SDK was read as evidence. It lies outside the repository, so this location supports the check but is not a design citation: material `material.dart` l.875-911 (`_MaterialInteriorState.forEachTween` tweens elevation, shadow colour, surface tint and shape only; the `color` is not tweened). This confirms that on a theme switch the chip's 75ms blend is limited to its shape (outline) and that its fill changes on the next frame, so "chip outlines" is the complete chip entry in the theme-switch exceptions.
  - Skills: the request named none, so none were loaded.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

These findings cover only Required Change 5 and what its edit touches.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

None that require an edit. One cosmetic note: the Flow & State Gaps bullet (design l.237) reads "inherited text colour inside `Scaffold` the 167ms blend of text-field borders and labels", with no comma after `Scaffold`. The meaning is still clear from the list that follows, so no change is required, and an edit for this alone would void the verdict.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **Menu hover moves focus (M-1, round 4). Status: applied correctly** (confirmed in the round-4 re-check; design l.45, proposal l.20).
2. **Chip focus-ring tween and hover fade (M-2, round 4). Status: applied correctly.** It was applied as worded in the round-4 re-check. Its narrower wording, "the chip focus ring's 75ms tween", and the "chip selection fade" record have now been replaced by Required Change 5.
3. **Text fields blend on a theme switch (M-3, round 4). Status: applied correctly.** It was applied as worded in the round-4 re-check. The missing chip entry in the same exception list is now added by Required Change 5.
4. **Suggestion S-1 (round 4). Status: applied correctly** (D5 l.69; the qualified "Tab to each control" THEN, spec l.122, was accepted by the reviewer in the round-4 re-check).
5. **Chip shape tween and chip selection record (M-1, S-1 of the round-4 re-check). Status: applied correctly.**
   - The chip shape tween is now described as "chip shape (75ms tween of outline, selected border and focus ring; a fixed Material constant)" in What Changes (proposal l.13) and the DESIGN.md list (l.20). S10 (l.122) and C12 (design l.148) use the recommended wording, "the chip shape's 75ms tween (outline, selected border and focus ring; a fixed Material constant)". The old "chip focus ring's 75ms tween" appears nowhere.
   - The checkmark draw-in is now "chip selection draw-in of the checkmark (195ms; the fill changes on the next frame because `ChipThemeData.color` is set)" in S10 and C12. What Changes and the DESIGN.md list carry the shortened form "chip checkmark draw-in (195ms; the fill changes on the next frame)". The "chip selection fade" wording appears nowhere.
   - The shortened forms say the same thing in the list's grammar, and the reason (`ChipThemeData.color` per state) is recorded in D5 (l.69), S10 and C12. S10 says "All five" and C12 says "Five Material transitions", so the count is unchanged.
   - Spec l.88 carries the recommended exception sentence word for word: "...and chip outlines over Material's 75ms; all three are recorded exceptions." C7 (l.143), the Flow & State Gaps bullet (l.237) and the proposal's DESIGN.md list (l.20) add the 75ms chip-outline blend.
   - The S10 summary row (design l.116, "Field, chip, snackbar, tooltip transitions") still matches, and as recommended it was left unchanged.
   - Consistency check:
     - The theme-switch SHALL ("Surfaces and Ember-styled controls SHALL switch instantly") now lists all three blends that Material keeps. The SDK confirms that the chip's `Material` tweens only shape, elevation, shadow and tint, not colour. The chip fill therefore switches instantly, and "chip outlines" is the complete chip exception.
     - C7, the Flow & State Gaps bullet, the proposal's DESIGN.md list and the spec name the same three exceptions with the same durations (200ms, 167ms, 75ms).
     - The controls requirement (spec l.99, "text-field, chip, snackbar and tooltip transitions are Material's own") covers both chip transitions.
     - The "Documented exceptions" scenario (spec l.113-115, "the chip's fill reach[es] its final Ember colour once Material's transition ends") stays true and assertable. The fill reaches its final colour on the next frame, which is at or before the end of any transition.
     - The "Tab to each control" THEN (spec l.122, "once Material's 75ms ring tween ends") agrees with "the chip shape's 75ms tween (… focus ring …)" and with D2's `lerpFrom`/`lerpTo` (design l.45).
     - The edit adds no new contradiction.

CHANGES_APPLIED: yes

## Rebuttals

Reviewer check of the round-3 items (kept from round 4):

- **M-1 (round 3), snackbar and tooltip motion:** verified fixed.
  - Proposal S10 limits the no-animation rule to buttons, icon buttons and menu items. It records the snackbar transition (250ms) and the tooltip fade (150ms in, 75ms out).
  - The What Changes controls bullet and the last bullet's DESIGN.md list name all four transitions.
  - The spec's controls requirement reads "text-field, chip, snackbar and tooltip transitions are Material's own".
  - C12 names the four transitions. Round 4's M-2 adds a fifth.
- **M-2 (round 3), inherited-text blend:** verified fixed.
  - The spec's theme-switch requirement covers surfaces and Ember-styled controls, and records the 200ms inherited-text blend.
  - C7, the Flow & State Gaps bullet and the proposal's DESIGN.md list match.
  - Round 4's M-3 is the same class of gap in text fields.
- **S-1 (round 3), instant hover and press:** verified applied. D5 adds a transparent overlay with per-state background colours. Round 4's suggestion S-1 adds the missing zero `animationDuration`.
- **S-2 (round 3), menu-ring clipping:** verified applied.
  - D2 and the spec's focus requirement draw the menu-item ring just inside the item's 8px shape (DESIGN.md l.357).
  - The ring is the shape's own border, and `ButtonStyleButton` paints it through its `Material` (`button_style_button.dart` l.602, 608-609). So the scroll view's clip no longer cuts it.
  - Round 4's M-1 is a separate issue: when the ring shows.
- **S-3 (round 3), small fixes:** verified fixed.
  - The Resource Bounds row now reads `flutter_bootstrap.js` and lists `canvaskit/`.
  - Context l.18 says "S1-S11".
  - The proposal's Impact names the `test:ember_ui` task and the `notices.dart` coverage change.

Author responses to round 4 (the owner chose the recommended option for changes 1 and 2):

- **Required change 1 (M-1):** applied as worded in D2 and in the proposal's DESIGN.md list.
- **Required change 2 (M-2):** applied as worded in proposal S10, What Changes and the DESIGN.md list, in design C12 (now five transitions), D2 (`lerpFrom`/`lerpTo`) and D5 (`ChipThemeData.color` per state).
- **Required change 3 (M-3):** applied as worded in the spec's theme-switch requirement, C7, the Flow & State Gaps bullet and the proposal's DESIGN.md list.
- **Required change 4 (S-1):** applied in D5 as worded. In the "Tab to each control" THEN, "on the next frame" covers buttons, icon buttons and menu items. Chips are judged once Material's 75ms ring tween ends, and text fields once their 167ms border transition ends (both recorded exceptions, S10), because applying the wording literally to them would contradict those exceptions. Please confirm this reading in the re-check.

Reviewer confirmation per item (round-4 re-check):

- **Required change 1:** confirmed fixed (design l.45, proposal l.20). No new contradiction.
- **Required change 2:** confirmed applied as worded (proposal l.13, l.20, l.122; design l.45, l.69, l.148). The wording it introduced is narrower than what Material does (M-1) and keeps a fill fade that D5's edit removes (S-1). Both are carried into Required Change 5.
- **Required change 3:** confirmed applied as worded (spec l.88; design l.143, l.237; proposal l.20). Chips are missing from the same exception list (M-1), which is carried into Required Change 5.
- **Required change 4:** confirmed applied, and the author's deviation is accepted by the reviewer. Qualifying chips and text fields by their recorded transitions applies the intent of S-1 and agrees with S10, C12 and the "Documented exceptions" scenario. Literal wording would have contradicted them.

Author response to the round-4 re-check (the owner chose the recommended option):

- **Required change 5:** applied as worded. Proposal S10, What Changes (l.13) and the DESIGN.md list (l.20), and design C12, now say "chip shape 75ms tween (outline, selected border and focus ring)" and "chip checkmark draw-in (195ms; the fill changes on the next frame)". The theme-switch exception in the spec, C7, the Flow & State Gaps bullet and the proposal's DESIGN.md list now name chip outlines (75ms). The count stays at five, and no mechanism changed.

Reviewer confirmation (this re-check):

- **Required change 5:** confirmed applied correctly.
  - S10 (proposal l.122) and C12 (design l.148) carry the recommended wording word for word.
  - What Changes (l.13) and the DESIGN.md list (l.20) carry a shortened form with the same meaning that fits the list's grammar. The `ChipThemeData.color` reason stays recorded in D5, S10 and C12.
  - The spec sentence (l.88) matches exactly, and C7 (l.143), the Flow & State Gaps bullet (l.237) and the proposal's DESIGN.md list (l.20) agree with it.
  - The two spec requirements, C7, C12, S10 and the Flow & State Gaps bullet agree. The SDK confirms that chip outlines are the only chip blend on a theme switch.
  - No new contradiction was found. Required Changes 1-5 are all applied.
