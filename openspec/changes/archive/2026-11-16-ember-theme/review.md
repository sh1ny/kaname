# Review

## Metadata

- **Round:** 5 (re-check of Required Changes)
- **Prior round:** Round 5 reviewed the A5 and task 7.9 amendment (commit 051a28c). It returned APPROVE_WITH_CHANGES with Required Changes 1-3 outstanding (M-1: the condition for bundling Roboto; M-2: glyphs that Roboto covers). The owner chose to apply them as worded, in commits ab2efd2 (design.md A5 and Risks, proposal.md What Changes, review.md) and 88e2882 (specs/ember-ui/spec.md scenario WHEN line).
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - This re-check: `git show ab2efd2 88e2882`; design.md A5 (l.132), Risks (l.257), Failure & Visibility (l.219) and Mechanism Ledger (l.249); proposal.md l.11, l.18 and S4 (l.72-78); specs/ember-ui/spec.md l.40 and l.50-63; tasks.md l.19-20 and l.104; the committed review.md (round 5); `openspec validate ember-theme --strict` (valid). `git diff 051a28c 88e2882 --stat` shows that only these four files changed.
  - Round 5, kept for reference:
    - the amendment diff (`git show 051a28c`);
    - design.md A1, S4/D6, C6, C10, Resource Bounds, Failure & Visibility, Mechanism Ledger and Risks;
    - proposal.md What Changes, Capabilities, Impact and S4;
    - both spec deltas, tasks.md group 7 and evidence/web-requests.md;
    - in the work tree, `app/web/flutter_bootstrap.js`, `deploy/Caddyfile` and `server/kaname_client/test/stack/stack_test.dart`.
  - The installed Flutter 3.47.9 SDK, which lies outside the repository. It is evidence for this check, not a design citation:
    - `flutter_tools` `build_system/targets/web.dart` l.39-40, l.654, l.701-753 and l.818;
    - engine `font_fallbacks.dart` l.41-59 and `canvaskit/text.dart` l.1255-1266.
  - A cmap comparison of Roboto-Regular.ttf with Geist and Literata, done in round 5.
  - Skills: the request named none, so none were loaded.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

These are round 5's findings. Their status after the re-check is given under Required Changes and Rebuttals.

### Critical (blocking)

None.

### Moderate

- **M-1 (round 5): A5 states the Roboto bundling without its condition.** `_bundleLocalRobotoFallback` bundles Roboto only when `useLocalCanvasKit` is `'true'`, and skips it when the app already declares a `Roboto` family (`web.dart` l.701-718). Without the local engine, the engine's global fallback list still starts with `Roboto` (`font_fallbacks.dart` l.41). So A5's "requests nothing from `/font-fallback/`" depends on C6's flag. **Status: fixed (Required Change 1).**
- **M-2 (round 5): some text still said every glyph outside Geist and Literata shows as a box.** The engine appends its global fallbacks, Roboto included, to every paragraph's families (`canvaskit/text.dart` l.1264). 174 code points that Roboto covers and neither Geist nor Literata does render in Roboto, for example U+017F, U+03D1 and U+0460-U+04A8. That made three places inaccurate: the spec scenario WHEN, proposal What Changes and the design Risks bullet. **Status: fixed (Required Changes 2 and 3).**

### Suggestions

- **S-1 (round 5):** A5's "a start-up with only covered text requests nothing from `/font-fallback/`" is inferred from a run that rendered 要, not observed in a run without it. Not applied, by the owner's choice. That is acceptable, because the sentence now gives its reason ("therefore") and no requirement depends on it.
- **S-2 (round 5):** Reorder task 7.9 so that the CJK character is rendered before its requests are mentioned. Not applied, by the owner's choice. The wording is still assertable, and the evidence meets every clause.
- **S-3 (round 5):** The stale "the engine asks for Roboto there on every start-up" comment in `stack_test.dart` l.185-186 (uncommitted). The author says it will be fixed in the group 7 commit. That is an implementation edit, outside this verdict.
- **S-4 (round 5):** The Resource Bounds row and T5 count three font files. The web build also ships Flutter's Roboto (about 170 KB). Not applied, by the owner's choice. It is acceptable because the extra file is fixed per Flutter version and is now named in A5, the proposal and Risks.
- **S-5 (this re-check, no edit required):** The Mechanism Ledger's "Self-hosted Noto fallback fonts" row (design l.249) still names "glyphs outside Geist and Literata" as the evidence that would change the call. As a trigger for reconsidering the decision, this is harmless: a glyph that Roboto covers does not show as a box, so no user would report it. It does not conflict with the corrected scenario. If the line is touched for another reason, "outside the fonts the web build ships" would match the rest of the text.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **A5 (design l.132), M-1. Status: applied exactly.**
   - The sentence beginning "Roboto is not among those requests: Flutter 3.47.9's release web build bundles it…" is replaced word for word with the required text. That text covers the local-engine condition (`--no-web-resources-cdn`, kept by C6), the exception for an app-declared `Roboto` family, the `web.dart` lines 701-753 citation, "A start-up with only covered text therefore requests nothing from `/font-fallback/`", and the sentence on characters Roboto covers rendering in Roboto.
   - The rest of A5 (the round-2 history, the evidence summary, "Depends on it: S4, D6" and the evidence task's assertion) is unchanged, as required.
2. **Spec scenario "A glyph no bundled font covers" (specs/ember-ui/spec.md l.62), M-2. Status: applied exactly.**
   - The WHEN line now reads, word for word, "the web app renders a character that no font in the web build covers (neither Geist, Literata, nor the Roboto fallback Flutter bundles with the local engine), such as a CJK character".
   - The THEN line is unchanged. The commit records the amendment as a clarification, which fits: neither the code nor the evidence changes behaviour.
3. **Proposal What Changes (l.18) and design Risks (l.257), M-2. Status: applied exactly.**
   - The proposal reads "Glyphs outside Geist, Literata and Flutter's bundled Roboto fallback (CJK, emoji) show as empty boxes on web."
   - The Risks bullet reads "[Glyphs outside Geist, Literata and Flutter's bundled Roboto (CJK, emoji) show as boxes on web]".

Consistency check after the edits:
- **S4:** S4 (proposal l.74, "Glyphs outside the bundled fonts") now agrees with What Changes, Risks, A5 and the scenario, because all of them count Roboto among the fonts the web build ships.
- **Fonts requirement:** the requirement at spec l.40 ("The app SHALL NOT fetch a font from any host other than its own") holds. The evidence shows Roboto served from `/assets/fonts/fallback/` on the app's own origin.
- **C6 and C10:** C6 is now the stated precondition of A5's Roboto claim, and it is already an invariant enforced by `webbuild --check`. C10 is untouched.
- **Failure & Visibility and the test matrix:** the Failure & Visibility row (l.219) and the test-matrix row for the scenario (tasks l.19) still match. The scenario title is unchanged, and the CJK character used in 7.9 is covered by no font in the build.
- **Spec validation:** `openspec validate ember-theme --strict` passes.
- **Result:** no new contradiction was found.

CHANGES_APPLIED: yes

## Rebuttals

Prior rounds, in brief:
- Rounds 1-4 settled S4 and D6, which moved fallback fonts to an own-origin path with a Caddy 404 after round 1's C-1.
- Round 4 and its re-check settled the focus, transition and theme-switch exceptions, with Required Changes 1-5 confirmed applied.
- Round 5 found that the amended A5 was right on the evidence but missing the local-engine condition (M-1). It also found that the "outside Geist and Literata → box" text was false for glyphs Roboto covers (M-2).

Author response to round 5 (the owner chose to apply Required Changes 1-3 as worded):
- **Required change 1:** applied in design A5 (commit ab2efd2).
- **Required change 2:** applied in the spec scenario WHEN line (commit 88e2882, marked as a clarification amendment).
- **Required change 3:** applied in proposal What Changes and the design's Risks bullet (commit ab2efd2).
- **Suggestions:** S-3 will be fixed in the group 7 commit. S-1, S-2 and S-4 were not applied.

Reviewer confirmation (this re-check):
- **Required change 1:** confirmed applied exactly (design l.132). No new contradiction.
- **Required change 2:** confirmed applied exactly (spec l.62). The THEN line is unchanged, and strict validation passes.
- **Required change 3:** confirmed applied exactly (proposal l.18, design l.257). It agrees with S4, A5 and the scenario.
- **Unapplied suggestions:** declining S-1, S-2 and S-4 is accepted by the reviewer. None of them carries a Critical or Moderate consequence, and S-3 lies outside the artifacts this verdict covers.
- **Result:** Required Changes 1-3 are all applied.
