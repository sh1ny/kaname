# Proposal

## Why

Kaname has a design system on paper (DESIGN.md, the Ember kit in `brand/`) but no Flutter package that applies it, so every later screen would either invent its own styling or wait. This change serves **M0 - Walking skeleton** and its agent-verified exit criterion "`ember_ui`: tokens generated from `brand/tokens.json`, bundled fonts (no network fonts), dark and light themes, contrast and focus tests". It is a prerequisite of `app-shell`. It also prepares the user-verified criterion "the owner opens the empty app on Windows desktop, web and a phone and accepts the look and the shell". That criterion is judged at the milestone close, after `app-shell` has built the shell this theme dresses, so this change adds no `[user]` task for it.

## What Changes

- A new shared Flutter package, `kaname_ember_ui`, at `app_packages/kaname_ember_ui/`: the first package in `app_packages/`.
- Ember tokens (colours in both rooms, shadows, type styles, radii, spacing, sizes, motion) generated from `brand/tokens.json` into the package. The kit stays the single source of truth, and a check fails when the generated file is stale.
- Geist and Literata (upright and italic) bundled as font assets in the package, with their OFL texts. No font is fetched from another host at runtime.
- Dark and light `ThemeData` built from the tokens, with the Ember roles that Material has no slot for exposed as a theme extension.
- Material controls styled to Ember: buttons (default, primary, quiet), icon buttons, chips, text fields, menus, tooltips and snackbars. They get pill and soft-corner shapes, no splash, and the 2px Focus outline on keyboard focus. Buttons, icon buttons and menu items change state without animation: hover and press colours are set per state, with no overlay fade. Material's own short text-field, chip checkmark draw-in (195ms; the fill changes on the next frame), chip shape (75ms tween of outline, selected border and focus ring; a fixed Material constant), snackbar and tooltip transitions stay, recorded as exceptions. The segmented control is left out: Material's forces rectangular, clipped segments. The first change that needs one builds an Ember control.
- `ink-tertiary` in `brand/tokens.json` is nudged to dark `#918d86` and light `#635e55`, so meta text keeps WCAG AA (4.5:1) on Hover and Press as well as at rest. The old values fall to 3.95-4.39:1 there. DESIGN.md records the change under "What Kaname changes"; `brand/BRAND.md` keeps the kit as delivered.
- Tests: WCAG contrast of the token pairs Ember uses for text and focus in both rooms, keyboard focus visibility on each styled control, and golden images of a control specimen in both rooms.
- The OFL texts registered in Flutter's `LicenseRegistry`, so the app's licence page carries them on every platform. `THIRD_PARTY_NOTICES` names the package's font licence files.
- The placeholder app switches to the Ember dark and light themes and follows the OS setting (`ThemeMode.system`).
- The web build bundles Flutter's rendering engine (`--no-web-resources-cdn`) and points the engine's fallback-font address at an empty path on the app's own origin, so the web app never contacts Google. Glyphs outside Geist, Literata and Flutter's bundled Roboto fallback (CJK, emoji) show as empty boxes on web. Desktop and mobile keep using OS fonts for them. Caddy answers that path with 404, never with the app's `index.html`. This applies to the mise `build:web` task, the CI web job and `stack:up`, each followed by a check of the build output.
- The kit's `mono` style (a system font stack, which Flutter web cannot use) is left out of the package until a change needs code or source views.
- Text fields keep DESIGN.md's focused border and halo, but draw the border in the Focus colour, because the light Ember border is 2.76:1 on Raised. Menu items get a 2px focus ring drawn just inside their shape, so a scrolling menu never clips it. DESIGN.md's "What Kaname changes" records both. It also records the `ink-tertiary` edit (its frontmatter colours take the new values too), the missing `mono` style, the text-field, chip checkmark draw-in (195ms; the fill changes on the next frame), chip shape (75ms tween of outline, selected border and focus ring; a fixed Material constant), snackbar and tooltip transition exceptions, Material's 200ms blend of inherited text colour, 167ms blend of text-field borders and labels, and 75ms blend of chip outlines on a theme switch, the focus ring on a pointer-hovered menu item, and the light empty-field edge gap.

## Capabilities

### New Capabilities
- `ember-ui`: Kaname's Flutter design-system package: generated tokens, bundled fonts and their licences, dark and light themes, Ember-styled Material controls, and the contrast, focus and golden guarantees they meet.

### Modified Capabilities
- `workspace-layout`: the current-packages scenario gains `kaname_ember_ui` at `app_packages/kaname_ember_ui/`.
- `third-party-notices`: the vendored-asset entries for Geist and Literata also name the licence files bundled in `kaname_ember_ui`.
- `self-host-stack`: Caddy answers the web app's fallback-font path with 404, never with the app's `index.html`.

## Impact

- New: `app_packages/kaname_ember_ui/` (pubspec, `lib/`, fonts, tests and goldens). The root workspace lists it.
- `brand/tools/build.mjs` (or the generator the design picks) gains an output into the package. `brand/tokens.json` changes only `ink-tertiary`. The kit's generated `brand/tokens.css` and `brand/flutter/ember_tokens.dart` are regenerated with it.
- `app/`: depends on `kaname_ember_ui`, and `MaterialApp` takes the Ember themes.
- `tools/kaname_tools/lib/src/notices.dart`: font licence coverage also under `app_packages/`.
- `mise.toml` (`build:web` with the `webbuild:check` task; `tokens` and `tokens:check` in `check`; a `test:ember_ui` task in `test`), `.github/workflows/ci.yml` (web build command and check), `app/web/flutter_bootstrap.js` (new: the engine's fallback-font address) and `deploy/Caddyfile` (404 for that path).
- `THIRD_PARTY_NOTICES`: hand-written font entries, and a regenerated dependency section if the lockfile changes.
- New font binaries in the repository: the full variable `.ttf` files from the google/fonts repository, under OFL-1.1.
- DESIGN.md "What Kaname changes": any deliberate deviation the design makes.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Package name and place

- **Choice:** `kaname_ember_ui` at `app_packages/kaname_ember_ui/`.
- **Rejected:** `kaname_ui`, which drifts further from ADR 0003's `ember_ui`; `kaname_ember`, which does not say it is a UI package.
- **Reversal cost:** medium (a rename touches every import).
- **Important:** yes: binds future changes (package boundary every UI change imports).
- **Chosen by:** user

### S2: Component scope

- **Choice:** tokens, fonts and dark/light themes, plus Ember styling of Material's buttons, icon buttons, chips, inputs, menus, tooltips and snackbar with the 2px focus outline. Ember-only widgets (segmented control, panel, card, row, banner, monogram, save state, linked reference, inspector) arrive with the change that first needs them. Round 2 of the design review showed that Material's SegmentedButton forces rectangular, clipped segments, so the owner took it out of this change.
- **Rejected:** all primitives now (bigger PR, widgets with no user until later milestones); tokens and theme only (focus and shapes left to app-shell, which weakens the focus tests).
- **Reversal cost:** low.
- **Important:** yes: changes behaviour users see.
- **Chosen by:** user

### S3: Wire the theme into the placeholder app

- **Choice:** the app's `MaterialApp` uses the Ember dark and light themes now, which proves the fonts bundle and render in real builds on all six targets.
- **Rejected:** package only, which leaves font loading in the real app unproven until app-shell.
- **Reversal cost:** low.
- **Important:** yes: changes behaviour users see.
- **Chosen by:** user

### S4: The web app never contacts Google for engine or fonts

- **Choice:** `--no-web-resources-cdn` bundles the rendering engine, and the engine's fallback-font address points at an empty path on the app's own origin, which Caddy answers with 404. Glyphs outside the bundled fonts show as empty boxes on web.
- **Rejected:** self-hosting Flutter's Noto fallback set (tens of MB with CJK, another font set to track); accepting fallback fetches from fonts.gstatic.com and narrowing "no network fonts"; deferring to `web-grid-spike`. Round 1 of the design review showed that the flag alone still fetches fallback fonts from Google, so S4 was put to the owner again.
- **Reversal cost:** low.
- **Important:** yes: changes behaviour users and self-hosters see (no third-party fetches; boxes for uncovered glyphs on web).
- **Chosen by:** user

### S5: Font licences ship inside the app

- **Choice:** the package ships the OFL texts as assets and registers them in `LicenseRegistry`. `THIRD_PARTY_NOTICES` names the package's font paths.
- **Rejected:** `THIRD_PARTY_NOTICES` only, which would leave a store-installed app carrying the fonts without their licence.
- **Reversal cost:** low.
- **Important:** yes: changes what users see (licence page) and meets OFL redistribution terms.
- **Chosen by:** user

### S6: Default theme before the user chooses

- **Choice:** follow the OS (`ThemeMode.system`). The settings screen in `app-shell` adds the explicit choice.
- **Rejected:** dark by default, which ignores a light OS setting.
- **Reversal cost:** low.
- **Important:** yes: changes behaviour users see.
- **Chosen by:** user

### S7: Ink Tertiary meets AA on every surface

- **Choice:** change `ink-tertiary` to dark `#918d86` (4.55:1 on Press) and light `#635e55` (4.53:1), still below Ink Secondary. The contrast test enforces 4.5:1 for every text token on every surface, with no exceptions.
- **Rejected:** a rule that text on Hover or Press steps up to Ink Secondary (a trap for every later row widget); testing resting surfaces only (a known accessibility gap).
- **Reversal cost:** low.
- **Important:** yes: changes what users see, and changes the token source of truth.
- **Chosen by:** user

### S8: Accent fills are not held to the 3:1 non-text bar

- **Choice:** the contrast test does not require Ember fills to contrast 3:1 with the surface (light Ember on canvas is 2.55:1). A fill is identified by its label (Ember Ink on Ember passes AA), and Focus passes 3:1 in both rooms. The spec states the exemption.
- **Rejected:** enforcing 3:1 and darkening the light accent, which would change the light room's character.
- **Reversal cost:** low.
- **Important:** yes: chosen on a judgement about the WCAG scope.
- **Chosen by:** user

### S9: No mono style for now

- **Choice:** the package generates no `mono` type style. The kit's mono is a system font stack, which Flutter web cannot use. The first change that needs code or source views picks a bundled mono font.
- **Rejected:** bundling Geist Mono now (a family the kit does not name, with no user yet); keeping the system stack and exempting it (empty boxes on web).
- **Reversal cost:** low.
- **Important:** yes: binds future changes (the first code view must add a mono font).
- **Chosen by:** user

### S10: Material's text-field and chip transitions are a recorded exception

- **Choice:** the no-animation rule covers buttons, icon buttons and menu items. Material's own text-field border transition (167ms, plus a 15ms hover fade) and chip selection draw-in of the checkmark (195ms; the fill changes on the next frame because `ChipThemeData.color` is set) cannot be switched off from a theme. Neither can Material's snackbar entrance and exit (250ms) or its tooltip fade (150ms in, 75ms out); these two were added after design review round 3, with the owner's agreement. The chip shape's 75ms tween (outline, selected border and focus ring; a fixed Material constant) was added after round 4. All five stay, recorded in DESIGN.md's "What Kaname changes", until Ember widgets replace them.
- **Rejected:** Ember field and chip wrappers that pass zero durations, which widens scope and brings back the "remember the wrapper" trap.
- **Reversal cost:** low.
- **Important:** yes: changes behaviour users see (a deviation from the One Motion Rule).
- **Chosen by:** user

### S11: The light empty-field edge is a known gap

- **Choice:** keep the kit's text-field border (Strong Hairline). In the light theme an empty field's edge is 1.37:1 against the field and the field about 1.07:1 against the page, below WCAG's 3:1 for component boundaries. Fields carry a visible label above them (DESIGN.md), and the gap is recorded so the owner's look check at the M0 close, or the first form-heavy change, can revisit it.
- **Rejected:** a new `field-line` token at 3:1 in both rooms, which changes the kit's field look before anyone has judged it on screen.
- **Reversal cost:** low.
- **Important:** yes: chosen on a judgement about accessibility, and visible to users.
- **Chosen by:** user
