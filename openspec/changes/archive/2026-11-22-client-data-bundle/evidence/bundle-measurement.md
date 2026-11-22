# Bundle measurement on a real CCP build (task 11.2) and browser checks (task 11.1)

Measured on 2026-11-20 on CCP's then-current build **3720952** (release date
2026-11-19), downloaded from CCP's static data service
(`eve-online-static-data-3720952-jsonl.zip`, 99,765,068 bytes). A second
stored build, 3714173, served as the "previous" build for the rotation checks.

**Machine.** WSL2 (Ubuntu) on the owner's desktop PC: a 13th-generation Intel
Core i7 with 6 logical CPUs and about 24 GB of memory visible to WSL. The PC
was shared, so other work (another agent's test run, a game server) ran
alongside; timings are therefore indicative, and the memory figures are
unaffected. Toolchain from `mise.toml`: Dart 3.13.7 / Flutter 3.47.9.
Chrome for Testing 156.0.8078.80, headless, driven with `puppeteer` (Dart).

## Summary against the design's limits

| Item | Measured | Limit (design) | Result |
|---|---|---|---|
| A2: the four raw files' keys | 944 of 944 keys are integers | integers | holds |
| Bundle size | 2,857,203 B gzip (2.72 MiB); 45,162,583 B inflated (43.1 MiB); ratio 15.8 | A3: a few MB / tens of MB | holds |
| Parse + index on web (hash, inflate, chunked parse, index) | 0.40 to 0.50 s (wasm), 0.43 to 0.48 s (JS) | A3: parse under 2 s | holds |
| Parse + index native (AOT) | 0.28 s | none | recorded |
| One whole one-letter query on web | 0.5 ms (JS build), 1.0 ms (wasm build) | A16: 16 ms | holds, 15x or more headroom |
| Bundle build on the worker | +647 MiB over the idle server (peak 1,319 MiB for the whole process) | quarter of the 4 GB envelope = 1,024 MiB | holds on the design's formula; see the note on the whole-process figure |
| Served bundle versions, 19 plus an estimated 2 rotated out (21) times one version, plus the worker's peak | 143 MiB + 647 MiB = 790 MiB (conservative) | 1,024 MiB | holds for the estimated workload (77%); 21 is an estimate, not a bound (see below) |
| App holding three bundles | about 0.2 GB over the page's baseline on web (0.37 GB renderer total), 0.27 GB native | 1,024 MiB | holds |
| A4 / A17 / C26 in Chrome, wasm and JS builds | pass, with one finding (below), since fixed | | pass; the stack defect found is fixed and passes through Caddy (11.6) |

**Finding for the owner (not a measurement failure; observed before the
fix, now fixed, see "Through Caddy (11.6)" below): the generated client's
WebSocket path ignores the `/api/` prefix.** The web app derives its server
address as `<origin>/api/` (`ServerAddress`), but the Serverpod client opens
its WebSocket at `<origin>/v1/websocket` (the path is fixed in
`ServerpodClientShared`: `_webSocketHost.replace(path: '/v1/websocket')`),
so the prefix is dropped. `deploy/Caddyfile` forwards only `/api/*`,
`/livez` and `/readyz`; `/v1/websocket` falls through to the single-page-app
fallback and answers 200 with `index.html`. In a first run that reached the
server through a proxy that forwarded only `/api/*`, Chrome logged
`WebSocket connection to 'ws://127.0.0.1:<port>/v1/websocket' failed: Error
during WebSocket handshake: Unexpected response code: 200`, retried with
growing waits, and no announcement ever arrived (no bundle in 200 s). Behind
the shipped Caddy stack the web app would behave the same, so A4 as written
("the generated client's streaming methods work on the wasm web build") is
true of the client but the deployed web topology does not carry the stream.
The checks below therefore ran through a test proxy that also forwarded
`/v1/websocket` to the server. This is reported as design drift against
D2/D8 (same-origin `/api/` plus stream); a fix (for example a Caddy route
for `/v1/websocket`, or a client-side prefix) was not made in this run.
It was fixed afterwards (round 21, owner's choice): `deploy/Caddyfile` now
routes `/v1/websocket` to the server, and the JS and wasm builds pass
through the real Caddy stack in "Through Caddy (11.6)".

## A2: the four raw files' keys

Tool: a Dart script reading each file from the zip and decoding every line
with `dart:convert`, counting lines whose `_key` is a JSON integer.

| File | Lines | Integer keys | Other |
|---|---|---|---|
| `dbuffCollections.jsonl` | 373 | 373 | 0 |
| `dynamicItemAttributes.jsonl` | 441 | 441 | 0 |
| `fighterAbilities.jsonl` | 36 | 36 | 0 |
| `fighterAbilitiesByType.jsonl` | 94 | 94 | 0 |

The builder (which fails a section whose key is not an integer) also built
the whole bundle from these files, both in the solo builder and on the
server's worker.

## Bundle size (D19, A3)

Tool: `buildBundleFromZip` (the solo builder over the zip) in a Dart VM, and
the server's own worker building from the imported build in the database.

| Figure | Value |
|---|---|
| Compressed (gzip) | 2,857,203 bytes (2.72 MiB) |
| Decompressed | 45,162,583 bytes (43.1 MiB), ratio 15.8 |
| SHA-256 | `3855319e26a9a20ecd90a3018ba62fa0f59b37db734a4cb6c4157085a0208e28` |
| Records | types 53,941; groups 1,633; categories 48; marketGroups 2,125; metaGroups 15; dogmaAttributes 2,929; dogmaAttributeCategories 37; dogmaEffects 3,499; dogmaUnits 60; typeDogma 27,295; mapRegions 114; mapConstellations 1,184; mapSolarSystems 8,490; dbuffCollections 373; dynamicItemAttributes 441; fighterAbilities 36; fighterAbilitiesByType 94 |
| Server's worker, same build | built 2,857,203 bytes, hash identical (C1 holds across the two build paths) |
| Previous build 3714173 | 2,856,870 bytes |

A3's "a few MB gzip'd, tens of MB decompressed" holds. The size is stored and
logged by the server, and no cap was needed (D19).

## Parse and index time (D12, D19)

All times are for the bundle above.

**Native.** Tool: a script compiled with `dart compile exe` (AOT), and the
same run under the VM (JIT); the stages are those of `openBundle` (SHA-256 and
gzip inflate in pure Dart, one-pass parse of the search sections) followed by
`SearchIndex.of`. Eight AOT runs, five JIT runs.

| Stage | AOT | JIT |
|---|---|---|
| SHA-256 of the gzip bytes | 13.2 to 13.7 ms | 19 to 20 ms |
| Inflate | 43 to 53 ms | 51 to 54 ms |
| Parse (types, groups, regions, systems) | 195 to 206 ms | 135 to 141 ms |
| Index (`SearchIndex.of`) | 21 to 24 ms | 21 to 26 ms |
| Total | 281 to 290 ms | 226 to 236 ms |

On the same index natively, a one-letter query takes 0.42 to 0.54 ms (AOT).

**Web.** Tool: a stand-alone page that calls the app's real
`BrowserBundleOpener.ofWindow(window).open(...)` (SubtleCrypto SHA-256,
`DecompressionStream('gzip')`, `openInflatedBundleChunked` in chunks of 2,000
lines yielding to the event loop) and then the app's real
`SearchBundleIndexer`, in a secure context (loopback), timed with
`performance.now()` in headless Chrome 156. The opener does hash, inflate and
parse in one call, so those three stages are one figure. The page was
compiled twice with the SDK compilers: `dart compile js -O4` and
`dart compile wasm -O2`. Five runs each (first run included, in order).

| Build | Open (hash + inflate + parse), ms | Index, ms | Total, ms |
|---|---|---|---|
| JS (dart2js) | 445, 427, 427, 401, 403 | 31, 36, 27, 24, 25 | 476, 463, 453, 425, 428 |
| wasm (dart2wasm) | 457, 439, 374, 375, 387 | 39, 30, 25, 25, 27 | 496, 469, 399, 400, 414 |

A3's "parse in under 2 seconds on web" holds with a factor of about four.

**Whole app in the browser.** In the real built app (task 11.1, below) the
bundle was in Cache Storage about 1.7 s after its request in both builds,
polled every 2 s; this includes the download from a local server, so it is a
loose upper bound for the whole pipeline.

## A16: the time of a whole query on web

Tool: the same web page; `SearchIndex.search`, which scans up to about 62,000
lowercase names (published types plus all systems), ranks prefix before
substring matches, keeps name order and cuts to 50 (`more` set). Ten batches
of 200 queries each, divided by 200 (the browser's timer is coarse); the
median batch figure is shown. One extra call was timed alone.

| Query | Hits | JS build | wasm build |
|---|---|---|---|
| `e` | 50 (more) | 0.54 ms | 1.00 ms |
| `a` | 50 (more) | 0.52 ms | 0.97 ms |
| `i` | 50 (more) | 0.52 ms | 1.04 ms |
| `o` | 50 (more) | 0.54 ms | 1.05 ms |
| `s` | 50 (more) | 0.51 ms | 0.98 ms |
| `tritanium` (full scan, 12 hits) | 12 | 0.85 ms | 1.41 ms |
| `jita` (full scan, 15 hits) | 15 | 0.65 ms | 1.20 ms |

Slowest single call timed alone: 1.8 ms. A16's 16 ms holds with a factor of
15 or more, so D17's rejection of an index stands. Native AOT, for
comparison: 0.4 to 0.5 ms for a one-letter query and 2.0 to 2.3 ms for the
two longer ones (the native figures are the median of 200 calls timed one
by one).

## Peak memory (D19, Resource Bounds)

The envelope is the design's: one instance on 2 vCPU / 4 GB; "a quarter" is
1 GiB (1,024 MiB).

### Bundle build on the worker

The worker is an isolate of the server process, so its memory is read from
the server process (Linux `/proc/<pid>/status`, `VmRSS` and `VmHWM`, the
resident set and its peak), in the development run mode (`dart run`, the
JIT, so more than the AOT image the stack runs). Method: restart the server
(a fresh `VmHWM`), let it settle with its bundle loaded, roll the
development database back to build 3714173 (`sde:rollback`), whose bundle did
not exist yet, and let the 60-second repair build it on the worker.

| Reading | Value |
|---|---|
| Fresh server, idle, bundle loaded: `VmRSS` / `VmHWM` | 732 MiB / 889 MiB |
| Idle just before the build (after the runtime's own collection) | 672 MiB |
| Peak during the build (`VmHWM`) | 1,319 MiB |
| Increment attributable to the build | +430 MiB over the earlier peak, +587 MiB over the first idle reading, +647 MiB over the lowest idle reading (the conservative figure used below) |
| Resident set after the build | about 1,252 MiB (the Dart heap is not returned to the system) |

The first start of the day also imported the 100 MB zip in the same process
and built the bundle: peak 1,339 MiB for import and build together.
Reference only: the solo builder (`buildBundleFromZip`, which holds every
imported record in memory and is not the worker's path) peaked at 2,628 MiB
RSS in the VM. The design's formula counts bundle-attributable memory:
647 MiB, below the 1,024 MiB limit.

**Whole-process note for the owner.** The server process's own peak, 1,319
MiB, is above 1,024 MiB, because about 670 to 730 MiB of it is the idle
development server (JIT, Serverpod, caches) that exists without any bundle.
If the "quarter of the envelope" were meant to cover the whole process, this
figure would exceed it in the development run; the AOT image of the stack was
not measured here. The design's formula (19 versions plus the worker's peak)
is met.

### One served bundle version, times 19, plus the worker's peak

Per version: the held bytes plus one response's transport buffers.

| Part | Measured | How |
|---|---|---|
| Held bytes | 2,857,203 B = 2.72 MiB | the bundle |
| Transport buffers in the process, per response | about 0.07 MiB (one 64 KiB chunk view) | 16 connections each sent the request and then did not read (a 4 KiB receive buffer, so the transfer stalled): server `VmRSS` rose 1.1 MB in total; the bytes themselves are shared |
| Kernel send queue per stalled response (not process memory) | 1,792,000 B = 1.71 MiB (28.7 MB for 16) | `ss -tn` Send-Q of the 16 server-side sockets; at most 4 MiB, the system's `tcp_wmem` maximum |

Per version, measured: 2.72 + 0.07 + 1.71 = 4.5 MiB. Conservatively, with the
4 MiB kernel maximum: 2.72 + 0.07 + 4 = 6.8 MiB.

| Count | Basis | Typical (4.5 MiB) | Conservative (6.8 MiB) |
|---|---|---|---|
| 19 versions | 2 held + 1 loading + 16 in flight | 86 MiB | 129 MiB |
| +2 rotated out within the proxy's timeout (workload estimate) | `write_idle 1m` in `deploy/Caddyfile` is below the route's 2-minute deadline; with rotations coming from the 60-second tick, one more falls in the window, two at a tick boundary. Worker replies (a switch, a repair) also trigger refreshes, and `write_idle` measures inactivity rather than time since admission, so this is the expected workload, not an enforced bound | 95 MiB (21) | 143 MiB (21) |
| + worker's peak | 647 MiB | 742 MiB | **790 MiB** |
| Limit | | 1,024 MiB | 1,024 MiB |

The conservative total, 790 MiB, is 77% of the limit for that workload. The
measured per-version figures hold whatever the count; nothing in the server
caps the rotated-out versions at two, so each further version still pinned
by a slow transfer adds up to 6.8 MiB (the remaining 234 MiB covers about 34
more).

Rotation with an old transfer held open: 16 transfers of the announced
bundle were held stalled while `sde:rollback` rotated the announcement to the
other build. The server's `VmRSS` was 1,282,076 kB before and 1,287,788 kB
after the rotation (+5.6 MiB), and returned to 1,282,068 kB when the
connections closed. During the stall, a 17th and later requests got `503`
(the 16-transfer bound, C19), and the stalled slots were released at the
2-minute deadline (a request got `200` at 123 s). The old bundle was still
served as the "previous" bundle after the rotation.

### The app holding three bundles at once

Three bundles are the one in use, one in flight and one held by a pending
save. Each held bundle here is the compressed copy, the opened bundle (the
inflated bytes with the decoded search sections) and its search index; three
were opened and kept at once.

| Platform | Measured | How |
|---|---|---|
| Web, JS build | renderer RSS 175 MB (page, no bundle), 229 MB (one), 368 MB (three): +193 MB for three; JS heap after a forced collection 69.5 MB | headless Chrome 156; Linux `ps` on the renderer process; Chrome's `Performance.getMetrics` after `HeapProfiler.collectGarbage` |
| Web, wasm build | 175 MB, 234 MB (one), 382 MB (three): +207 MB for three; heap after collection 89 MB | same |
| Native (AOT) | 274 MB resident for three, peak 288 MB (about 80 MB each plus a 35 MB base) | the same script as above; `ProcessInfo` |

The limit is a quarter of the envelope, 1,024 MiB; the largest figure, 382
MB for the whole renderer, is 37% of it. The measurement holds the bundles
and indexes the way the app does but runs without the Flutter engine, which
adds its own memory.

## Browser checks (11.1)

Scope of this run: Chrome for Testing 156.0.8078.80 on Linux (WSL2),
headless, against the real built web app (`mise run build:web`, a release
`--wasm` build with its dart2js fallback; about 2 min 38 s), the development
server in the development run mode against the real imported build, and the
real bundle. The server ran on alternative local ports because the default
ones were in use by another project. A small test proxy served the web build
and forwarded `/api/*` (prefix removed, as Caddy does) and, as the finding
above explains, `/v1/websocket` to the server.

The wasm build was the one Chrome chooses (skwasm; files fetched:
`main.dart.wasm`, `main.dart.mjs`, `skwasm.wasm`). Chrome 156 supports
WebAssembly GC, so the JS build was run by serving the bootstrap without its
dart2wasm entry, so that the loader takes the dart2js build that
`build:web` also produces (files fetched: `main.dart.js`, `canvaskit.wasm`).

### Results, Chrome 156 (both builds passed every check)

| Check | wasm build | JS build |
|---|---|---|
| Announcement stream delivers its first event | yes: after the WebSocket opened, the server sent `pong`, the subscription acknowledgement and a `BundleAnnouncementNamed` event within 0.25 s | yes, same |
| The real bundle downloads | yes: `GET /api/static-data/bundle/3720952/<sha>` answered 200, 2,857,203 bytes | yes |
| Hashes (SubtleCrypto), inflates (DecompressionStream), indexes | yes: the app kept the bundle in Cache Storage (it saves after opening and indexing); the stored entry (2,857,203 bytes) hashes, with SubtleCrypto in the page, to the announced SHA-256 | yes, same |
| The index is used | yes: typing `tritan` into the quick search lists "Tritanium, Mineral" and other types from the bundle | yes |
| Supersede an in-flight download | passed (below) | passed (below) |

Supersede (A4, A17, C26). Method: the proxy was told to stall the first bundle
body (it forwarded part of it, then stopped reading from the server, which is
what a stuck client does). Once the download was in flight, `sde:rollback`
changed the active build, so that the next announcement named the other
build's bundle (within one 60-second tick). The app received that
announcement, aborted the download and requested the replacement. The proxy
destroyed its connection to the server when the browser closed its side, as
Caddy does for an aborted client, and sampled the server's sockets with `ss`.

| | wasm build | JS build |
|---|---|---|
| Held download | build 3714173, stalled after 1,114,112 bytes | build 3720952, stalled after 1,638,400 bytes |
| Replacement request, after the rollback command returned | 11 s later | 47 s later |
| Browser aborted the old request (`net::ERR_ABORTED`) in the same instant as it issued the replacement | yes | yes |
| Proxy saw the browser close, destroyed its server connection | at 29,785 ms, 29,786 ms | at 81,664 ms, 81,665 ms |
| Server-side socket of the old transfer when the replacement GET arrived | already closed (0 other aborted transfers open; the replacement came 14 ms after the close) | already closed (9 ms after the close) |
| Server-side socket of the old transfer at +0, +100, +300, +1,000 ms | closed each time | closed each time |
| Replacement completed | 2,857,203 bytes; Cache Storage entry's SHA-256 equals the replacement's announced hash | 2,856,870 bytes; same |
| Search after the replacement | results shown | results shown |

In both builds the old transfer's server-side socket was closed before the
replacement request reached the server (the browser's abort and the
replacement request are separate events in the browser: the abort came
first). What this shows is the browser-side abort and the connection close
seen by `ss`; the route's own release of its slot is covered by the route's
tests, and the 2-minute deadline, the 16-transfer bound and the 503 were
observed above.

After the runs the development database was returned to build 3720952 as the
active build (`sde:rollback`), with 3714173 held as the previous build.

### Through Caddy (11.6)

Scope: the same Chrome for Testing 156.0.8078.80 (headless, Linux, WSL2) loaded
the real web build (the release `--wasm` build with its dart2js fallback) from
the origin of the real Caddy image (`caddy:2` pinned by digest, Caddy v2.11.9)
configured with the repo's `deploy/Caddyfile`, in front of the development
server (development run mode, real imported build 3720952 active, 3714173
previous, both with bundles). The web build was mounted at `/srv`; `server`
was mapped to the host (`--add-host server:host-gateway`). Ports 8080 to 8082
were held by another project, so the server ran on 18080 to 18082 and the
only change to the Caddyfile was the upstream port (`server:8080` became
`server:18080`) in a temporary copy; every route is otherwise identical.
The JS build was selected by making the loader's WebAssembly GC probe
(`WebAssembly.validate` on its 15-byte test module) report false, so that it
loads `main.dart.js`; the wasm build is the one Chrome chooses (skwasm). The
announcement frames and the WebSocket handshake were read from Chrome's
DevTools network events.

| Check | wasm build | JS build |
|---|---|---|
| Files fetched | `main.dart.wasm`, `main.dart.mjs`, `skwasm.wasm` | `main.dart.js`, `canvaskit.wasm` |
| WebSocket `ws://<origin>/v1/websocket` | handshake answered 101 Switching Protocols, 0.24 s after it was created | same, 0.18 s |
| First announcement event | `pong`, the subscription acknowledgement, then `BundleAnnouncementNamed` (build 3720952, 2,857,203 bytes, SHA-256 `3855319e...0208e28`) within 30 ms of the handshake | same, within 22 ms |
| Bundle download | `GET /api/static-data/bundle/3720952/<sha>` through Caddy answered 200, 2,857,203 bytes, 3 ms after the event | same, 8 ms after |
| Hashed, inflated, indexed | the app saved the bundle to Cache Storage after indexing; the stored entry (2,857,203 bytes) hashes with SubtleCrypto to the announced SHA-256 | same |

Without an upgrade, `GET /v1/websocket` through Caddy answered 400 "Not a
WebSocket upgrade request" from the server, not `index.html`; a request with
the upgrade headers answered 101. `GET /api/static-data/bundle/...` with an
unknown hash answered the server's 404, not the fallback.

Result: both builds pass through Caddy; the route added in round 21 fixes the
finding above. The Caddy container, the server, Chrome and the server's
embedded Postgres were stopped afterwards.

### Other browsers (11.7)

Run on 2026-11-22 by the owner, by hand, in desktop browsers on Windows 11
(NT 10.0.26300) reaching the stack in WSL2 through `localhost`, a secure
context, so SubtleCrypto is available over plain HTTP. Read from each
browser's own DevTools Network panel, with "Disable cache" ticked and the
site's data cleared before every load.

**Stack.** The web build of the change's head (`mise run build:web`, release
`--wasm` with its dart2js fallback, built for this run) was served by the real
Caddy image (`caddy:2` pinned by digest, as in 11.6) with the repo's
`deploy/Caddyfile`, in front of the development server (development run mode,
real imported builds 3720952 and 3714173, both with bundles). Two origins
were run side by side:

- `localhost:8088` served the build unchanged: the loader chooses.
- `localhost:8089` served a copy whose `flutter_bootstrap.js` reports no
  WebAssembly GC support (`supportsWasmGC:B()` replaced by
  `supportsWasmGC:!1`), so that every browser loads the JS build there.

**Which build each browser gets.** Flutter's loader offers the wasm build only
to Blink: its default `wasmAllowList` is
`{blink: true, gecko: false, webkit: false}`, and `app/web/flutter_bootstrap.js`
keeps that default. So the wasm build runs in Chromium-based browsers only;
Firefox and Safari always get the JS build, on either origin. "wasm where
supported" in 11.7 is read accordingly.

**Superseding an in-flight download.** Browser throttling slows the app's
own files as well (under a 3G profile `main.dart.wasm` and `skwasm.wasm` took
about two minutes each, so the app started after the rotation and downloaded
only the new bundle; that run is not counted). Instead, the server-to-Caddy
leg was throttled: for these runs Caddy's upstream was a local TCP relay
(`server:8080` became `server:18080` in a temporary copy of the Caddyfile,
nothing else changed) that forwards each connection at about 50 kB/s, reading
from the server only as fast as it forwards, so the transfer stays in flight at
the server. The relay logged each connection's open and close and, for the
Firefox run, each request line with its time. With the bundle download
pending, `mise run sde:rollback` rotated the active build; the next
announcement named the other build's bundle.

| Browser | Build | Files fetched | `/v1/websocket` | Bundle over the network | Search `tritan` |
|---|---|---|---|---|---|
| Vivaldi 8.3.4191.47 (Chromium) | wasm (8088) | `main.dart.wasm`, `main.dart.mjs`, `skwasm.wasm` | 101 | 200, 2,858 kB | Tritanium (Mineral) and others listed |
| Vivaldi 8.3.4191.47 | JS (8089) | `main.dart.js`, `canvaskit.wasm` | 101 | 200, 2,858 kB | listed |
| Firefox 160.0.1 | JS (8088: the loader's choice) | `main.dart.js`, `canvaskit.wasm` | 101 | 200, 2.86 MB | listed |
| Firefox 160.0.1 | JS (8089) | same | 101 | 200, 2.86 MB | listed |
| Edge 158.0.4370.33 (Chromium) | wasm (8088) | `main.dart.wasm`, `main.dart.mjs`, `skwasm.wasm` | 101 | 200, 2.9 MB (and, with the cache enabled, from the HTTP cache) | listed |
| Edge 158.0.4370.33 | JS (8089) | `main.dart.js`, `canvaskit.wasm` | 101 | 200, 2.9 MB, 59.5 s through the throttle | listed |
| Safari | | | | | not run: no macOS or iOS device in this setup. Over the network from one, the origin would be plain HTTP on a LAN address, not a secure context, so SubtleCrypto would be missing; a run needs a Mac running the stack, or an HTTPS origin |

Without "Disable cache", a reload after clearing site data showed the bundle
request answered from the browser's HTTP cache: the route serves it with
`Cache-Control: public, max-age=31536000, immutable` (the URL carries the
hash). The app cleared from Cache Storage still requested it, and opened and
indexed what the browser returned.

Supersede (A4, A17, C26):

| | Vivaldi, wasm | Vivaldi, JS | Firefox, JS | Edge, wasm |
|---|---|---|---|---|
| Held download | build 3714173 (`ea5eb0a0...`) | build 3720952 (`3855319e...`) | build 3714173 (`ea5eb0a0...`) | build 3720952 (`3855319e...`) |
| Rotation command returned | 11:20:56.0 | 11:24:56.0 | 11:27:52.9 | 11:39:15.3 |
| Caddy closed the old transfer's upstream connection (relay log) | 11:21:18.332, after 1,620,270 bytes | 11:24:57.113, after 890,000 bytes | 11:28:02.100, after 1,095,577 bytes | 11:39:24.058, after 1,456,080 bytes |
| Old request in the browser | stopped at 1,615 kB, 33.6 s (shown as 200 with the partial size) | stopped at 885 kB, 18.3 s (same) | `NS_BINDING_ABORTED` at 1.10 MB, 23.7 s | stopped at 1.5 MB, 30.2 s (shown as 200 with the partial size) |
| Replacement request reached the server | 11:21:18.338 (new upstream connection, 6 ms after the close) | on a pooled upstream connection, so not timed by the relay; in the browser's waterfall it starts where the old request ends | 11:28:02.131, request line logged, 31 ms after the close | 11:39:24.062, request line logged, 4 ms after the close (the other open tabs requested the new bundle in the same instant, so of the two requests from this origin at that time one is Edge's) |
| Replacement completed | 2,858 kB (build 3720952) | 2,857 kB (build 3714173) | 2.86 MB (build 3720952); 2,857,510 bytes on the relay's connection | 2.9 MB, 59.7 s (build 3714173) |

In every run the browser aborted the old download and Caddy closed its
connection to the server before the replacement request reached the server
(where the relay could time it). Other open tabs of the same origin took the
new announcement and downloaded the new bundle at the same moment, as they
should. A server restart during the session (the background job running it
hit a time limit) showed as WebSocket reconnects in the open tabs, after which
the announcement stream resumed. Vivaldi's console showed one
`[Violation] 'setTimeout' handler took <N>ms` on the wasm build, a Chromium
long-task notice, not an error. Edge's Issues panel listed "Deprecated feature
used" warnings; Edge also ran extensions that injected their own scripts
into the page (`index.js`, `injection-topics.js` and others in its Network
list), which are not the app's.

After the runs the development database's active build was 3720952 again,
with 3714173 held as the previous build.

## Reproduction notes

The harness scripts (zip measurement, web page and runner, same-origin
test proxy, stall and rotation probes) are kept out of the repository because
they depend on a scratch layout and are not reusable as they are. The measured
build is CCP's 3720952; a later build will give slightly different figures
(the bundle size changes by a few kB per build). The commands that matter:
`mise run build:web`; `mise run server:dev` with
`SERVERPOD_API_SERVER_PORT` (and the insights and web ports) set when 8080 is
busy; `mise run sde:rollback` to rotate between two stored builds.
