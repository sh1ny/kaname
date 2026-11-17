# Tasks

Implementers and reviewers load these skills before writing Dart, and every packet carries them with AGENTS.md's "Dart and Flutter code" section:
- `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis` and `dart-add-unit-test`;
- `flutter-add-widget-test`, `flutter-apply-architecture-best-practices` (ADR 0010 overrides its state and DI steps) and `flutter-build-responsive-layout`;
- `flutter-setup-declarative-routing`, `flutter-setup-localization`, `impeccable` and `serverpod-endpoints`.

Each skill is at `.claude/skills/<name>/SKILL.md`. Check current go_router, flutter_riverpod 3, shared_preferences and package_info_plus APIs with Context7 or `find-docs` before writing against them. Run everything through mise.

## Test map

All paths are under `app/test/`.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| app-shell → Wide windows show the full desktop frame | Desktop width | `shell/app_frame_test.dart` | wide window shows top bar, rail, sidebar, main and status bar | green |
| app-shell → Wide windows show the full desktop frame | Window narrowed across the breakpoint | `shell/app_frame_test.dart` | narrowing to 1000 turns the open inspector into a sheet and keeps main state | green |
| app-shell → Medium windows show the inspector as an overlay | Inspector opened at medium width | `shell/inspector_test.dart` | medium width opens the inspector as a sheet over a scrim | green |
| app-shell → Medium windows show the inspector as an overlay | Scrim dismisses the sheet | `shell/inspector_test.dart` | tapping the scrim closes the sheet and keeps main | green |
| app-shell → Narrow windows use bottom navigation and a sidebar drawer | Phone width | `shell/app_frame_test.dart` | narrow window shows bottom bar with four destinations and no rail | green |
| app-shell → Narrow windows use bottom navigation and a sidebar drawer | Drawer closes on navigation | `shell/app_frame_test.dart` | picking a bottom-bar destination closes the drawer | green |
| app-shell → The docked inspector opens and closes without replacing the subject | Open and close with the keyboard | `shell/inspector_test.dart` | closing returns focus to the toggle and keeps main state | green |
| app-shell → The docked inspector opens and closes without replacing the subject | Opener gone when closing | `shell/inspector_test.dart` | closing with the opener gone focuses main without error | green |
| app-shell → Panels move with one motion and honour reduced motion | Normal motion | `shell/inspector_test.dart` | inspector reaches 352 at 200ms, not before | green |
| app-shell → Panels move with one motion and honour reduced motion | Reduced motion | `shell/inspector_test.dart` | disableAnimations opens the inspector on the next frame | green |
| app-shell → Module slots come from one registry | Registered slots appear in order | `shell/slot_registry_test.dart` | M0 registry lists Home, Personal, Organisation with Settings at the foot | green |
| app-shell → Module slots come from one registry | Duplicate slot | `shell/slot_registry_test.dart` | duplicate id or path throws naming the duplicate | green |
| app-shell → Every destination has a route and deep links work | Deep link on the web | `shell/router_test.dart` | initial location /settings shows Settings selected | green |
| app-shell → Every destination has a route and deep links work | Unknown path | `shell/router_test.dart` | unknown location redirects to not-found inside the frame with a Home link | green |
| app-shell → Shell text is localised | English device | `shell/localisation_test.dart` | en-GB shows English labels | green |
| app-shell → Shell text is localised | Unsupported locale | `shell/localisation_test.dart` | ja-JP falls back to English without errors | green |
| app-shell → Shell controls are reachable by keyboard and screen reader | Tab through the rail | `shell/accessibility_test.dart` | rail items take focus in order with the ring and selected semantics | green |
| app-shell → Shell controls are reachable by keyboard and screen reader | Icon-only control without a label | `shell/accessibility_test.dart` | every icon-only shell control has a semantic label | green |
| app-settings → Settings has Appearance, Server and About sections | Open Settings | `settings/settings_screen_test.dart` | sections appear in order Appearance, Server, About | green |
| app-settings → Settings has Appearance, Server and About sections | Narrow window | `settings/settings_screen_test.dart` | at 390 sections stack with no overflow | green |
| app-settings → The user chooses System, Dark or Light | Choose Light on a dark system | `settings/theme_choice_test.dart` | choosing Light on a dark system shows the light canvas next frame | green |
| app-settings → The user chooses System, Dark or Light | System follows a later OS change | `settings/theme_choice_test.dart` | System follows an OS brightness change | green |
| app-settings → The theme choice survives a restart | Restart after choosing Dark | `settings/theme_preference_store_test.dart` | Dark saved, then a new app start shows dark on the first frame | green |
| app-settings → The theme choice survives a restart | Unreadable stored value | `settings/theme_preference_store_test.dart` | missing, empty or unknown value reads as System | green |
| app-settings → The theme choice survives a restart | Storage fails to save | `settings/theme_choice_test.dart` | failed save keeps the choice and shows the not-saved message | green |
| app-settings → About shows the version and the licence page | Open licences | `settings/about_test.dart` | licence page lists Geist and Literata | green |
| app-settings → About shows the version and the licence page | Back from licences | `settings/about_test.dart` | back from licences returns to Settings with the choice unchanged | green |
| app-server-connection → The web app talks to the server on its own origin | Served by the stack | `server/server_address_test.dart` | web with base http://127.0.0.1:8080/ targets /api/ on that origin | green |
| app-server-connection → The web app talks to the server on its own origin | Served under another host name | `server/server_address_test.dart` | web target follows the base origin's host | green |
| app-server-connection → The web app talks to the server on its own origin | Release web build given an address | `server/server_address_test.dart` | release web ignores the define | green |
| app-server-connection → Desktop and mobile take an optional build-time server address | Address given | `server/server_address_test.dart` | native define http://127.0.0.1:8080/ is the target | green |
| app-server-connection → Desktop and mobile take an optional build-time server address | No address | `server/server_status_test.dart` | no address gives NotConfigured, makes no call, and the UI shows No server configured | green |
| app-server-connection → Desktop and mobile take an optional build-time server address | Invalid address | `server/server_status_test.dart` | address without a scheme gives InvalidAddress, makes no call, and Settings says invalid | green |
| app-server-connection → The app calls the health endpoint at start and on request | Check again | `server/server_status_test.dart` | Check again makes one new call and replaces the answer | green |
| app-server-connection → The app calls the health endpoint at start and on request | Double press | `server/server_status_test.dart` | two presses during a call share one call and show busy | green |
| app-server-connection → The app shows the health answer | Everything up | `server/server_status_view_test.dart` | all up shows connected and version, Postgres up, Redis up | green |
| app-server-connection → The app shows the health answer | Redis down | `server/server_status_view_test.dart` | Redis down shows text and error colour | green |
| app-server-connection → An unreachable server is shown without internal detail | Server stopped | `server/server_status_test.dart` | failure or 10s time-out gives Unreachable with no exception text and the shell still navigates | green |
| app-server-connection → An unreachable server is shown without internal detail | Server comes back | `server/server_status_test.dart` | Check again after Unreachable shows the new answer | green |
| dependency-licences → Locked packages are classified by licence | Other Flutter SDK packages | `tools/kaname_tools/test/licences_test.dart` (outside `app/test/`) | every other Flutter SDK package is accepted as BSD-3-Clause without a licence file | green |
| ember-ui → Keyboard focus is always visible | Tab to each control | `app_packages/kaname_ember_ui/test/focus_test.dart` (outside `app/test/`) | segmented-control options paint the outside outline in both themes | red |
| ember-ui → Keyboard focus is always visible | Focus leaves a control | `app_packages/kaname_ember_ui/test/focus_test.dart` (outside `app/test/`) | focus leaving a control clears its indicator, segmented options included | red |
| ember-ui → Keyboard focus is always visible | Segmented-control option beside the selected one | `app_packages/kaname_ember_ui/test/focus_test.dart` (outside `app/test/`) | an option beside the selected one shows its full outline | red |

## 1. Dependencies and assumptions

- [x] 1.1 Verify A3: add `flutter_riverpod` (3.x), `go_router`, `shared_preferences`, `package_info_plus`, `intl`, `flutter_localizations` (SDK), `flutter_web_plugins` (SDK) and `kaname_client` to `app/pubspec.yaml`, then run `mise run resolve`. Verify with `mise run notices` followed by `mise run notices:check` and `mise run licences`, which must pass. Any failure stops this task and goes to the owner. (Applied: the SDK packages failed; per D10, write the failing `licences_test.dart` test, then classify every SDK package except `sky_engine` as BSD-3-Clause in `tools/kaname_tools/lib/src/licences.dart`, run `mise run test:tools`, and flip its row green.)
- [x] 1.2 Verify A4 for the web target: in a scratch run, `SharedPreferencesWithCache.create` and `PackageInfo.fromPlatform()` both work under `flutter test --platform chrome` or a debug web run. Record the result in the task's commit message. The other platforms are checked at task 8.4.

## 2. Localisation (S6, D7)

- [x] 2.1 Verify A1: set up gen-l10n. Add `app/l10n.yaml` (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/generated`, no synthetic package) and `flutter: generate: true`, then run `mise exec -- flutter gen-l10n` in `app/`. Verify the output appears in `lib/l10n/generated/`. If the pinned Flutter refuses this layout, stop for design drift.
- [x] 2.2 Commit the generated files, exclude `lib/l10n/generated/**` from `app/analysis_options.yaml`, and add a `l10n:check` mise task that regenerates into a temporary directory and fails on any difference. Wire it into `check` and the CI job that runs `check`. Verify that `mise run l10n:check` passes, and fails after a hand edit to the ARB without regeneration (revert afterwards).

## 3. Server connection (S2, D3, D5)

- [x] 3.1 Write the failing `server/server_address_test.dart` tests for every ServerAddress row of the test map (red). `ServerAddress` takes `isWeb`, `isDebug`, the raw define and the base `Uri` as inputs.
- [x] 3.2 Implement `app/lib/server/data/server_address.dart`, returning the sealed `ServerTarget` (`ConfiguredServer`, `NoServer` or `InvalidServer`). Write C3 in the `ServerAddress` doc comment. Verify the 3.1 tests pass and flip their rows green.
- [x] 3.3 Write the failing `server/server_status_test.dart` tests (red). Use a hand-written `FakeServerHealth` with controllable completers, and `ProviderContainer.test`.
- [x] 3.4 Implement the `ServerHealth` interface and the `ClientServerHealth` adapter (`Client(host, connectionTimeout: Duration(seconds: 10))`) in `app/lib/server/data/`. Implement the sealed `ServerStatus` and `ServerStatusNotifier` in `app/lib/server/logic/`, with a 10s backstop, single-flight and every failure mapped to `Unreachable`. Write C7 in the `ServerStatus` doc comment, citing the spec requirement. Verify the 3.3 tests pass and flip their rows green.

## 4. Settings data (S3, D6, D9)

- [x] 4.1 Write the failing `settings/theme_preference_store_test.dart` tests (red), with `shared_preferences`' in-memory test platform.
- [x] 4.2 Implement `ThemeChoice`, the `ThemePreferenceStore` interface and its `SharedPreferencesWithCache` implementation, allow-listing only `kaname.theme_mode`, plus the failing-save fallback store, in `app/lib/settings/data/`. Write C2 and C8 in the `ThemePreferenceStore` doc comment. Verify the 4.1 tests pass and flip their rows green.
- [x] 4.3 Implement the `AppVersionSource` interface and its `package_info_plus` implementation, which returns "unknown" on failure. Add a unit test with a throwing source. Verify the test passes.

## 5. Shell (S1, S4, S5, D2, D4)

- [x] 5.1 Write the failing `shell/slot_registry_test.dart` and `shell/router_test.dart` tests (red).
- [x] 5.2 Implement the slot registry (`app/lib/shell/logic/`) with its duplicate guard, and placeholder modules in `app/lib/modules/{home,personal,organisation}/` with localised empty states. Write C1 in the registry's doc comment, citing the spec requirement. Verify the registry tests pass and flip their rows green.
- [x] 5.3 Implement `buildRouter`:
  - `StatefulShellRoute.indexedStack` with one branch per slot, plus Settings (with `/settings/licences`) and a hidden not-found branch;
  - `/` redirects to `/home`, and unmatched locations redirect to `/not-found`;
  - no `preload`.

  Write C10 and C11 in the `buildRouter` doc comment. Verify the router tests pass and flip their rows green.
- [x] 5.4 Write the failing `shell/app_frame_test.dart`, `shell/inspector_test.dart` and `shell/accessibility_test.dart` tests (red). Set window sizes with `tester.view.physicalSize`, and reduced motion with `MediaQueryData(disableAnimations: true)`.
- [x] 5.5 Implement `AppFrame` and the shell widgets in `app/lib/shell/ui/`, following DESIGN.md's Layout and Ember tokens:
  - the frame itself, the top bar, the rail, the bottom bar and the status-bar slot;
  - the sidebar and its drawer, at 200ms with `panelEase`;
  - the inspector panel and its overlay sheet;
  - the `InspectorNotifier` open state;
  - focus return, with main as the fallback;
  - a main column that stays mounted.

  Write C6 in the `InspectorPanel` doc comment and C9 in the `ShellBottomBar` doc comment. Verify the 5.4 tests pass and flip their rows green.
- [x] 5.6 Write `shell/localisation_test.dart` (red), then route every shell string through `AppLocalizations`, with English as the fallback locale. Verify the tests pass and flip their rows green.

## 6. Screens and wiring (S2, S3, C5)

- [x] 6.1 Write the failing `server/server_status_view_test.dart`, `settings/settings_screen_test.dart`, `settings/theme_choice_test.dart` and `settings/about_test.dart` tests (red).
- [x] 6.2 Implement the status-bar server indicator and the Settings screen: Appearance (a System, Dark or Light segmented control), Server (full answer, Check again, busy state, not configured, invalid, unreachable) and About (the version, plus a licence page through `showLicensePage` or a routed `LicensePage`). Use exhaustive switches over `ServerStatus` and `ThemeChoice`. Verify the 6.1 tests pass and flip their rows green.
- [x] 6.3 Rewrite `app/lib/main.dart` and `app/lib/app.dart`:
  - `main()` registers the font licences, calls `usePathUrlStrategy()`, creates the preferences (falling back on failure), reads the version, resolves `ServerAddress` from `kIsWeb`, `kDebugMode`, `KANAME_SERVER_URL` and `Uri.base`, and runs `ProviderScope` with overrides;
  - `KanameApp` uses `MaterialApp.router` with `themeAnimationDuration: Duration.zero`.

  Write C5 in the `KanameApp` doc comment. Replace `app/test/app_test.dart` with tests that keep its two Ember canvas checks, now through the shell. Verify with `mise exec -- flutter test` in `app/`.
- [ ] 6.4 Per D11 (added during apply), move the segmented control into `kaname_ember_ui`:
  - write the failing tests (red): in the package's `focus_test.dart`, in both themes, a case that tabs to an option whose right-hand neighbour is selected and checks the full outside outline, and the options in the "focus leaving a control" test; a widget test for selection by tap and by Enter/Space and for the semantics (group label; each option a button with its label, selected state and mutual exclusion);
  - implement and export `EmberSegmentedControl<T>`, with the focused option's ring painted above its neighbours and a caller-given key per option;
  - update the `ember_theme.dart` doc comment, the library doc in `lib/kaname_ember_ui.dart` and the package's pubspec description;
  - make the Appearance section use it with `SettingsKeys.themeOption` as option keys, and delete `app/lib/settings/ui/theme_segmented.dart`.

  Verify with `mise exec -- flutter test` in `app_packages/kaname_ember_ui` and in `app/`, and `mise exec -- dart analyze --fatal-infos`; flip the ember-ui rows green.

## 7. Documentation

- [x] 7.1 Write `docs/guides/riverpod.md`, the project's Riverpod guide (ADR 0010):
  - providers live only in `logic/`, and `data/` code is plain Dart that never imports Riverpod;
  - no codegen and no `persist`;
  - `Notifier` with sealed states, as `ServerStatusNotifier` shows;
  - `ProviderContainer.test` with overrides and hand-written fakes;
  - single-flight;
  - where to put a new module.

  Carry C4: ADR 0010 already states it, and accepted ADRs are not edited. The guide restates it and links to the ADR. Link the guide from AGENTS.md's "Dart and Flutter code" section. Verify the link resolves and the guide names the pinned Riverpod version from `pubspec.lock`.
- [x] 7.2 Add the S4 bottom-navigation deviation to DESIGN.md's "What Kaname changes", and the inspector-stretch gap. Add a run note to `app/README.md` with `flutter run -d chrome --dart-define=KANAME_SERVER_URL=http://127.0.0.1:8080/` for debug web, and the same define for desktop and mobile. Verify by reading the rendered Markdown.

## 8. Integration

- [ ] 8.1 Run `mise run check` and `mise run build:web`, which includes `webbuild:check`. Both must pass. Verify the CI workflow still builds all six targets on this branch's PR.
- [ ] 8.2 Verify A2: run `mise run stack:up` with `deploy/.env` set, load `http://127.0.0.1:<port>/settings` in a headless browser, and confirm that the health request goes to `/api/` on the same origin and returns. If the Serverpod web client needs another host form, stop for design drift.
- [ ] 8.3 [evidence] Record the stack proof (D8) → evidence/stack-web-health.md. The file holds the commands run, the status-bar and Settings → Server text shown (version, Postgres up, Redis up), the request URL seen by the browser, and the deep-link check of `/settings`. Then run `mise run stack:down`.
- [ ] 8.4 [user] The owner opens the app on Windows desktop, on the web through the stack, and on a phone. The owner checks the frame at each width, the rail, sidebar, inspector, bottom bar and drawer, Settings (theme choice survives a restart, the server answer or "No server configured", About and licences), and the placeholder icons (Open Question). The owner accepts the look and the shell, or lists what to change. This checks the M0 exit criterion "The owner opens the empty app on Windows desktop, web and a phone and accepts the look and the shell".

## Workflow follow-up

- Pre-ship review, PR and archive follow the Specwright workflow. Archive waits on task 8.4.
