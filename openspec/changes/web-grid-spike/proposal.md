# Proposal

## Why

Big data grids are the riskiest UI assumption in the architecture. Corp asset tables reach hundreds of thousands of rows (architecture, resource bounds), and Flutter web has to scroll, filter and group them smoothly on ordinary hardware. If it can't, later milestones need a different plan: server paging everywhere, a web worker, or a renderer change. This change tests that now, before any module builds on it. It is the last change of M0 (Walking skeleton); its prerequisite `app-shell` is done.

It advances these M0 exit criteria:
- "The grid spike: a 25-column grid over 200,000 seeded rows on the web build (skwasm and the CanvasKit fallback), with virtualised rows and columns, sticky headers, and filtering, grouping and sorting outside the widget tree. A report records the measured frame times and a go or adjust recommendation." (agent)
- "The owner scrolls, groups and filters the grid spike on web on a low-end laptop and accepts the result or asks for a plan change." (user) A `[user]` task in this change checks it before archive, so an "adjust" verdict is known before M0 closes (S7). The M0 close records that result.

Constraining ADRs: 0003 (root pub workspace; pure-Dart shared code must not import Flutter), 0005 (web has no solo mode, and corp tables are server-only with SQL grouping; the client-side engine measures the main-thread worst case and the desktop solo and offline-cache path), 0010 (Riverpod 3 in the presentation layer only, sealed states in a `Notifier`, no codegen).

## What Changes

- Add a separate spike app, `spikes/kaname_grid_spike`, as a workspace member: a Flutter web app themed with `kaname_ember_ui` (S1). The product app and its web build are unchanged.
- Seed 200,000 deterministic synthetic rows in the client, shaped like corp assets across 25 columns. The data is clean-room and has no SDE or real data (S2).
- Add a pure-Dart query engine, outside the widget tree, that filters, sorts and groups the rows and computes per-group totals of quantity and value (S2, S8).
- Show the rows in a grid virtualised on both axes, with a sticky header row and a pinned first column, keyboard row navigation with the Ember focus ring, and drag-to-resize columns (S8).
- Build the spike for the web with `--wasm` (skwasm, with the CanvasKit fallback) and measure both renderers by forcing each one (S3).
- Measure missed frames, frame times and query times and write a report under `docs/spikes/` with the numbers, the method, the machines and a go or adjust recommendation against the agreed budget (S4). The report also recommends whether the product web build should move to `--wasm`.
- Keep the spike as a benchmark harness in CI (analyze and tests) until the first real grid lands (S6).

Non-goals: server-side paging or SQL grouping, any change to the product app, its routes or its web build, real or SDE data, editing cells, export, and a reusable grid component API.

## Capabilities

### New Capabilities
None. The spike adds no product behaviour, so the change sets `skip_specs: true`. The committed report and the tasks carry its acceptance (S5).

### Modified Capabilities
None.

## Impact

- New workspace member `spikes/kaname_grid_spike` (Flutter, `publish_to: none`, `resolution: workspace`), listed in the root `pubspec.yaml`. The workspace and format-dirs checks in `tools/kaname_tools` must accept the new member folder, and its tests join `mise run test`.
- A new mise task builds the spike for the web with `--wasm` and the engine bundled (no CDN), matching the product build's self-contained rule.
- Possible new dependency for two-axis virtualisation (chosen in design). `pubspec.lock` and `THIRD_PARTY_NOTICES` are regenerated, and the licence check must pass.
- `docs/spikes/web-grid.md` (new): the report.
- CI: the spike is analysed and tested with the rest of the workspace. No new platform builds.
- No server, API, product app or spec changes.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Where the spike lives

- **Choice:** a separate spike app, `spikes/kaname_grid_spike`, in the workspace: a Flutter web app themed with `kaname_ember_ui`, with its own web build.
- **Rejected:** a hidden route inside the product shell (spike code would ship in the product build); a visible module slot (it would change the shell's registered slots for throwaway code).
- **Reversal cost:** low
- **Important:** yes. It binds future changes: it adds a workspace member folder that the workspace checks must accept.
- **Chosen by:** user

### S2: Where the data lives and is queried

- **Choice:** 200,000 deterministic synthetic rows generated in the client. Filtering, grouping and sorting run in a pure-Dart query engine outside the widget tree, on the main thread, with each operation timed.
- **Rejected:** server paging through SQL (it needs Postgres seeding, an endpoint and the Docker stack in an M0 spike, whereas the client-side engine measures the main-thread worst case and the desktop solo and offline-cache path; web never runs solo, ADR 0005); measuring both (roughly twice the work for M0).
- **Reversal cost:** low
- **Important:** yes. It was chosen on weak evidence: the spike exists to measure it.
- **Chosen by:** user

### S3: Renderer coverage

- **Choice:** build the spike only with `--wasm` (skwasm, with a CanvasKit fallback) and measure both renderers by forcing each one. The product web build stays as it is, and the report recommends whether to switch it.
- **Rejected:** also moving the product build, CI and Docker stack to `--wasm` in this change (it widens scope beyond the spike).
- **Reversal cost:** low
- **Important:** yes. Its outcome binds a future build decision.
- **Chosen by:** user

### S4: The "go" budget

- **Choice:** on both renderers, hand-speed scrolling misses at most 5% of frames. Missed frames are counted as skipped display refreshes: each time between frames adds `max(0, round(interval / period) − 1)`, where the period is the display's measured refresh period, and the ratio is missed / (missed + intervals). The p99 time between frames stays ≤33ms. Where the web engine reports frame timings, build plus raster time also stays within p90 ≤16.7ms. Filter, group or sort over 200,000 rows is on screen in ≤300ms: from the call until the end of the first frame that shows the new view, with engine time reported alongside. Missing a budget means "adjust", and the report names the fix (for example a web worker or server paging). The budget is measured on the development machine, and the owner judges it again on a low-end laptop. A stress traversal at maximum speed is reported as headroom, not judged. The owner refined the frame metric in design review round 1 (time between frames sits at the refresh period, so a plain "p90 ≤16.7ms" on it flips on timer jitter). In round 2 the owner chose to count skipped refreshes and to judge operations on time until on screen.
- **Rejected:** 30fps p90 and ≤1s operations (it accepts visible jank); no fixed budget (the verdict would rest on the numbers alone, with no threshold); judging build plus raster time alone (no verdict if the web engine doesn't report it); time between frames with a jitter margin (meaningless on high-refresh displays).
- **Reversal cost:** low
- **Important:** yes. It changes behaviour users see and sets the acceptance bar.
- **Chosen by:** user

### S5: No capability spec

- **Choice:** `skip_specs: true`. The committed report and the tasks are the evidence.
- **Rejected:** a `grid-spike` capability spec (a durable requirement in the main specs for a disposable app).
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user

### S6: Spike lifetime

- **Choice:** keep the spike in `spikes/` and in CI as a benchmark harness until the first real grid lands (corp assets or member audit). That change reuses or replaces it and deletes the spike.
- **Rejected:** deleting it once the report is accepted (the measurements could no longer be rerun).
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user

### S7: How the user-verified criterion is checked

- **Choice:** a `[user]` task in this change: the owner scrolls, groups and filters the spike on web on a low-end laptop and accepts it or asks for a plan change before archive.
- **Rejected:** judging it only at the M0 close (an "adjust" verdict would surface only after the change merged).
- **Reversal cost:** low
- **Important:** yes. It changes how the change completes: archive waits on the owner.
- **Chosen by:** user

### S8: Features beyond the exit criterion

- **Choice:** add a pinned first column, keyboard row navigation with the Ember focus ring, per-group totals of quantity and value, and drag-to-resize columns.
- **Rejected:** only the exit criterion's minimum (it would leave common asset-table needs unmeasured).
- **Reversal cost:** low
- **Important:** yes. It widens the spike's scope and what the owner judges.
- **Chosen by:** user
