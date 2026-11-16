# Review

## Metadata

- **Round:** 5 (re-review of an amendment made during apply)
- **Prior round:** Round 4's re-check confirmed Required Changes 1-5 applied and marked them applied on its APPROVE_WITH_CHANGES verdict. Commit 051a28c then amended design A5 and task 7.9 after the group 7 browser run, which voided that verdict for the amended text. This round supersedes it.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - The amendment diff (`git show 051a28c`): design.md A5 (l.132) and tasks.md 7.9 (l.104).
  - design.md: A1 (l.129), S4/D6 (l.75-85, summary rows l.110 and l.123), C6 (l.142), C10 (l.146), Resource Bounds (l.227), Failure & Visibility (l.219), Mechanism Ledger (l.247-249), Risks (l.257).
  - proposal.md: What Changes (l.18), Capabilities (l.30), Impact (l.38) and S4 (l.72-78).
  - specs/ember-ui/spec.md, requirement "The web build loads no engine or font files from third-party hosts" (l.50-63). specs/self-host-stack/spec.md in full.
  - tasks.md: test matrix rows l.17-19 and group 7 (l.96-104).
  - evidence/web-requests.md (untracked, the 2026-11-16 run).
  - review.md (round 4 and its re-check) and the template `openspec/schemas/specwright/templates/review.md`.
  - For reference, the implementation in the work tree, which is not yet committed: `app/web/flutter_bootstrap.js` (untracked), `deploy/Caddyfile` (modified, the `@fontFallback` rule) and `server/kaname_client/test/stack/stack_test.dart` (modified, l.179-198).
  - The installed Flutter 3.47.9 SDK, which lies outside the repository. It is evidence for this check, not a design citation:
    - `packages/flutter_tools/lib/src/build_system/targets/web.dart` l.39-40, l.654 and l.701-753 (`_bundleLocalRobotoFallback`), and l.818 (`useLocalCanvasKit`).
    - engine `lib/web_ui/lib/src/engine/font_fallbacks.dart` l.41-59 (`globalFontFallbacks = ['Roboto']`).
    - engine `lib/web_ui/lib/src/engine/canvaskit/text.dart` l.1255-1266 (`_computeCombinedFontFamilies` appends the global fallbacks to every paragraph's families).
  - A cmap comparison of the engine's `txt/third_party/fonts/Roboto-Regular.ttf` (171,676 B) with the package's `Geist[wght].ttf` and `Literata[opsz,wght].ttf`. It was done with a stdlib script in a scratch directory.
  - Skills: the request named none, so none were loaded.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

The amended A5 matches the evidence:
- The run made 19 requests, all to `http://localhost`.
- Roboto was served as `200 /assets/fonts/fallback/Roboto-Regular.ttf`.
- Rendering 要 made five Noto Sans SC/TC/HK/JP/KR requests under `/font-fallback/`, and each got 404 with a plain-text body.
- The glyph showed as an empty box.

The amendment does not contradict S4, D6, C6 or C10:
- The bootstrap sets `fontFallbackBaseUrl: "/font-fallback/"`.
- The Caddy rule answers `/font-fallback` and `/font-fallback/*` with 404 ahead of the single-page-app fallback.
- The `webbuild` check still enforces both settings.

The Failure & Visibility row (a 404 on the own origin, an empty box and a console warning) and the Mechanism Ledger's Caddy row still hold. The evidence shows the `console.warn` lines and the Noto requests the Caddy rule exists for. No artifact other than A5 said that Roboto returns 404 at start-up. The two findings below come from what the corrected behaviour reveals, not from the edit's wording itself.

### Critical (blocking)

None.

### Moderate

- **M-1: A5 states the Roboto bundling without its condition.** A5 says that "Flutter 3.47.9's release web build bundles it as `assets/fonts/fallback/Roboto-Regular.ttf`". The SDK does this only when the build uses the local engine. `_bundleLocalRobotoFallback` returns at once unless `useLocalCanvasKit` is `'true'` (`web.dart` l.701-704). It also skips the copy when the app's font manifest already declares a family named `Roboto` (l.713-718).

  Without `--no-web-resources-cdn`, the engine still puts `Roboto` first in its global fallback list (`font_fallbacks.dart` l.41). It would then request Roboto from the fallback address, which is the round-2 reading. So A5's "requests nothing from `/font-fallback/`" depends on C6's flag, and A5 does not say so. As worded, it presents a flag-dependent outcome as a property of every release build. Its "Depends on it" line also omits the link a future Flutter bump or flag change would break.

- **M-2: the spec scenario, proposal and Risks still say every glyph outside Geist and Literata shows as a box. Roboto now covers some of them.** Because Roboto is bundled and registered, the engine adds it to every paragraph's family list (`canvaskit/text.dart` l.1264). A character that Roboto covers renders in Roboto, not as an empty box.

  The cmap comparison finds 174 code points above U+0020 that Roboto covers and neither Geist nor Literata does. Examples are U+017F ſ, U+03D1 ϑ, U+03D6 ϖ and the historic Cyrillic letters U+0460-U+04A8.

  The following text is therefore now wrong for those characters:
  - The spec scenario "A glyph no bundled font covers" (spec l.61-63, WHEN "a character that neither Geist nor Literata covers", THEN "shows as an empty box").
  - Proposal What Changes (l.18, "Glyphs outside Geist and Literata (CJK, emoji) show as empty boxes on web").
  - The design's Risks bullet (l.257).

  The 7.9 evidence used a CJK character, which no loaded font covers, so it passes. But the main spec this archives into would state a behaviour that is false for a known set of characters. S4's own wording, "Glyphs outside the bundled fonts" (proposal l.74), is correct once Roboto counts as bundled, so S4 needs no edit.

### Suggestions

- **S-1: the claim about a start-up with only covered text is inferred, not observed.** A5 says that "a start-up with only covered text requests nothing from `/font-fallback/`". The only run rendered 要, so this is inferred from the fact that every `/font-fallback/` request in that run was a CJK family. The inference is sound given the SDK, but nothing in 7.9 records it. Either add "(inferred: every fallback request in the run was for 要)", or have 7.9 also record a load of the unmodified placeholder with no `/font-fallback/` request. Neither is required, because no requirement depends on that claim.
- **S-2: reorder task 7.9.** It refers to "the CJK character's `/font-fallback/` requests" before the clause that says to render one. Reordering it would read more clearly, for example: "...all must be on the app's own origin; render one CJK character, note it shows as an empty box, and that its `/font-fallback/` requests get 404 with no request to another host". The current wording is still assertable, and the evidence meets every clause. tasks.md is outside the verdict's void rule.
- **S-3: stale comment in the uncommitted stack test.** `stack_test.dart` l.185-186 says "the engine asks for Roboto there on every start-up". That is the round-2 belief A5 has now dropped. Reword it when committing group 7, for example: "the engine asks there for fonts covering glyphs no loaded font has". The sample path `/font-fallback/roboto/v32/...` is still a valid probe. The self-host-stack scenario's example path `roboto/v1/x.woff2` is also fine as an arbitrary file under the path and needs no edit.
- **S-4: font counts leave out Roboto on web.** The Resource Bounds row ("About 2 MB (3 files)", design l.227) and T5 ("3 font files", l.11) count the package's fonts. The web build also ships Flutter's Roboto-Regular.ttf (about 170 KB), which comes from the SDK, not the repository. A clause noting this would keep the bounds honest. It is optional, because the extra file is fixed per Flutter version.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **A5 (design l.132), M-1.** Replace the sentence "Roboto is not among those requests: Flutter 3.47.9's release web build bundles it as `assets/fonts/fallback/Roboto-Regular.ttf` and the app loads it from its own origin, so a start-up with only covered text requests nothing from `/font-fallback/`." with:

   "Roboto is not among those requests: when the build uses the local engine (`--no-web-resources-cdn`, kept by C6), Flutter 3.47.9 bundles Roboto as `assets/fonts/fallback/Roboto-Regular.ttf` unless the app already declares a `Roboto` family (`flutter_tools` `build_system/targets/web.dart` lines 701-753, outside the repository), and the app loads it from its own origin. A start-up with only covered text therefore requests nothing from `/font-fallback/`. Because the engine appends its fallback list to every paragraph's families, characters Roboto covers render in Roboto rather than as a box."

   Leave the rest of A5 unchanged.

2. **Spec scenario "A glyph no bundled font covers" (specs/ember-ui/spec.md l.62), M-2.** Replace the WHEN line with:

   "- **WHEN** the web app renders a character that no font in the web build covers (neither Geist, Literata, nor the Roboto fallback Flutter bundles with the local engine), such as a CJK character"

   Keep the THEN line unchanged.

3. **Proposal What Changes (proposal.md l.18) and design Risks (design.md l.257), M-2.**
   - In the proposal, change "Glyphs outside Geist and Literata (CJK, emoji) show as empty boxes on web." to "Glyphs outside Geist, Literata and Flutter's bundled Roboto fallback (CJK, emoji) show as empty boxes on web."
   - In the Risks bullet, change "[Glyphs outside Geist and Literata (CJK, emoji) show as boxes on web]" to "[Glyphs outside Geist, Literata and Flutter's bundled Roboto (CJK, emoji) show as boxes on web]".

CHANGES_APPLIED: no

## Rebuttals

Prior rounds, in brief:
- Rounds 1-4 settled S4 and D6, which moved fallback fonts to an own-origin path with a Caddy 404 after round 1's C-1.
- Round 2 contributed the reading of `font_fallbacks.dart` that A5 originally recorded, which said Roboto returns 404 at every start-up.
- Round 4 and its re-check settled the focus, transition and theme-switch exceptions, with Required Changes 1-5 confirmed applied.

None of those outcomes is reopened here. This round covers only the A5 and task 7.9 amendment and what the observed behaviour makes stale.

The round-2 reading of `font_fallbacks.dart` was correct about the engine's list. The engine does start `globalFontFallbacks` with `Roboto`. What it missed is the flutter_tools step, which registers a bundled Roboto whenever the engine is local. The amendment's correction is right, and Required Change 1 only adds the condition that makes it true.
