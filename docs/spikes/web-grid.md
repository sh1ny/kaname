# Spike report: big data grids on Flutter web

The M0 roadmap names one risky UI assumption: that Flutter web can show a large data grid fast enough. The spike `spikes/kaname_grid_spike` tests it with 200,000 seeded rows and 25 columns in a `TableView`, filtered, sorted and grouped in plain Dart on the main thread. This report gives the numbers from the development machine. The owner's own check decides the M0 exit criterion. The owner chose to make it on the development PC under game load instead of a low-end laptop (task 9.5, amended 2026-11-17); a laptop run stays optional (below).

The raw results, with the machine header, are in [`openspec/changes/web-grid-spike/evidence/bench-dev-machine.md`](../../openspec/changes/web-grid-spike/evidence/bench-dev-machine.md). Every figure here comes from that file.

## Method

The spike runs its own benchmark: press **Benchmark** in the toolbar, or open the page with `?bench=1`. `mise run bench:spike` builds the spike with `--wasm`, serves it with `kaname_tools serve` (COOP/COEP headers, loopback) and opens it in headless Chrome for Testing once per row: skwasm multi-threaded, skwasm single-threaded (`?threads=single`) and CanvasKit (`?renderer=canvaskit`). Each row writes one JSON file (schema version 1).

The script, in order:

1. **Calibrate:** 2s of animation; the median time between frames is the refresh period.
2. **Hand-speed scroll:** 20s of vertical scrolling at 3,000 px/s, reversing at the ends. The verdict is judged on this segment.
3. **Stress traversal:** top to bottom in 30s and back in 30s, about 200,000 px/s. Reported as headroom, not judged.
4. **Horizontal scroll:** to the last column and back, 5s each way.
5. **Operations:** filter text `a`, category filter, sort on name, quantity and a float column, group by category then by a second column, collapse all, expand all, clear the query.
6. **Resize:** one column to 320px.

**Metrics.** Times between frames come from persistent frame callbacks. Missed frames count skipped refreshes: each interval adds `round(interval / period) − 1`. Work time is build plus raster time from `FrameTiming`. For each operation the spike records the engine time (the Dart query) and the time until on screen (from the call to the end of the first frame showing the new view, plus its raster time when reported).

**S4 budget**, judged on the hand-speed segment:

| Criterion | Budget |
|---|---|
| Missed frames | ≤5% |
| p99 time between frames | ≤33ms |
| Work p90 (build + raster) | ≤16.7ms |
| Every operation on screen | ≤300ms |

## Machine and load state

- **Machine:** the owner's development PC, Intel Core i7-13700K, through WSL2 (6 logical CPUs and 23 GB visible to WSL).
- **Browser:** Chrome for Testing 157.0.8103.78, headless, 1600×900 at device pixel ratio 1, refresh period 16.7ms (60Hz).
- **GPU path:** software. WebGL runs on SwiftShader (`ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)`), because WSL gives headless Chrome no GPU.
- **Load:** idle, confirmed by the owner; load average 0.05 before the run.
- **Date:** 2026-11-17.

## Results

### Hand-speed verdict

| Row | Missed | p99 | Work p90 | Ops ≤300ms | Verdict |
|---|---|---|---|---|---|
| skwasm multi-threaded, re-run 1 | 0.2% | 16.67ms | 13.1ms | yes | **pass** |
| skwasm multi-threaded, re-run 2 | 0.2% | 16.67ms | 12.5ms | yes | **pass** |
| skwasm single-threaded | 0.4% | 16.8ms | 12.8ms | yes | **pass** |
| CanvasKit | 15.4% | 33.3ms | 19.8ms | yes | **miss** (missed frames, p99, work) |

In the full run the multi-threaded row crashed (see "Multi-threaded skwasm crash"). Its figures come from two re-runs of that row alone.

### Stress headroom (not judged)

| Row | Down: missed, p50 | Up: missed, p50 | Work p90 |
|---|---|---|---|
| skwasm multi-threaded, re-run 1 | 49.9%, 33.3ms | 49.7%, 33.3ms | 84–86ms |
| skwasm multi-threaded, re-run 2 | 47.8%, 33.3ms | 48.1%, 33.3ms | 82–83ms |
| skwasm single-threaded | 59.4%, 33.4ms | 59.9%, 33.4ms | 38ms |
| CanvasKit | 74.4%, 66.7ms | 74.7%, 66.7ms | 63ms |

At about 200,000 px/s every frame shows new rows. skwasm holds 30 fps there and CanvasKit 15 fps. In the multi-threaded rows work time includes waiting on the render thread, so it is not comparable with the single-threaded figure.

Horizontal scrolling stayed within budget for skwasm (0.3–1.7% missed). CanvasKit missed 5.3% and 5.6%, just over budget.

### Operations

Engine time and time until on screen, in milliseconds. The multi-threaded row shows re-run 1.

| Operation | skwasm multi | skwasm single | CanvasKit |
|---|---|---|---|
| Filter text (200,000 → 151,114 rows) | 1.7 / 58 | 1.7 / 57 | 1.9 / 71 |
| Category (→ 4,515 rows) | 2.2 / 58 | 6.1 / 70 | 1.6 / 77 |
| Sort text | 3.5 / 29 | 3.9 / 42 | 2.9 / 53 |
| Sort integer | 5.1 / 27 | 3.2 / 35 | 2.8 / 70 |
| Sort float | 3.3 / 25 | 4.8 / 46 | 3.0 / 49 |
| Group first | 4.7 / 58 | 3.6 / 37 | 3.1 / 67 |
| Group second | 3.1 / 24 | 3.3 / 33 | 3.2 / 52 |
| Collapse all | 0.0 / 11 | 0.0 / 19 | 0.1 / 48 |
| Expand all | 0.0 / 20 | 0.0 / 38 | 0.0 / 85 |
| Clear (→ 200,000 rows) | 0.2 / 83 | 0.2 / 80 | 0.3 / 82 |
| Resize column | n/a / 41 | n/a / 52 | n/a / 79 |

The slowest operation in any row took 85ms to reach the screen, against a budget of 300ms. Re-run 2 of the multi-threaded row stayed under 79ms.

### Seed time

Generating the 200,000 rows at startup: 44ms and 45ms (skwasm multi-threaded), 47ms (single-threaded), 53ms (CanvasKit).

## Multi-threaded skwasm crash

In the full run the multi-threaded skwasm page threw `RuntimeError: memory access out of bounds` inside `skwasm.wasm`, called from the app's `main.dart.wasm`. It happened about 100s in, around the operations step. Two re-runs of the same row finished and passed, and so did three shorter smoke runs of it earlier that day. So the crash is intermittent: one failure in six multi-threaded runs. The stack sits in the engine, not in spike code, and the spike has no native or unsafe code of its own. Single-threaded skwasm and CanvasKit never crashed. Before the product relies on multi-threaded skwasm, the crash needs a reproduction on the Flutter release in use and an upstream report.

## Caveats

- **Software GPU (A3).** Headless Chrome in WSL rasterises on SwiftShader, so these figures are a pessimistic bound, not what a person sees on real hardware. The owner's own check decides. During the run with the owner's PC under game load, the owner judged the live grid (skwasm, multi-threaded) "not laggy" and responsive.
- **LAN serving is single-threaded (review round 2, S-b).** Browsers allow cross-origin isolation only on a secure context: HTTPS, or `localhost` itself. Opened over the LAN at `http://<host>:<port>`, the page is not cross-origin isolated, and skwasm runs single-threaded whatever the headers say. To measure multi-threaded skwasm on the laptop, build and serve the spike on the laptop itself.
- **Operation sizes.** The script filters before it sorts and groups, so the sorts and groupings ran on 4,515 rows, not on 151,114 or 200,000. Filtering and clearing do touch the full set. Sorting or grouping all 200,000 rows was not timed by the script. The owner can try it by hand in the spike (no filter, then sort or group).
- **A8 not checked.** Chrome 157 ignored both `--js-flags=--no-experimental-wasm-gc` and `--js-flags=--no-wasm-gc`, so the fallback from a forced `renderer=skwasm` on a browser without WasmGC was not observed.
- **One machine, one browser.** No Firefox, Safari or mobile run. 60Hz only.

## Verdict

**Go for skwasm; adjust for CanvasKit.**

- skwasm passes S4 with a wide margin, single-threaded and multi-threaded, even on a software GPU: under 0.5% missed frames, p99 at one refresh period, and every operation on screen within 85ms.
- CanvasKit misses S4 on this machine (15.4% missed frames, p99 33.3ms against 33ms, work p90 19.8ms). Operations stay within budget. With work p90 above one refresh period on a software rasteriser, raster cost is the likely cause, and real GPUs could clear it. The fix for this miss: treat CanvasKit as the fallback only for browsers without WasmGC, ship `--wasm` so capable browsers get skwasm, and let the owner's `?renderer=canvaskit` check decide whether the fallback is acceptable or needs work (for example fewer visible columns or lighter cell painting).
- The multi-threaded crash keeps multi-threaded skwasm from being the default until it is understood (above).

## Recommendation: move the product web build to `--wasm`

The product's `mise run build:web` today runs `flutter build web --release --no-web-resources-cdn`. That build always uses CanvasKit, the one renderer that missed. A `--wasm` build serves skwasm to browsers with WasmGC and falls back to CanvasKit for the rest.

The change that adopts it must follow C3 (the doc comment on `WebBuildChecker` in `tools/kaname_tools/lib/src/webbuild.dart`):

- **Headers.** Multi-threaded skwasm needs `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` on the origin, added to `deploy/Caddyfile`. Without them skwasm runs single-threaded. Single-threaded skwasm passed S4 here without the headers and never crashed, so the recommended first step is `--wasm` **without** the headers. Add them later, once the crash above is reproduced and resolved upstream.
- **Self-contained check.** `webbuild --check` passes on `--wasm --no-web-resources-cdn` output (A7, checked by `mise run build:spike`), so the existing check carries over.

## Scope

These are client-side numbers on seeded data. They do not move corp-table filtering, grouping or totals off SQL on web (C5, ADR 0005). A grid over server data must measure server-side paging and SQL grouping before relying on them.

## Owner's laptop

Optional since the 9.5 amendment. On the Windows clone, after pulling this branch:

1. `mise install`, then `mise run resolve`.
2. `mise run build:spike`. It needs Chrome for its web tests; set `CHROME_EXECUTABLE` if Chrome is not found.
3. `mise run serve:spike`, then open <http://127.0.0.1:8080/> in Chrome on the laptop itself (loopback keeps skwasm multi-threaded).
4. Scroll, filter, sort and group by hand. Then try:
   - <http://127.0.0.1:8080/?threads=single>: skwasm single-threaded;
   - <http://127.0.0.1:8080/?renderer=canvaskit>: the CanvasKit fallback.

   The toolbar shows the renderer and thread mode in use.
5. Optionally press **Benchmark** on each, then **Copy JSON**, and paste the results into this report under a "Laptop" heading.
