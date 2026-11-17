# Proposal

## Why

The app is still a placeholder screen. M0 (Walking skeleton) needs the shell that every later module plugs into, and the first call from the app through Caddy and Serverpod to Postgres. Both prerequisites are done: `serverpod-skeleton` (health call, Compose stack) and `ember-theme` (themes, controls, fonts). `web-grid-spike` waits on this change.

It advances these M0 exit criteria:
- "The app shell: adaptive rail, sidebar, main and inspector on desktop and web, bottom navigation on mobile; go_router routes; empty module slots; a settings screen; the project's Riverpod guide (ADR 0010)." (agent)
- "`docker compose up` runs Serverpod, Postgres, Redis and Caddy locally. The web app loads and shows the health endpoint's answer." The app half of this criterion; the stack half landed with `serverpod-skeleton`. (agent)
- "The owner opens the empty app on Windows desktop, web and a phone and accepts the look and the shell." (user) A `[user]` task in this change checks it before archive, so look problems are fixed in this PR (S9). The M0 close records that result.

Constraining ADRs: 0003 (workspace layout, vertical modules under `app/lib/modules/<module>/`), 0005 (connected mode: the app reads only from the server; no solo mode yet), 0006 (no offline cache in M0), 0010 (Riverpod 3 in the presentation layer only, no codegen or persist, go_router, a project guide).

## What Changes

- Replace the placeholder screen with an adaptive shell that follows DESIGN.md's reference frame:
  - top bar, icon rail, contextual sidebar, main column, docked inspector and status bar on wide windows;
  - the inspector becomes an overlay sheet at ≤1080px;
  - at ≤760px, a bottom navigation bar for the top-level slots, with the sidebar as a drawer. This is a recorded deviation from the kit (S4).
- Add a docked inspector that opens and closes, returns focus to its opener and stays empty in M0. Stretch is deferred (S5).
- Add a typed module-slot registry (id, label, icon, route) that later modules add to. M0 registers three empty placeholders, Home, Personal and Organisation, plus Settings (S1).
- Add go_router routing with one route per slot, a settings route and deep links that work on the web.
- Add a Settings screen with three sections (S3):
  - theme choice (System, Dark or Light), persisted across restarts;
  - Server, showing the health answer;
  - About, with the licence page.
- Make the app call the server's health endpoint through the generated client (S2):
  - web uses its own origin's `/api/`;
  - desktop and mobile use an optional build-time server address and show "no server configured" without one;
  - the status bar and Settings → Server show the version and the Postgres and Redis status, or that the server is unreachable.
- Introduce flutter_riverpod 3 in the app's presentation layer, following ADR 0010, and write the project's Riverpod guide at `docs/guides/riverpod.md`, linked from AGENTS.md (S7).
- Set up localisation with gen-l10n and one English ARB file. Every shell string goes through it (S6).
- Keep `themeAnimationDuration: Duration.zero` in the rewritten MaterialApp.
- Record the mobile-navigation deviation in DESIGN.md's "What Kaname changes".

Non-goals (S8): sign-in or SSO, a server-address UI, a command palette, any module content, an offline cache or local store, solo mode, and inspector stretch.

## Capabilities

### New Capabilities
- `app-shell`: the app's adaptive frame (regions, breakpoints and mobile navigation), the docked inspector, the module-slot registry, routing and deep links, and localised shell strings.
- `app-settings`: the Settings screen, the persisted theme choice and the About and licence section.
- `app-server-connection`: how the app finds its server on each platform, calls the health endpoint and shows the answer or the failure.

### Modified Capabilities
- `dependency-licences`: every package taken from the Flutter SDK, not only `flutter` and `flutter_test`, takes the Flutter SDK's licence (BSD-3-Clause), as the notices check already treats them. The app's new SDK dependencies `flutter_localizations` and `flutter_web_plugins` have no licence file of their own, so the licence check failed on them (D10).
- The `ember-ui` requirement already allows a user theme choice ("while the user has not chosen a theme"), and `server-health` is unchanged.

## Impact

- `app/`: `main.dart` is rewritten. The shell, routing, slots, settings and server-connection code are added under `app/lib/`, with l10n config and an ARB file. Widget tests replace the placeholder test.
- New app dependencies: `flutter_riverpod` 3, `go_router`, `shared_preferences` (the theme preference only), `package_info_plus` (the About version), `flutter_localizations`, `flutter_web_plugins` (SDK, path URLs) and `intl`, and `kaname_client` (workspace). `pubspec.lock` and `THIRD_PARTY_NOTICES` are regenerated, and the licence check must pass.
- `docs/guides/riverpod.md` (new), AGENTS.md (link), DESIGN.md ("What Kaname changes").
- Web build: switches to path URLs (`usePathUrlStrategy()`) with base href `/`. Compose stack: no changes expected. The web app uses the existing `/api/` route and single-page-app fallback in `deploy/Caddyfile`.
- `tools/kaname_tools`: the licence check classifies every Flutter SDK package except `sky_engine` as BSD-3-Clause (D10), with a test.
- No server or API changes.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Module slots in the empty shell

- **Choice:** a typed slot registry (id, label, icon, route). M0 registers three empty placeholders (Home, Personal, Organisation) plus Settings.
- **Rejected:** all 19 planned modules as disabled slots (dead entries for many milestones; the list goes stale); Home and Settings only (the rail and bottom nav look empty at the look check).
- **Reversal cost:** low
- **Important:** yes. It binds future changes: every module registers through this contract.
- **Chosen by:** user

### S2: How the app reaches the server and shows health

- **Choice:** web calls its own origin's `/api/`. Desktop and mobile use an optional build-time server address (`--dart-define`) and show "no server configured" without one. The answer appears in the status bar and on Settings → Server. There is no server-address UI.
- **Rejected:** an editable, persisted server address in Settings (it settles the connect flow and storage before M2 and M4 shape them); web only (desktop and mobile show nothing server-related).
- **Reversal cost:** low
- **Important:** yes. It changes behaviour users see.
- **Chosen by:** user

### S3: Settings contents and persistence

- **Choice:** theme choice (System, Dark or Light), the Server section and About with the licence page. The theme choice persists through `shared_preferences`, as a UI preference only. The M4 local-store decision (R32) stays open.
- **Rejected:** a theme choice kept in memory only (it resets on restart, which the look check would hit); no theme choice (the app follows the OS only).
- **Reversal cost:** low
- **Important:** yes. It changes settings users see and adds a dependency.
- **Chosen by:** user

### S4: Mobile navigation

- **Choice:** at ≤760px, a bottom navigation bar for the top-level slots, with the contextual sidebar as a drawer. DESIGN.md records this as a deviation.
- **Rejected:** a drawer only, as DESIGN.md's kit says (the roadmap's exit criterion names bottom navigation); a bottom bar with no sidebar (each module would inline its sidebar content).
- **Reversal cost:** medium
- **Important:** yes. It changes behaviour users see and deviates from the design system.
- **Chosen by:** user

### S5: Inspector depth in M0

- **Choice:** a 352px docked inspector that opens and closes, returns focus to its opener and becomes an overlay sheet with a scrim at ≤1080px. It stays empty, and stretch is deferred to the first module that needs it.
- **Rejected:** the full signature with stretch and a tabbed header (untested against real content); a static empty column (the responsive behaviour is postponed).
- **Reversal cost:** low
- **Important:** yes. It changes behaviour users see.
- **Chosen by:** user

### S6: Localisation

- **Choice:** set up gen-l10n now with one English ARB file. Every shell string goes through it.
- **Rejected:** hard-coded English (every screen written before l10n would need a retrofit).
- **Reversal cost:** medium
- **Important:** yes. It binds future changes: every UI string follows this pattern.
- **Chosen by:** user

### S7: Location of the Riverpod guide

- **Choice:** `docs/guides/riverpod.md`, linked from AGENTS.md's Dart and Flutter section.
- **Rejected:** a section of `app/README.md` (less visible to agents); text inside AGENTS.md (a longer always-loaded file).
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user

### S8: Non-goals

- **Choice:** out of scope are sign-in or SSO, a server-address UI, a command palette, module content, an offline cache or local store, solo mode, and inspector stretch.
- **Rejected:** adding an empty command palette now.
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user

### S9: How the user-verified look criterion is checked

- **Choice:** a `[user]` task in this change. The owner opens the app on Windows desktop, web and a phone and accepts the look and the shell before archive.
- **Rejected:** judging it only at the M0 close (look problems would need a gap-closing change).
- **Reversal cost:** low
- **Important:** yes. It changes how the change completes (archive waits on the owner).
- **Chosen by:** user
