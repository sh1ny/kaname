# Spike report: big data grids on Flutter web

The M0 roadmap names one risky UI assumption: that Flutter web can show a large data grid fast enough. The spike `spikes/kaname_grid_spike` tests it with 200,000 seeded rows and 25 columns in a `TableView`, filtered, sorted and grouped in plain Dart on the main thread. This report gives the numbers from the development machine. The owner's own check decides the M0 exit criterion. The owner chose to make it on the development PC under game load instead of a low-end laptop (task 9.5, amended 2026-11-17); a laptop run stays optional (below).

The raw results, with the machine header, are in [`openspec/changes/web-grid-spike/evidence/bench-dev-machine.md`](../../openspec/changes/web-grid-spike/evidence/bench-dev-machine.md). Every timing here comes from that file. The row counts after each filter (151,114 and 4,515) come from a separate VM run of the same seed with the same filters (`runGrid` with filter text `a`, then also category code 0); the result JSON does not record them.

## Method

The spike runs its own benchmark: press **Benchmark** in the toolbar, or open the page with `?bench=1`. `mise run bench:spike` builds the spike with `--wasm`, serves it with `kaname_tools serve` (COOP/COEP headers, loopback) and opens it in headless Chrome for Testing once per row: skwasm multi-threaded, skwasm single-threaded (`?threads=single`) and CanvasKit (`?renderer=canvaskit`). Each row writes one JSON file (schema version 1).

The script, in order:

1. **Calibrate:** 2s of an empty animation, with the grid still; the median time between frames is the refresh period.
2. **Hand-speed scroll:** 20s of vertical scrolling at 3,000 px/s, reversing at the ends. The verdict is judged on this segment.
3. **Stress traversal:** top to bottom in 30s and back in 30s, about 200,000 px/s. Reported as headroom, not judged.
4. **Horizontal scroll:** to the last column and back, 5s each way.
5. **Operations:** filter text `a`, category filter, sort on name, quantity and a float column, group by category then by a second column, collapse all, expand all, clear the query. Then the same three sorts and two groupings again on all 200,000 rows, with no filter.
6. **Resize:** one column to 320px.

**Metrics.** Times between frames come from persistent frame callbacks. Missed frames count skipped refreshes: each interval adds `max(0, round(interval / period) − 1)`. Work time is build plus raster time from `FrameTiming`. For each operation the spike records the engine time (the Dart query) and the time until on screen (from the call to the end of the first frame showing the new view, plus its raster time when reported).

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
- **Load:** idle, confirmed by the owner; load average 0.58 before the run (just after the build).
- **Date:** 2026-11-18. The first full run, on 2026-11-17, is kept in the evidence's "Earlier run" section for the crash below. It is not quoted here: it predates the pre-ship review fixes (frame timings matched to their own frames, calibration on an empty animation, full-set steps).

## Results

### Hand-speed verdict

| Row | Missed | p99 | Work p90 | Ops ≤300ms | Verdict |
|---|---|---|---|---|---|
| skwasm multi-threaded | 0.1% | 16.67ms | 12.8ms | yes | **pass** |
| skwasm single-threaded | 0.2% | 16.8ms | 12.6ms | yes | **pass** |
| CanvasKit | 10.6% | 33.3ms | 19.8ms | yes | **miss** (missed frames, p99, work) |

### Stress headroom (not judged)

| Row | Down: missed, p50 | Up: missed, p50 | Work p90 |
|---|---|---|---|
| skwasm multi-threaded | 47.9%, 33.3ms | 48.2%, 33.3ms | 81–85ms |
| skwasm single-threaded | 57.2%, 33.4ms | 58.1%, 33.4ms | 37ms |
| CanvasKit | 74.7%, 66.7ms | 73.8%, 66.7ms | 62–65ms |

At about 200,000 px/s every frame shows new rows. skwasm holds 30 fps there and CanvasKit 15 fps. In the multi-threaded row, work time includes waiting on the render thread, so it is not comparable with the single-threaded figure.

Horizontal scrolling (not judged) missed 0–4.3% of frames in every row. Its p99 reached 33.3ms for CanvasKit and 33.4ms on the single-threaded outward leg, just over the 33ms that S4 applies to the hand-speed segment.

### Operations

Engine time and time until on screen, in milliseconds. A `*` marks an operation whose raster time never arrived. The web engine reports frame timings in batches at least 100ms apart, and the run ends before the last batch, so the last one or two operations count only to the end of their frame.

| Operation | skwasm multi | skwasm single | CanvasKit |
|---|---|---|---|
| Filter text (200,000 → 151,114 rows) | 1.6 / 102 | 1.8 / 75 | 1.9 / 83 |
| Category (→ 4,515 rows) | 5.7 / 82 | 2.1 / 64 | 1.5 / 78 |
| Sort text (4,515 rows) | 3.8 / 58 | 7.1 / 52 | 2.7 / 67 |
| Sort integer (4,515 rows) | 3.1 / 49 | 3.4 / 46 | 3.0 / 65 |
| Sort float (4,515 rows) | 5.1 / 53 | 3.6 / 45 | 3.2 / 72 |
| Group first (4,515 rows) | 3.2 / 47 | 5.8 / 47 | 3.1 / 68 |
| Group second (4,515 rows) | 3.5 / 35 | 3.4 / 44 | 3.2 / 80 |
| Collapse all | 0.0 / 33 | 0.0 / 27 | 0.1 / 61 |
| Expand all | 0.0 / 157 | 0.0 / 38 | 0.0 / 73 |
| Clear (→ 200,000 rows) | 0.2 / 187 | 0.2 / 90 | 0.3 / 141 |
| Sort text, 200,000 rows | 66.6 / 252 | 74.4 / 147 | 48.2 / 193 |
| Sort integer, 200,000 rows | 64.7 / 252 | 72.0 / 156 | 40.3 / 188 |
| Sort float, 200,000 rows | 68.7 / 250 | 72.9 / 148 | 44.2 / 178 |
| Group first, 200,000 rows | 77.6 / 130* | 82.6 / 166 | 50.5 / 183 |
| Group second, 200,000 rows | 80.8 / 135* | 80.1 / 157* | 45.0 / 125* |
| Resize column | n/a / 46* | n/a / 51* | n/a / 53* |

Every operation reached the screen within 300ms. The slowest took 252ms: multi-threaded skwasm sorting all 200,000 rows, which leaves 48ms of headroom on this machine. Three things stand out:

- **Engine speed.** The Dart engine runs the full-set sorts and groupings in 64–83ms compiled to wasm (skwasm rows) and 40–51ms compiled to JavaScript (CanvasKit row).
- **Raster time.** Multi-threaded raster times (10–134ms) run well above single-threaded ones (7–10ms), which is why that row's on-screen figures are the highest. The cause was not investigated: the render thread may queue frames.
- **Unmeasured groupings.** The two multi-threaded full-set groupings have no raster time, so their on-screen figures are lower than the full-set sorts' and not comparable with them.

### Seed time

Generating the 200,000 rows at startup: 44ms (skwasm multi-threaded), 43ms (single-threaded), 54ms (CanvasKit).

## Multi-threaded skwasm crash

In the first full run (2026-11-17) the multi-threaded skwasm page threw `RuntimeError: memory access out of bounds` inside `skwasm.wasm`, called from the app's `main.dart.wasm`. It happened about 100s in, around the operations step. Every other multi-threaded run finished: two re-runs of that row, three shorter smoke runs and two later full runs, including the one quoted above. So the crash is intermittent: one failure in eight multi-threaded runs. The stack sits in the engine, not in spike code, and the spike has no native or unsafe code of its own. Single-threaded skwasm and CanvasKit never crashed. Before the product relies on multi-threaded skwasm, the crash needs a reproduction on the Flutter release in use and an upstream report.

## Caveats

- **Software GPU (A3).** Headless Chrome in WSL rasterises on SwiftShader, so these figures are a pessimistic bound, not what a person sees on real hardware. The owner's own check decides. During the run with the owner's PC under game load, the owner judged the live grid (skwasm, multi-threaded) "not laggy" and responsive.
- **LAN serving is single-threaded (review round 2, S-b).** Browsers allow cross-origin isolation only on a secure context: HTTPS, or `localhost` itself. Opened over the LAN at `http://<host>:<port>`, the page is not cross-origin isolated, and skwasm runs single-threaded whatever the headers say. To measure multi-threaded skwasm on the laptop, build and serve the spike on the laptop itself.
- **A8 not checked.** Chrome 157 ignored both `--js-flags=--no-experimental-wasm-gc` and `--js-flags=--no-wasm-gc`, so the fallback from a forced `renderer=skwasm` on a browser without WasmGC was not observed.
- **One machine, one browser.** No Firefox, Safari or mobile run. 60Hz only.

## Verdict

**Go for skwasm; adjust for CanvasKit.**

- skwasm passes S4 with a wide margin, single-threaded and multi-threaded, even on a software GPU: under 0.5% missed frames, p99 at one refresh period, and every operation on screen within 300ms, including sorting and grouping all 200,000 rows (at most 252ms).
- CanvasKit misses S4 on this machine (10.6% missed frames, p99 33.3ms against 33ms, work p90 19.8ms). Operations stay within budget. With work p90 above one refresh period on a software rasteriser, raster cost is the likely cause, and real GPUs could clear it. The fix for this miss: treat CanvasKit as the fallback only for browsers without WasmGC, ship `--wasm` so capable browsers get skwasm, and let the owner's `?renderer=canvaskit` check decide whether the fallback is acceptable or needs work (for example fewer visible columns or lighter cell painting).
- The multi-threaded crash keeps multi-threaded skwasm from being the default until it is understood (above).
- Full-set sorts leave 48ms of headroom here, most of it spent outside the Dart engine. On a slower machine they could miss. If they do, the fix is the one S4 names: run the query in a web worker, or page from the server (C5).

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
