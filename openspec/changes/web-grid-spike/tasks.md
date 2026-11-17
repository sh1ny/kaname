# Tasks

Implementers and reviewers load these skills before writing Dart, and every packet carries them with AGENTS.md's "Dart and Flutter code" section:
- `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis` and `dart-add-unit-test`;
- `dart-build-cli-app` (the `serve` command and the runner);
- `flutter-add-widget-test`, `flutter-apply-architecture-best-practices` (ADR 0010 and `docs/guides/riverpod.md` override its state and DI steps) and `flutter-build-responsive-layout`;
- `impeccable` with DESIGN.md for the grid's look.

Each skill is at `.claude/skills/<name>/SKILL.md`. Check current `two_dimensional_scrollables`, `flutter_riverpod` 3, `puppeteer` and Flutter web loader APIs with Context7 or `find-docs` before writing against them. Run everything through mise.

**Machine load.** The owner's PC is often busy with games or other projects' agents. Before any timing run (tasks 9.1–9.3), ask the owner whether the machine is idle, and record its load state with the numbers. Builds and tests may run at any time, but keep them to one at a time.

## Test map

The change sets `skip_specs: true` (proposal S5), so there are no `#### Scenario:` entries to map. The tests below are the change's own checks. Each starts red and turns green in the task named.

| Area | Behaviour | Test file | Test name | State |
|---|---|---|---|---|
| tools → workspace | a `spikes/kaname_*` member is accepted; other `spikes/` names are refused | `tools/kaname_tools/test/workspace_test.dart` | spikes root accepts kaname_ members | green |
| tools → workspace | `--format-dirs` prints `spikes/kaname_grid_spike` and still refuses unsafe paths | `tools/kaname_tools/test/workspace_test.dart` | format dirs accept spikes members | green |
| tools → purity | `spikes/` is not checked for purity | `tools/kaname_tools/test/purity_test.dart` | spikes members are outside the purity rule | green |
| tools → serve | serves files with content types (`.wasm`, `.mjs`, `.js`, `.html`), and `/` serves `index.html` | `tools/kaname_tools/test/serve_test.dart` | serves files with their content types | green |
| tools → serve | COOP/COEP sent by default, absent with `--no-isolation` | `tools/kaname_tools/test/serve_test.dart` | isolation headers follow the flag | green |
| tools → serve | unknown path and `/font-fallback/x` get a plain 404 | `tools/kaname_tools/test/serve_test.dart` | non-files and font fallback answer 404 | green |
| tools → serve | `..` and encoded escapes outside the root are refused | `tools/kaname_tools/test/serve_test.dart` | paths outside the root are refused | green |
| tools → serve | binds loopback by default; bind failure exits 1 with a message | `tools/kaname_tools/test/serve_test.dart` | binds loopback and reports bind failure | green |
| spike → seed | xorshift32 first 16 outputs match the golden (VM and Chrome) | `spikes/kaname_grid_spike/test/data/prng_test.dart` | xorshift32 matches golden | green |
| spike → seed | 200,000 rows, 25 columns, web-portable lists, ints < 2^31, checksums match constants | `spikes/kaname_grid_spike/test/data/seed_test.dart` | seed is deterministic and web-portable | green |
| spike → engine | substring and category filters | `spikes/kaname_grid_spike/test/data/grid_engine_test.dart` | filter by text and category | green |
| spike → engine | sort is total (row-index tie-break), ascending and descending, text/int/float | `spikes/kaname_grid_spike/test/data/grid_engine_test.dart` | sort is total and deterministic | green |
| spike → engine | group runs, counts, sums; collapsed groups show only headers | `spikes/kaname_grid_spike/test/data/grid_engine_test.dart` | group with totals and collapse | green |
| spike → engine | operations never copy rows and report elapsed time | `spikes/kaname_grid_spike/test/data/grid_engine_test.dart` | operations return index views and timing | green |
| spike → logic | `Seeding` → `Ready`; self-check mismatch → `SeedFailed` naming the check | `spikes/kaname_grid_spike/test/logic/grid_notifier_test.dart` | seed states and self-check | green |
| spike → logic | a throwing operation keeps the view and sets a typed `lastError` | `spikes/kaname_grid_spike/test/logic/grid_notifier_test.dart` | failed operation keeps view and sets lastError | green |
| spike → logic | resize, current row and collapse-key reset behave as designed | `spikes/kaname_grid_spike/test/logic/grid_notifier_test.dart` | widths, current row and collapse keys | green |
| spike → ui | header row and name column stay pinned while scrolling both axes | `spikes/kaname_grid_spike/test/ui/grid_view_test.dart` | header and name column stay pinned | green |
| spike → ui | only visible cells are built (virtualised on both axes) | `spikes/kaname_grid_spike/test/ui/grid_view_test.dart` | builds only visible cells | green |
| spike → ui | group header: label in the pinned cell, sums in their columns, no merges | `spikes/kaname_grid_spike/test/ui/grid_view_test.dart` | group header layout | green |
| spike → ui | arrow keys move the current row with the Ember focus ring | `spikes/kaname_grid_spike/test/ui/grid_view_test.dart` | keyboard moves the current row | green |
| spike → ui | dragging a header edge resizes the column | `spikes/kaname_grid_spike/test/ui/grid_view_test.dart` | drag resizes a column | green |
| spike → ui | filter input is debounced; `Seeding`, `SeedFailed` and `lastError` are shown | `spikes/kaname_grid_spike/test/ui/grid_screen_test.dart` | filter debounce and visible states | green |
| spike → bench | missed frames (skipped refreshes), p50/p90/p99, verdict per S4 | `spikes/kaname_grid_spike/test/logic/bench_metrics_test.dart` | metrics and S4 verdict | green |
| spike → bench | step order, `stepDone` handshake, timeouts → `Aborted`, cancel | `spikes/kaname_grid_spike/test/logic/benchmark_notifier_test.dart` | benchmark state machine | green |
| spike → bench | result JSON v1 fields; abort published through `BenchHost` | `spikes/kaname_grid_spike/test/logic/benchmark_result_test.dart` | result JSON v1 and abort publication | green |
| spike → bench | `?bench=1` autostarts; grid input disabled while running | `spikes/kaname_grid_spike/test/ui/benchmark_ui_test.dart` | autostart and input lock | green |
| spike → web build | `build:spike` output passes `webbuild --check` | n/a (mechanical: `mise run build:spike`) | n/a | green |

## 1. Workspace tooling for `spikes/`

- [x] 1.1 Write failing tests for the `spikes` package root and `--format-dirs` pattern in `tools/kaname_tools/test/workspace_test.dart`, and for purity exclusion in `purity_test.dart`. Verify they fail for the right reason (map rows "spikes root…", "format dirs…", "spikes members…").
- [x] 1.2 Add `spikes` to `WorkspaceCheck.packageRoots` and to the `--format-dirs` pattern in `tools/kaname_tools/lib/src/workspace.dart`, leaving `pureRoots` unchanged. Write C2 as the doc comment on `WorkspaceCheck.packageRoots`. Verify with `mise run test:tools`; flip the three rows green.

## 2. `kaname_tools serve`

- [x] 2.1 Write failing tests in `tools/kaname_tools/test/serve_test.dart` for the five serve rows of the test map, using a temporary directory and a real loopback `HttpServer` on port 0. Verify they fail.
- [x] 2.2 Implement `ServeCommand` in `tools/kaname_tools/lib/src/serve.dart`, registered in `cli.dart`. It uses `dart:io` only and follows D5: content types, COOP/COEP unless `--no-isolation`, a plain 404 for non-files, `index.html` only for `/`, path-escape refusal, `--host` defaulting to `127.0.0.1`, `--port` and a 30s idle timeout.
  - Write C4 as the doc comment on `ServeCommand`, and C9 on `ServeCommand.run`.
  - Verify with `mise run test:tools` (rows green) and `mise run purity`.

## 3. Spike package scaffold

- [x] 3.1 Verify A4: check the current `two_dimensional_scrollables` release and its Flutter constraint against Flutter 3.47.9 (Context7 or pub.dev, then `flutter pub add --dry-run`). Record the version in the task's commit message. If it is incompatible, stop: that is design drift (D1).
- [x] 3.2 Create `spikes/kaname_grid_spike` (Flutter, `publish_to: none`, `resolution: workspace`, web platform only) with dependencies `flutter`, `flutter_riverpod`, `kaname_ember_ui` and `two_dimensional_scrollables`. List it in the root `pubspec.yaml`.
  - The `lib/` folders are `data/`, `logic/` and `ui/`, plus `main.dart`, whose library doc comment carries C1 and C7.
  - Add `analysis_options.yaml` matching the app's.
  - Add mise tasks `test:spike` (VM, added to `test`) and `test:spike:web` (`flutter test --platform chrome --tags web`).
  - Run `mise run resolve`, then `mise run notices` and `mise run licences`, so that `THIRD_PARTY_NOTICES` is regenerated and the licence check passes.
  - Verify with `mise run workspace`, `mise run analyze` and `mise run format:check`.

## 4. Seed and query engine (`data/`)

- [x] 4.1 Write failing VM tests (`prng_test.dart`, `seed_test.dart`, `grid_engine_test.dart`) for the seed and engine rows, tagging the PRNG, seed and engine tests `web`. Verify they fail.
- [x] 4.2 Implement `data/prng.dart` (xorshift32, every step masked with `& 0xFFFFFFFF`), `data/columns.dart` (web-portable typed lists only; dictionary codes with ranks; integers < 2^31; C8 as its library doc comment) and `data/seed.dart`. The seed builds 200,000 rows and 25 columns from syllable-generated names, with no SDE, ESI or third-party schema, and its golden and checksum constants are exported for the self-check.
  - Verify the PRNG and seed rows are green with `mise run test:spike`.
- [x] 4.3 Implement `data/grid_engine.dart`:
  - filter by dictionary mask, then a scan;
  - self-written merge sort with a row-index tie-break;
  - grouping with counts and the sums of quantity and total value;
  - the flat `Int32List` view with `-(g+1)` headers and collapsed groups;
  - a `Stopwatch` time per operation.

  C5 (with its ADR 0005 sentence) is the library doc comment. Verify the engine rows are green with `mise run test:spike`.
- [x] 4.4 Run `mise run test:spike:web` (Chrome, one job at a time) and confirm the tagged PRNG, seed and engine tests pass under dart2js. Flip nothing new; this guards C-1 and C8.

## 5. Grid state (`logic/`)

- [x] 5.1 Write failing `grid_notifier_test.dart` tests with `ProviderContainer.test` and hand-written fakes for the seed and engine (no mocking package). Verify they fail.
- [x] 5.2 Implement `logic/grid_notifier.dart`:
  - sealed `GridState` (`Seeding`, `Ready`, `SeedFailed(reason)`), with the seed started after the first frame and the startup self-check against the golden and the checksums;
  - `Ready` with the query, view, widths, current row, last timing and a typed `lastError` (which operation failed; the exception message goes to `debugPrint` only, per `docs/guides/riverpod.md:47`);
  - the methods `setFilter`, `sortBy`, `groupBy`, `toggleGroup`, `resizeColumn` and `moveCurrent`;
  - the seed and engine providers overridden in `main()`.

  Verify the logic rows are green.

## 6. Grid UI (`ui/`)

- [x] 6.1 Write failing widget tests (`grid_view_test.dart`, `grid_screen_test.dart`) for the UI rows, with a small seeded fixture overridden through providers. Verify they fail.
- [x] 6.2 Implement `ui/grid_view.dart`:
  - `TableView.builder` with `pinnedRowCount: 1`, `pinnedColumnCount: 1` and 30px rows;
  - column extents from `Ready` widths, with drag-to-resize on header edges;
  - group headers per D1 (label, count and arrow in the pinned cell, sums in their columns, no merges);
  - keyboard row navigation with the Ember focus ring and current-row Ember Glow;
  - Ember tokens, Geist 13px with tabular figures.

  Verify the pinned, virtualised, group-header, keyboard and resize rows are green.
- [x] 6.3 Implement `ui/grid_screen.dart`:
  - a toolbar with a debounced filter input, category filter, sort and group pickers and an expand/collapse-all control;
  - the renderer and thread-mode readout and the Benchmark button;
  - the `Seeding` and `SeedFailed` states and the `lastError` banner, which names the operation.

  Check the look against DESIGN.md with `impeccable`. Verify the "filter debounce and visible states" row is green, and check `mise run analyze`.

## 7. Benchmark (`logic/` + `ui/`)

- [x] 7.1 Write failing tests `bench_metrics_test.dart`, `benchmark_notifier_test.dart`, `benchmark_result_test.dart` and `benchmark_ui_test.dart` for the bench rows, with a fake `BenchHost` and a fake clock. Verify they fail.
- [x] 7.2 Implement `logic/bench_metrics.dart` as pure functions:
  - calibrated refresh period (median);
  - missed frames `max(0, round(interval / period) − 1)` and the ratio missed / (missed + intervals);
  - p50, p90, p99 and max;
  - the S4 verdict per segment (≤5% missed, p99 ≤33ms, work p90 ≤16.7ms when timings exist, every operation on screen ≤300ms).

  Verify the "metrics and S4 verdict" row is green.
- [x] 7.3 Implement `logic/benchmark_notifier.dart` (sealed `Idle`, `Running(step)`, `Done(result)`, `Aborted(reason)`) and `logic/benchmark_result.dart`.
  - **Script:** calibrate; hand-speed scroll 20s at 3,000 px/s; stress traversal 30s each way; horizontal scroll 5s each way; operations; resize.
  - **Timeouts and cancel:** per-step timeout of 2× planned + 10s, and Cancel.
  - **Handshake:** scroll steps are run by the grid widget through `stepDone(step)`; operation steps call `GridNotifier`.
  - **Recording:** frame samples in a preallocated 100,000-entry `Float64List` with `droppedSamples`; engine time and time until on screen per operation; seed time.
  - **Result:** JSON `schemaVersion: 1`, with C6 as the doc comment on `BenchmarkResult`. On `Aborted`, publish `{schemaVersion: 1, aborted: reason}` through `BenchHost`, so the runner fails fast (review round 2, S-a).

  Verify the state-machine and JSON rows are green.
- [x] 7.4 Implement the `BenchHost` seam: an interface in `logic/`, a web implementation (conditional import) that sets `window.gridBenchResult`, reads `Uri.base` for `?bench=1` and reports the renderer, and a VM stub. Also implement the grid widget's scroll-step runner and input lock, and `ui/result_panel.dart` (figures against the budget, "Copy JSON").
  - Verify A6: use `dart:ui_web` if it exposes the active renderer, else record the requested renderer plus `kIsWasm`, and note which in the commit.
  - Verify the "autostart and input lock" row is green, then run `mise run test:spike` and `mise run test:spike:web`.

## 8. Web build, bootstrap and runner

- [x] 8.1 Write `spikes/kaname_grid_spike/web/flutter_bootstrap.js` per D8. It reads `?renderer=` and `?threads=single`, passes `renderer` and `forceSingleThreadedSkwasm` in the `config` literal, keeps `fontFallbackBaseUrl: "/font-fallback/"` in that literal, and logs unknown values. Add the mise tasks `build:spike` (`test:spike:web`, then `flutter build web --wasm --release --no-web-resources-cdn`, then `kaname_tools webbuild --check spikes/kaname_grid_spike/build/web`) and `serve:spike`.
  - Verify A7 by running `mise run build:spike`. If `webbuild --check` rejects valid `--wasm` output, stop and report it as design drift, without changing the checker silently.
  - Flip the "web build" row green.
- [x] 8.2 Write C3 as a doc comment on `WebBuildChecker` in `tools/kaname_tools/lib/src/webbuild.dart`. Verify with `mise run analyze`.
- [x] 8.3 Verify A2: add `puppeteer` as a `dev_dependency` of the spike only. Confirm that `mise run resolve` changes no existing locked version (`git diff pubspec.lock` shows additions only), that `mise run licences` passes, and that it launches Chrome for Testing headless. If any of these fails, remove it, record the outcome in the commit, and use the manual `?bench=1` fallback (D4) in group 9.
- [x] 8.4 Implement `spikes/kaname_grid_spike/tool/bench.dart`. For each combination of skwasm threaded, skwasm single-threaded and CanvasKit, it:
  - serves the build with `kaname_tools serve`, adding `--no-isolation` for the single-threaded row;
  - opens headless Chrome at `/?bench=1&renderer=…&threads=…`;
  - polls `window.gridBenchResult` with a 10-minute timeout;
  - writes `build/grid-bench/<renderer>-<threads>.json`, marking failed rows with their reason.

  It exits 1 if any row failed. Add the mise task `bench:spike`. Verify with a short smoke run (`--smoke`, scaled-down durations) that writes three JSON files and is not judged. Ask the owner first whether the machine may take a headless Chrome run now.
  - Verify A5 by reading the thread mode in the threaded row's JSON.
  - Verify A1 by checking whether frame timings were reported.
  - Verify A8 by forcing `renderer=skwasm` with WasmGC disabled (a Chrome flag) and recording what happens.

## 9. Measurements, report and owner check

- [x] 9.1 Ask the owner whether the machine is idle enough for timing runs. Wait for the answer; do not run 9.2 on a busy machine.
- [x] 9.2 [evidence] Run `mise run bench:spike` on the idle development machine and save the three JSON results, plus a header with the machine, the CPU and GPU path (`chrome://gpu` summary), the load state the owner confirmed and the date → evidence/bench-dev-machine.md
- [x] 9.3 Write `docs/spikes/web-grid.md`:
  - **Method:** the script, the metrics and the S4 budget.
  - **Machines and load state.**
  - **Per-renderer tables:** hand-speed verdict, stress headroom, operations (engine and on-screen) and seed time.
  - **Caveats:** headless and software GPU (A3); LAN serving runs skwasm single-threaded unless served on the laptop itself (review round 2, S-b).
  - **Verdict:** go or adjust against S4, and the fix for any miss.
  - **Recommendation:** whether the product web build should move to `--wasm`, naming C3's headers.
  - **Scope note:** the client-side numbers don't change where corp-table grouping runs (C5).
  - **Owner's laptop:** how to run the spike there on the Windows clone (`mise run build:spike`, `mise run serve:spike`, then open `/?renderer=…` or press Benchmark).

  Link the report from the roadmap's M0 section only at milestone close, not here. Verify that the report quotes the evidence file's numbers.
- [x] 9.4 Run `mise run check` and `mise run spec:validate`. Both pass.
- [ ] 9.5 [user] The owner runs the spike on web on the development PC, under load from gaming (amended 2026-11-17, owner's choice: "This PC counts"; the low-end laptop run becomes optional, see the report's "Owner's laptop" section), (skwasm and `?renderer=canvaskit`). The owner scrolls, groups and filters the grid, optionally presses Benchmark and pastes the JSON into the report, and then accepts the result or asks for a plan change. This checks the M0 exit criterion "The owner scrolls, groups and filters the grid spike on web on a low-end laptop and accepts the result or asks for a plan change".

## Workflow follow-up

- Pre-ship review (Specwright) before the first PR push.
- Ship the PR as KintsugiBot, request `@codex review` as sh1ny, and handle feedback. The owner merges.
- Archive after 9.5 is ticked, then `specwright-finish`. Then `specwright-roadmap close` for M0.
