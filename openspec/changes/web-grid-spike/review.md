# Review

## Metadata

- **Round:** 2
- **Prior round:** round 1 VERDICT: REVISE (2 Critical, 10 Moderate, 8 Suggestions)
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** openspec/changes/web-grid-spike/proposal.md, design.md, .openspec.yaml (skip_specs: true, no specs); the round-1 review (scratchpad review-round1.md); openspec/roadmap.md (M0 exit criteria, lines 9-29); openspec/architecture.md (resource bounds, lines 84-97; components); docs/adr/0003, 0004, 0005, 0010; docs/guides/riverpod.md; DESIGN.md (lines 248, 287, 351); AGENTS.md; licence-policy.yaml; root pubspec.yaml. Cited source, all git-tracked and re-read at the cited ranges: tools/kaname_tools/lib/src/workspace.dart (74-80, 133-138, 180-201, 231-233), purity.dart (38-39), webbuild.dart (17-87, 104-126, 188-230), mise.toml (38-139, 218-229), .github/workflows/ci.yml (1-100), app/web/flutter_bootstrap.js (1-16), deploy/Caddyfile (20-40); app_packages/kaname_ember_ui/lib/src/ember_theme.dart is tracked (cited as a whole file, not opened). No referenced stores. Skills loaded: dart-use-pattern-matching, dart-write-documentation, dart-run-static-analysis, dart-add-unit-test, dart-build-cli-app, flutter-add-widget-test, flutter-apply-architecture-best-practices, flutter-build-responsive-layout, impeccable (all loaded).
- **Re-check:** 2026-11-17, Required Changes 1–4, owner decisions as listed: (1) option (a), count skipped vsyncs/refreshes; (2) option (a), the ≤300ms budget judges time until on screen (first rendered frame showing the new view), engine time reported too; (3) the ADR 0005 line, S2's rejected reason and the C5 extension as proposed; (4) C9, no owner decision needed. Re-read: openspec/changes/web-grid-spike/proposal.md and design.md only.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Round-1 findings: status

| Round 1 | Status | Where |
|---|---|---|
| C-1 `Int64List` breaks dart2js | resolved | D2 web-portable storage; D6 Chrome-tagged tests and startup self-check; C8 |
| C-2 frame-interval verdict flips on jitter | resolved (owner decision) | S4 refined; D4 calibrate step and missed-frame rule. See M-1 below for a remaining gap in how missed frames are counted. |
| M-1 step timeout vs traversal | resolved | D4 script: 2× planned + 10s per step; durations stated |
| M-2 who drives the controllers | resolved | D4 "Who drives what"; State & Ownership |
| M-3 semantics-based start | resolved | D4 `?bench=1`; rejected accessibility-tree start |
| M-4 merged cells across the pinned edge | resolved | D1: group headers merge no cells |
| M-5 `List.sort` stability | resolved | D2 self-written merge sort with row-index tie-break; C8 |
| M-6 xorshift32 masking | resolved | D7 masking plus golden test on VM and Chrome |
| M-7 `serve` index fallback | resolved | D5 plain 404; ledger row. See M-4 below for the missing carried constraint. |
| M-8 forced-renderer fallback uncited | resolved | A8 |
| M-9 carried constraints | resolved | C6, C7 |
| M-10 citations | resolved | riverpod.md:25; webbuild.dart:213-221; A7 |
| S-a hand-speed segment | resolved | D4 step 2 |
| S-b sample cap | resolved | Resource Bounds: 100,000 samples |
| S-c puppeteer lock changes | resolved | A2 |
| S-d web-only seam | resolved | D4 `BenchHost` |
| S-e bootstrap literal form | resolved | D8 |
| S-f C3 destination | resolved | C3 → `WebBuildChecker` |
| S-g ADR 0003 note | resolved | ADRs section |
| S-h visible states | resolved | D3 seed after first frame, `lastError` |

### Critical (blocking)

None.

### Moderate

**M-1. The missed-frame ratio counts a long stall as one missed frame, so visible hitches can pass the "go" budget (S4, D4 Verdict).**
S4 and D4 define the ratio over intervals: "a frame is missed when the time between frames exceeds 1.5× the display's measured refresh period", at most 5%. The hand-speed segment is 20s, about 1,200 intervals at 60 Hz. A 500ms main-thread stall is one interval, so it adds one "missed frame", not about 30. Ten such stalls (5s of frozen screen in 20s) give 10/1,200 ≈ 0.8% missed, and they sit exactly at the p99 boundary (the 12th-worst interval), so p99 ≤33ms can also pass. The agent's verdict can then say "go" for a run with visible hitching. S7 catches it on the owner's laptop only by eye, and the agent's report is the deliverable of the agent criterion.
Fix: count dropped vsyncs, not intervals. Each interval contributes `max(0, round(interval / period) − 1)` missed frames, and the ratio is missed / (missed + intervals). Or add a cap on the worst interval (for example ≤100ms). S4 is `Chosen by: user`, so this goes to the owner first (Required Change 1).

**M-2. The ≤300ms operation budget times the engine only. The user-visible latency of filter, group and sort is never judged (S4, D2, D4, Risks).**
D2 has each operation return "its elapsed time from a `Stopwatch`" around the pure engine function. D4 records "each query operation's time". The Risks section keeps "Query timings and frame timings ... separately". S4 says "Filter, group or sort over 200,000 rows finishes in ≤300ms on the main thread", which the owner will read as "the result is on screen in ≤300ms". The rebuild after a query (new `Ready`, new `GridView`, a `TableView` with a new row count and fresh span metrics, the scroll reset) happens after the stopwatch stops. The operation steps are outside the judged hand-speed segment, so the frame metrics never see that rebuild either. A fast engine with a slow first frame after each query gets "go", while typing in the filter visibly lags. This is exactly the "[`TableView` overhead hides engine speed]" risk, but in reverse.
Fix: in D4, also record each operation's time from the notifier call to the end of the next rendered frame (for example the next persistent-frame callback after the new state, plus raster time when A1 holds), report both numbers, and say in S4 which one the 300ms budget judges. This changes what S4 measures, so it goes to the owner first (Required Change 2).

**M-3. The proposal's ADR 0005 rationale is contradicted by ADR 0005 itself, and a client-side "go" could be read against the architecture (proposal line 11, S2 Rejected; architecture resource bounds).**
The proposal lists "0005 (solo mode has no server, so client-side handling of big tables matters)", and S2 rejects server paging partly because it "doesn't test the client-only path that solo mode needs". ADR 0005 says "Web has no solo mode" and "Corp and alliance features are server-only". architecture.md maps "Corp asset tables" to "Filtering, grouping and totals in SQL; virtualised grid (M0 spike)". So on the web build this spike measures, the client-only query path serves no mode the ADRs allow for corp tables. S2 still stands on its other reason: no Postgres, endpoint or Docker stack in the spike. The roadmap criterion ("outside the widget tree") is also met either way. But the stated motivation is wrong, and C5 only guards one direction. It warns a server-data grid not to rely on client numbers, but nothing stops the report's client-side "go" from being cited later as a reason to move corp-table grouping off SQL on web, against ADR 0005 and the architecture. The S4 "adjust" fixes ("server paging") are also already the architecture's plan for corp tables, which the report should say.
Fix: correct the proposal's ADR 0005 line and S2's rejected-alternative wording. The client-side engine measures main-thread cost as a worst case and for desktop solo and the offline cache; web never runs solo. Widen C5 so the report's client-side numbers do not change where corp-table filtering, grouping and totals run (architecture resource bounds, ADR 0005). S2 is `Chosen by: user`, so the wording change goes to the owner (Required Change 3).

**M-4. The `serve` 404 contract for `/font-fallback/*` is not a carried constraint, although the Mechanism Ledger names the change that would break it (D5, Carried constraints).**
D5 rejects an `index.html` fallback partly so that "`/font-fallback/*` gets a 404 as it does under Caddy" (deploy/Caddyfile:26-35; app/web/flutter_bootstrap.js:4-8 "keep the two paths identical"). The Mechanism Ledger's "Evidence that would change the call" for the SPA fallback is "A routed app served through `serve`", which is a foreseeable future change. A change that adds the fallback without also exempting `/font-fallback` would return `index.html` with 200 for font requests, the failure round-1 M-7 described. C4 covers only "dev server, loopback, never deployed". No entry carries this rejected alternative.
Fix: add a carried constraint with one destination (Required Change 4).

### Suggestions

- **S-a. Publish aborts to the runner.** `window.gridBenchResult` is written "once at `Done`" (State & Ownership), so an `Aborted(reason)` run leaves the runner polling for its full 10-minute timeout. The row is then recorded as a timeout without the abort reason. Writing `{schemaVersion: 1, aborted: reason}` (or a separate `window.gridBenchError`) on `Aborted` would make the row fail fast with its cause. If it is part of the JSON, C6 applies.
- **S-b. LAN serving loses cross-origin isolation.** D5 lets the owner pass a LAN `--host`. A page loaded from `http://<LAN address>` is not a secure context, so COOP/COEP give no `crossOriginIsolated` and skwasm runs single-threaded. The toolbar shows the thread mode, but the report should state that the S7 laptop run is single-threaded unless it is served on the laptop itself, so the owner's judgment and the agent's best-case numbers are not silently different modes.
- **S-c. Collapsing a group jumps to the top.** Collapsed groups are part of `GridQuery` (D3), and "Scroll offsets ... Reset to top on query change" (State & Ownership; Flow & State Gaps). Collapsing a group deep in the list therefore throws the owner back to row 0 during the S7 judgment. Consider keeping the offset (or the group header's position) on `toggleGroup`.
- **S-d. Error text and the Riverpod guide.** docs/guides/riverpod.md:47 says "the UI must not show exception text". D3's `lastError` carries "its message" and Failure & Visibility shows "an inline banner from `lastError`". Keep `lastError` and `SeedFailed` typed (which operation or which self-check failed), show that, and send the exception message to the console only.
- **S-e. Citation drift.** Context "Naming" cites `workspace.dart:180-200`. `_namingProblems` is at `workspace.dart:186-201`, and 180-185 is the end of the discovery walk. The claim holds, so cite 186-201.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

All four verified applied in the re-check run (2026-11-17). Each was checked against the owner's decision and against every place the round-2 text named; no new contradiction was found among the edited passages.

1. **S4 and D4 Verdict: missed-frame counting (M-1).** Verified, owner option (a). proposal.md S4 Choice (line 73) counts skipped display refreshes, `max(0, round(interval / period) − 1)` per interval, ratio missed / (missed + intervals), limit ≤5%, and records the round-2 owner choice. design.md D4 "Verdict per S4" (line 132) uses the same formula with the period from the calibrate step (line 107). Decision summary S4 row (design.md line 229) reads "≤5% missed frames (skipped refreshes)". D4 Result (line 137) carries "every figure above" in the JSON, so the field list follows the change.
2. **S4, D4 Recording and Risks: operation latency (M-2).** Verified, owner option (a). design.md D4 Recording (lines 123-127) records engine time and time until on screen (notifier call to the end of the first rendered frame showing the new view, plus raster time when A1 holds); both go in the JSON and the report. D4 "Verdict per S4" (line 135) judges "every operation's time until on screen ≤300ms". proposal.md S4 (line 73) says "on screen in ≤300ms ... with engine time reported alongside". Risks bullet on `TableView` overhead (design.md line 401) reports both and says the budget judges time until on screen. Summary S4 row (line 229) reads "ops on screen ≤300ms". D2's per-operation `Stopwatch` (design.md line 75) remains the engine-time figure, consistent with this.
3. **Proposal line 11, S2 Rejected and C5 (M-3).** Verified, wording as proposed. proposal.md line 11 matches the proposed ADR 0005 text exactly. S2 Rejected (proposal.md line 58) no longer cites "the client-only path that solo mode needs"; it keeps the Postgres/endpoint/Docker reason and states the client-side engine measures the main-thread worst case and the desktop solo and offline-cache path, "web never runs solo, ADR 0005". C5 (design.md line 260) carries the added sentence verbatim; its kind (rejected alternative) and single destination (grid_engine.dart library) are unchanged.
4. **Carried constraints (M-4).** Verified. C9 (design.md line 263) matches the required text verbatim, with kind "rejected alternative" and one destination (`tools/kaname_tools/lib/src/serve.dart ServeCommand.run`). It is listed between C7 and C8, which is cosmetic only.

Note, not a Required Change and no effect on the verdict: design.md's ADRs section (line 409) still reads "0005: solo mode motivates the client-side case." It was not part of Required Change 3 and does not contradict the edits (desktop solo is still a motivation), but the author may align it with proposal line 11 ("web has no solo mode; corp tables server-only with SQL grouping") in a later edit if it wants the two to read the same.

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals

None.
