# Tasks

## Test map

Package tests live in `app_packages/kaname_ember_ui/test/` (shortened to `ember_ui/test/` below); tool tests in `tools/kaname_tools/test/`.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| ember-ui → Tokens are generated from the brand source | Generated tokens are current | tools/kaname_tools/test/tokens_repo_test.dart | committed generated tokens match brand/tokens.json | green |
| ember-ui → Tokens are generated from the brand source | Tokens edited without regenerating | tools/kaname_tools/test/tokens_test.dart | check names the stale generated file and says to run the generator | green |
| ember-ui → Tokens are generated from the brand source | Generated file edited by hand | tools/kaname_tools/test/tokens_test.dart | check names a hand-edited generated file | green |
| ember-ui → Every colour role exists in both rooms | Both rooms carry every role | ember_ui/test/theme_test.dart | dark and light themes expose every colour role in tokens.json | green |
| ember-ui → Every colour role exists in both rooms | A role without a light value | tools/kaname_tools/test/tokens_test.dart | a role without a light value fails naming role and room and writes nothing | green |
| ember-ui → Every colour role exists in both rooms | An unparseable colour | tools/kaname_tools/test/tokens_test.dart | an unparseable colour fails naming role and value and writes nothing | green |
| ember-ui → Fonts are bundled and never fetched from another host | Type styles use bundled families | ember_ui/test/fonts_test.dart | every type style names a font family the package declares | green |
| ember-ui → Fonts are bundled and never fetched from another host | A font asset is missing | ember_ui/test/fonts_test.dart | loading fonts with a declared file missing fails naming the file | green |
| ember-ui → The web build loads no engine or font files from third-party hosts | Self-contained web build | tools/kaname_tools/test/webbuild_test.dart | self-contained build passes the check | red |
| ember-ui → The web build loads no engine or font files from third-party hosts | A build that depends on the CDN | tools/kaname_tools/test/webbuild_test.dart | build without local engine, wasm or own-origin fallback fails naming what it found | red |
| ember-ui → The web build loads no engine or font files from third-party hosts | A glyph no bundled font covers | n/a: mechanical check, evidence/web-requests.md (task 7.9) | n/a: needs a real browser and network log; the capture script lists every request's origin | n/a |
| ember-ui → Font licences ship with the app | Licence page lists the fonts | ember_ui/test/licences_test.dart | licence entries hold full OFL text for Geist and Literata | green |
| ember-ui → Font licences ship with the app | A licence text is missing | ember_ui/test/licences_test.dart | a missing licence file fails naming family and file | green |
| ember-ui → The package provides a dark and a light theme | Themes in both rooms | ember_ui/test/theme_test.dart | a widget reads dark roles under dark and light roles under light | green |
| ember-ui → The package provides a dark and a light theme | Roles read without the Ember theme | ember_ui/test/theme_test.dart | reading Ember roles under a non-Ember theme throws "Ember theme is not installed" | green |
| ember-ui → The app follows the system theme until the user chooses | Dark system setting | app/test/app_test.dart | dark platform brightness renders the Ember dark canvas | red |
| ember-ui → The app follows the system theme until the user chooses | System setting changes while running | app/test/app_test.dart | brightness change shows the light canvas on the next frame | red |
| ember-ui → Material controls take Ember's shapes and states | Specimen matches the goldens | ember_ui/test/golden_test.dart | control specimen matches its golden in dark and light | green |
| ember-ui → Material controls take Ember's shapes and states | A styling change alters a control | n/a: mechanical check, evidence/golden-failure.txt (task 5.10) | n/a: flutter_test's golden comparator reports the differing file; recorded once by altering a radius locally | n/a |
| ember-ui → Material controls take Ember's shapes and states | No state animation | ember_ui/test/states_test.dart | buttons, icon buttons and menu items paint no splash and change state on the next frame | green |
| ember-ui → Material controls take Ember's shapes and states | Documented exceptions | ember_ui/test/states_test.dart | text field border and chip fill reach Ember colours after Material's transition, no splash | green |
| ember-ui → Keyboard focus is always visible | Tab to each control | ember_ui/test/focus_test.dart | tab to each control paints its Focus indicator in both themes | green |
| ember-ui → Keyboard focus is always visible | Focus leaves a control | ember_ui/test/focus_test.dart | focus leaving a control removes its indicator | green |
| ember-ui → Keyboard focus is always visible | A control without a focus indicator | ember_ui/test/focus_test.dart | focus check fails naming control and theme for an unstyled control | green |
| ember-ui → Token colours meet WCAG contrast | Current tokens pass | ember_ui/test/contrast_test.dart | every listed pair meets its threshold in both rooms | green |
| ember-ui → Token colours meet WCAG contrast | A token edit lowers contrast | ember_ui/test/contrast_test.dart | a lowered pair fails naming theme, roles, measured and required ratio | green |
| ember-ui → Token colours meet WCAG contrast | Ember fills are exempt from the surface bar | ember_ui/test/contrast_test.dart | an Ember fill below 3:1 on a surface is not a failure | green |
| workspace-layout → Packages follow the placement and naming rule | Current packages comply | tools/kaname_tools/test/workspace_test.dart | current layout reports app, ember_ui, core, tools, server and client and exits 0 | green |
| workspace-layout → Packages follow the placement and naming rule | A misplaced or misnamed package | tools/kaname_tools/test/workspace_test.dart | missing prefix or directory mismatch fails with rule | green |
| third-party-notices → Vendored assets are listed by hand | Current vendored assets listed | tools/kaname_tools/test/notices_repo_test.dart | repository notices cover every vendored source | green |
| third-party-notices → Vendored assets are listed by hand | A vendored source without an entry | tools/kaname_tools/test/notices_test.dart | check names an OFL file under app_packages missing from the hand-written sections | green |
| self-host-stack → The fallback-font path never serves the web app | Fallback font requested | server/kaname_client/test/stack/stack_test.dart | Given the stack when a fallback font is requested then Caddy answers 404 and not index.html | red |
| self-host-stack → The fallback-font path never serves the web app | Ordinary app route still falls back | server/kaname_client/test/stack/stack_test.dart | Given the stack when an app route without a file is requested then index.html is served | red |

## 1. Package scaffold

- [x] 1.1 Update the "current layout" test in `workspace_test.dart` to expect `kaname_ember_ui` at `app_packages/kaname_ember_ui/`; run `mise run test:tools` and confirm it fails because the package does not exist.
- [x] 1.2 Create `app_packages/kaname_ember_ui/` (Flutter package: `pubspec.yaml` with `resolution: workspace`, `analysis_options.yaml` with `public_member_api_docs` as in `packages/kaname_core`, `lib/kaname_ember_ui.dart`, `README.md`), list it in the root `pubspec.yaml` workspace, run `mise run resolve`; verify `mise run workspace` exits 0 and the 1.1 test is green (flip its row).
- [x] 1.3 Add a `test:ember_ui` mise task (`flutter test` in the package) to `test`; re-run the unchanged "missing prefix or directory mismatch" test (row stays green); verify `mise run test` runs the new task.
- [x] 1.4 Run `mise run notices` (the lockfile changed) and verify `mise run notices:check` exits 0.

## 2. Token generator and the ink-tertiary edit

- [x] 2.1 Write failing tests in `tools/kaname_tools/test/tokens_test.dart` (in-memory file system fixture) for: stale generated file named with the "run the generator" hint; hand-edited generated file named; role without a light value fails naming role and room and writes nothing; unparseable colour fails naming role and value and writes nothing; mono stack and style skipped; a style naming an unbundled family fails. Verify they fail because the `tokens` command does not exist.
- [x] 2.2 Implement `kaname_tools tokens --write/--check` (D1; sealed parse result, no `dynamic`, typed colour parsing of `#rrggbb` and `rgba(...)`, whole-file render then one write, formatter output form, doc comment on every generated public member), registered in `cli.dart`; verify the 2.1 tests pass and flip their rows green.
- [x] 2.3 Change `ink-tertiary` in `brand/tokens.json` to dark `#918d86`, light `#635e55` (S7); rerun `mise exec -- node brand/tools/build.mjs`; verify `git diff --stat brand/` shows only `tokens.json`, `tokens.css` and `brand/flutter/ember_tokens.dart`.
- [x] 2.4 Add mise tasks `tokens` (`--write`) and `tokens:check` (`--check`), with `tokens:check` in `check`; run `mise run tokens` to write `app_packages/kaname_ember_ui/lib/src/generated/ember_tokens.dart`, carrying C9 in the `EmberType` doc comment ("no mono type style; the first code or source view adds a bundled mono font and its style, never the system stack"); verify `mise run tokens:check` exits 0 and the file analyzes clean.
- [x] 2.5 Write `tools/kaname_tools/test/tokens_repo_test.dart` (committed generated tokens match `brand/tokens.json`, and a second write changes nothing); verify it passes and flip its row green.
- [x] 2.6 DESIGN.md: set the `ink-tertiary` frontmatter colours to the new values, and add to "What Kaname changes" the `ink-tertiary` edit (S7, with the 4.5:1 on Hover and Press reason) and the missing `mono` style (S9); verify `grep -n 918d86 DESIGN.md` and the section text.

## 3. Fonts, licences and notices

- [x] 3.1 Verify A4: confirm the three files exist at google/fonts commit `4e5f06dbb274a27ebe71ed54ea706b3ee40eabd9` with the listed sizes (GitHub contents API); if Geist's latest commit differs, pin the commit actually downloaded from and record it.
- [x] 3.2 Download `Geist[wght].ttf`, `Literata[opsz,wght].ttf`, `Literata-Italic[opsz,wght].ttf` and both `OFL.txt` (saved as `OFL-geist.txt`, `OFL-literata.txt`) unmodified into `app_packages/kaname_ember_ui/fonts/`; write `fonts/PROVENANCE.md` with commit, source paths and SHA-256 of each file; verify with `sha256sum` against PROVENANCE.md.
- [x] 3.3 Write failing tests: `fonts_test.dart` (every type style names a declared package family and no system family such as `ui-monospace`; loading fonts with a declared file missing fails naming the file) and `licences_test.dart` (licence entries for Geist and Literata hold the full OFL-1.1 text with each family's copyright line; a missing licence file fails naming family and file). Verify they fail for the right reason.
- [x] 3.4 Declare the families in the package pubspec and the OFL texts as assets; implement `EmberFonts` (`lib/src/fonts.dart`) with `registerLicences()` and the D8 test font loader (injectable asset source, so a missing file is testable), carrying C5 in the `EmberFonts` doc comment; verify the 3.3 tests pass and flip their rows green.
- [x] 3.5 Write a failing `notices_test.dart` case: an `OFL-*.txt` under a package in `app_packages/` that the hand-written sections do not name makes `notices --check` fail naming it; then extend `notices.dart` font-licence coverage to `app_packages/*/` and verify the case passes (flip its row green).
- [x] 3.6 Add the package's licence paths to the Geist and Literata entries in `THIRD_PARTY_NOTICES`; verify `notices_repo_test.dart` and `mise run notices:check` pass and flip its row green.

## 4. Themes, colours and contrast

- [x] 4.1 Write failing `contrast_test.dart` (every text role ink, ink secondary, ink tertiary, prose, accent text at 4.5:1 on canvas, panel, raised, hover and press; text on Ember, warning and error fills at 4.5:1; Focus at 3:1 on every surface; translucent colours composited over canvas; a lowered pair fails naming theme, roles, measured and required ratios; an Ember fill below 3:1 on a surface is not a failure). Verify the failure is the missing contrast helper, not a wrong value.
- [x] 4.2 Implement the WCAG contrast helper used by the test (pure Dart, compositing over canvas); verify `contrast_test.dart` passes on the current tokens and flip its three rows green. C3: confirm the exemption sentence is in the spec's "Token colours meet WCAG contrast" requirement.
- [x] 4.3 Write failing `theme_test.dart`: dark and light themes expose every colour role in `brand/tokens.json` with that room's value; a widget reads dark roles under dark and light roles under light; reading Ember roles under a non-Ember theme throws an error whose message says "Ember theme is not installed". Verify failure reasons.
- [x] 4.4 Copy `brand/flutter/ember_theme.dart` to `lib/src/ember_theme.dart` (D5) with the library doc comment "Adapted from the owner's Ember kit, `brand/flutter/ember_theme.dart`." (C8); point it at the generated tokens; add `EmberColors.of(context)` with the not-installed error; apply D7 (`opsz` equal to size for serif styles, explicit `wght` on every style); add C11 and C13 to the `EmberTheme` doc comment; export from the library; verify the 4.3 tests pass, flip their rows green, and `mise run analyze` is clean.

## 5. Controls, states, focus and goldens

- [x] 5.1 Write failing `focus_test.dart`: tabbing to each styled control (default, primary and quiet buttons, icon button, chip, text field, menu item) in both themes paints the 2px Focus outline 2px outside buttons, icon buttons and chips (chips after the 75ms ring tween), just inside menu items, and a Focus border with the Ember Glow halo on text fields (after the 167ms transition); focus leaving a control removes its indicator; the focus checker fails naming control and theme for an unstyled control. Verify failure reasons.
- [x] 5.2 Implement the focus-ring `OutlinedBorder` (stadium and rounded rectangle, outside and inside variants, `lerpFrom`/`lerpTo`) and resolve every control theme's shape through widget states (D2); text fields get the Focus-coloured border plus halo; menu items take the inside ring whenever focused; verify `focus_test.dart` passes and flip its three rows green. C2: confirm the spec's "Keyboard focus is always visible" requirement carries the rule.
- [x] 5.3 Write failing `states_test.dart`: pressing then hovering a styled button, icon button and menu item paints no splash and shows the pressed and hovered colours on the next frame; a focused text field's border and a selected chip's fill reach their Ember colours once Material's transition ends, with no splash. Verify failure reasons.
- [x] 5.4 Style buttons (default, primary, quiet), icon buttons and menu items with a transparent overlay, per-state background colours and `animationDuration: Duration.zero`; chips with `ChipThemeData.color` per state (transparent hover); no splash factory anywhere; text fields, tooltips and snackbars to Ember sizes, shapes and colours; verify `states_test.dart` passes and flip its two rows green. C12: confirm the spec's "Material controls take Ember's shapes and states" requirement lists the five exceptions.
- [x] 5.5 Write `golden_test.dart`: a control specimen (every styled control at rest, selected and disabled where applicable) in the dark and the light theme with bundled fonts loaded (D8); skipped on Windows and macOS with the reason "goldens are rendered on Linux" (D3); C4 in the `main` doc comment. Run without goldens and verify it fails for missing images.
- [x] 5.6 Verify A2: render a Geist label at weights 400 and 600 in a golden-test scratch run and confirm the glyphs differ; if they do not, stop (design drift for D7).
- [x] 5.7 Generate the goldens on Linux (`flutter test --update-goldens` in the package), inspect both images for pills, soft corners, real fonts and readable colours; verify `golden_test.dart` passes and flip its row green.
- [x] 5.8 Resolve the design's Open Question from the goldens: note in the `EmberTheme` doc comment which `ColorScheme` slots the icon button reads for selected and hovered states, if the theme had to set them explicitly.
- [x] 5.9 DESIGN.md "What Kaname changes": add the text-field Focus border (light Ember 2.76:1 on Raised), the inside menu-item ring and the ring on a pointer-hovered menu item (D2), the five transition exceptions (text-field border 167ms with the 15ms hover fade, chip checkmark draw-in 195ms with the fill on the next frame, chip shape 75ms tween of outline, selected border and focus ring, snackbar 250ms, tooltip 150ms in and 75ms out; S10, C12) and the light empty-field edge gap (S11, C13); verify by reading the section.
- [x] 5.10 [evidence] Alter one control radius locally, run `golden_test.dart`, save the failure output naming the specimen and theme, then revert the edit (`git diff` empty for the package) → evidence/golden-failure.txt

## 6. App wiring

- [ ] 6.1 Write failing tests in `app/test/app_test.dart`: with platform brightness dark the app renders the Ember dark canvas colour; changing platform brightness to light shows the Ember light canvas on the next frame with no intermediate colour. Verify failure reasons.
- [ ] 6.2 Verify A3 while wiring: add `kaname_ember_ui` to the app, give `MaterialApp` `theme: EmberTheme.light()`, `darkTheme: EmberTheme.dark()`, `themeMode: ThemeMode.system` and `themeAnimationDuration: Duration.zero`, call `EmberFonts.registerLicences()` in `main`; verify the 6.1 tests and the existing "Kaname" test pass, flip the rows green, and confirm a Linux desktop or web debug build bundles `packages/kaname_ember_ui/fonts/` (A3). C7: confirm the spec's "The app follows the system theme until the user chooses" requirement carries the instant switch and the three blends.
- [ ] 6.3 DESIGN.md "What Kaname changes": record Material's 200ms blend of inherited text colour, 167ms blend of text-field borders and labels and 75ms blend of chip outlines on a theme switch; verify by reading the section.

## 7. Web build, check and Caddy

- [ ] 7.1 Verify A1: run `mise exec -C app -- flutter build web --release --no-web-resources-cdn` once and record that the emitted `flutter_bootstrap.js` sets `useLocalCanvasKit: true` and `canvaskit/` holds `.wasm` files; if not, stop (design drift for S4/D6).
- [ ] 7.2 Write failing `tools/kaname_tools/test/webbuild_test.dart` (in-memory fixtures): a self-contained build passes; missing `useLocalCanvasKit`, no `.wasm` in `canvaskit/`, missing `fontFallbackBaseUrl` and a foreign `fontFallbackBaseUrl` each fail naming what is missing or the address found. Verify failure reasons.
- [ ] 7.3 Implement `kaname_tools webbuild --check <dir>` (D6) and register it in `cli.dart`; verify the 7.2 tests pass and flip both rows green. C6: confirm the spec's web build requirement carries the invariant.
- [ ] 7.4 Add `app/web/flutter_bootstrap.js` loading the engine with `fontFallbackBaseUrl: "/font-fallback/"`; add `--no-web-resources-cdn` to `build:web` and a `webbuild:check` mise task on `app/build/web`, run by `build:web` after its build; verify `mise run build:web` builds and passes the check.
- [ ] 7.5 CI: add `--no-web-resources-cdn` to the web matrix build command (`.github/workflows/ci.yml:77`) and a web-only step running `mise run webbuild:check` after it; update `ci_workflow_test.dart` if it asserts the web command; verify `mise run test:tools` passes.
- [ ] 7.6 Write the two failing stack tests in `stack_test.dart` (fallback font request answered 404 with a body that is not `index.html`; an app route without a file still gets `index.html`); run `mise run stack:up` and `mise run stack:test` and verify the 404 test fails (the route test may already pass).
- [ ] 7.7 Add a `/font-fallback/*` 404 rule ahead of the SPA fallback in `deploy/Caddyfile`, with a comment that the path must match `app/web/flutter_bootstrap.js` (C10); verify both stack tests pass after `mise run stack:up` and flip their rows green. C10: confirm the self-host-stack requirement carries the invariant.
- [ ] 7.8 Verify `mise run stack:up` runs `webbuild:check` through `build:web`; then `mise run stack:down`.
- [ ] 7.9 [evidence] Verify A5: serve the built web app through the stack, load it in a headless browser, record every request URL and status; all must be on the app's own origin, with the expected `/font-fallback/` Roboto 404; render one CJK character and note it shows as an empty box with no request to another host → evidence/web-requests.md

## 8. Integration

- [ ] 8.1 C1: confirm the spec's "Tokens are generated from the brand source" requirement carries the never-edit-by-hand rule, and that the generated file's header says so.
- [ ] 8.2 Run `mise run check` and `mise run spec:validate`; both exit 0.
- [ ] 8.3 Confirm every Test map row is green or n/a with its evidence committed.

## Workflow follow-up

- The user-verified M0 look criterion (Windows desktop, web and a phone) is judged at the milestone close after `app-shell`; this change adds no `[user]` task for it (proposal, Why).
- Pre-ship review, PR as KintsugiBot, `@codex review` as sh1ny, owner merge, then archive.
