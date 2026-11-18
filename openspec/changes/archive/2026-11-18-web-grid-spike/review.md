# Review

## Metadata

- **Round:** 3
- **Prior round:** round 2 VERDICT: APPROVE_WITH_CHANGES (4 Moderate, 5 Suggestions), all four Required Changes re-checked applied (CHANGES_APPLIED: yes); voided by commit 0d7b771, a behaviour-change amendment to S4's p99 limit
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** openspec/changes/web-grid-spike/proposal.md, design.md, tasks.md, review.md (round 2, for continuity); `git show 0d7b771`; the review instruction (`openspec instructions review --change web-grid-spike`) and templates/review.md. In-force ADRs: docs/adr/0003, 0004, 0005, 0010 (status lines and the cited passages; 0005:20-21 "Web has no solo mode", "Corp and alliance features are server-only"). Design citations, all git-tracked, re-read at the merge base cbea168 (the state the Context section describes): tools/kaname_tools/lib/src/workspace.dart 74-80, 133-138, 180-201, 231-233; purity.dart 38-39; webbuild.dart 31-33, 58-87, 104-126, 213-221; mise.toml 42-49, 61-64, 71-78, 122-139; .github/workflows/ci.yml 66-67, 77; app/web/flutter_bootstrap.js 4-12; deploy/Caddyfile 26-35; docs/guides/riverpod.md 9-17, 25, 31-50; DESIGN.md 248, 287, 351. To check the amendment's reach, read at HEAD (read-only, `git show HEAD:`): spikes/kaname_grid_spike/lib/logic/bench_metrics.dart, lib/logic/benchmark_result.dart (C6 doc comment and JSON fields), lib/ui/result_panel.dart:188, test/logic/bench_metrics_test.dart, docs/spikes/web-grid.md, openspec/changes/web-grid-spike/evidence/bench-dev-machine.md (verdict blocks). No referenced stores. Skills loaded: dart-use-pattern-matching, dart-write-documentation, dart-add-unit-test, flutter-add-widget-test, flutter-apply-architecture-best-practices, dart-build-cli-app (all six loaded).
- **Re-check:** 2026-11-18, Required Changes 1–3, with the owner's answers as relayed by the coordinator: (1) option (a), "Rounded, below 2.5 periods"; (3) option (a), "Bump to version 2". The edits are uncommitted. I read them with `git diff` on proposal.md, design.md, tasks.md and evidence/bench-dev-machine.md, and grepped the three planning files for every remaining "v1" and `schemaVersion`. Task 9.6 is still open, so I judged the plan, not the work-tree code.
- **Second re-check:** 2026-11-18, items 3a–3d of Required Change 3 and S-d. The edits are uncommitted. I read design.md lines 230, 238 and 329, tasks.md lines 44, 129 and 170-177, and evidence/bench-dev-machine.md line 11, then grepped proposal.md, design.md and tasks.md again for every "v1" and `schemaVersion`. The only test-name check was a grep of `benchmark_result_test.dart` for row 44's test name. The plan was judged, not the code.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Amendment consistency (0d7b771)

The new rule reads the same in every planning artifact: proposal S4 Choice (line 73) and its "Amended 2026-11-18" bullet (line 74), design D4 "Verdict per S4" (line 134), the Decision summary S4 row (line 230) and tasks.md 7.2 (line 121) all state `round(p99 / period) ≤ 2` with the period from calibration. Every other S4 element (≤5% skipped refreshes, work p90 ≤16.7ms where reported, operations on screen ≤300ms) is unchanged in all five places. No carried constraint names the old 33ms literal. Citations in Context re-read at the merge base all still support their claims. The three findings below are where the amendment stops short.

### Critical (blocking)

None.

### Moderate

**M-1. The "about 33.3ms at 60Hz" gloss contradicts the formula it annotates. The formula passes p99 up to 2.5 periods, about 41.7ms (proposal S4 line 73, design D4 line 134).**
Dart's `double.round()` rounds half away from zero, so `round(p99 / period) ≤ 2` holds for every p99 below 2.5 periods: 41.75ms at a 16.7ms period. The parenthetical says the limit is "about 33.3ms at 60Hz", and the amendment bullet calls it "two refresh periods". These describe `p99 ≤ 2 × period`, which is a different rule. The two rules disagree for every p99 between about 33.4ms and 41.7ms. The existing test shows the consequence: `bench_metrics_test.dart` (HEAD, around line 70) asserts that "Two 40 ms intervals out of 100 put p99 at 40 ms" gives `p99Ok` false. Under the formula, `round(40 / 16.7) = round(2.40) = 2`, so it passes. Under "two periods, about 33.3ms", it fails. An implementer can satisfy either sentence of the amended text and still contradict the other one, and the report's reader gets the wrong limit. The wording is consistent with how the missed-frame count rounds ("skips at most one refresh"), so the formula is probably what the owner meant, but S4 is `Chosen by: user` and DECISION_MAKING is `all`. The owner should confirm which rule applies before the text is fixed (Required Change 1).

**M-2. The amendment changes behaviour that ticked tasks 7.2 and 9.3 already delivered under the old limit, and no open task carries it into the code, tests or report (tasks.md).**
tasks.md 7.2 was edited in place to say "p99 ≤2 refresh periods as amended" and stays `[x]`. 9.3 also stays `[x]`. At HEAD, the code and report still implement and state the old limit:
- `bench_metrics.dart:15` `const double maxP99Ms = 33;`, `:138` `scroll.p99Ms <= maxP99Ms`, `:151` "within 33 ms";
- `result_panel.dart:188` shows the budget as `≤ ${_ms(maxP99Ms)}`;
- `bench_metrics_test.dart` encodes the 33ms boundary (the 40ms case above, and the "p99 33.0 ms" pass case);
- `docs/spikes/web-grid.md:28` has the budget table row "≤33ms". Line 48 marks CanvasKit "**miss** (missed frames, p99, work)", and line 110 says "p99 33.3ms against 33ms". Under the amended rule, CanvasKit's 33.3ms p99 passes (`round(33.3 / 16.7) = 2`). CanvasKit still misses on missed frames (12.0%) and work p90 (19.3ms), so the "adjust for CanvasKit" verdict stands, but the stated reasons are wrong.

The apply workflow does not reopen ticked tasks, so nothing in the plan makes these edits before archive. The report, which is this change's evidence (S5), would then judge against a budget the proposal no longer states. Fix: add an unticked task for the amendment (Required Change 2).

**M-3. The amendment changes what `p99Ok` means under `schemaVersion: 1`, and C6 does not say whether that bumps the version (C6, D4 Result).**
C6 (design line 262; doc comment on `BenchmarkResult`) says "Any change to its fields bumps the version, so reruns compare only like with like". The JSON stores `verdict.p99Ok` (benchmark_result.dart:165) but not the limit it was judged against. The committed evidence (`evidence/bench-dev-machine.md`) holds `p99Ok` values computed against ≤33ms. A rerun with the amended code would emit `schemaVersion: 1` with `p99Ok` computed against `round(p99 / period) ≤ 2`, so the same p99 of 33.3ms reads `false` in the evidence and `true` in a rerun under the same version. That is exactly the unlike comparison C6 exists to prevent. The field set did not change, so C6's wording ("a change to its fields") arguably does not trigger, and that gap is the finding. Fix: decide and record one of these (Required Change 3), which goes to the owner because D4 is `Chosen by: user`:
- (a) bump to `schemaVersion: 2`, and widen C6 to "a change to its fields or to a verdict rule";
- (b) keep version 1 but add the judged limits (for example `p99LimitPeriods: 2`) to the JSON, so each file says what it was judged against. This is still a field change, so it implies (a) under C6 as written;
- (c) keep version 1 and record in the report that the evidence's `p99Ok` values predate the amendment and are recomputed in the report from `p99Ms` and the period.

Recommendation: (a). It is the smallest change that keeps C6 honest, and it needs no report caveat.

### Suggestions

- **S-a. Name the old limit as rejected.** S4's Rejected list (proposal line 75) and the summary row's Rejected cell do not list "a literal p99 ≤33ms". The amendment bullet gives the reason (it fails on a single skipped refresh at 60Hz), so adding it to Rejected keeps a later edit from quietly bringing the fixed-millisecond form back. *Re-check:* added to the proposal's Rejected list (line 75), along with a strict `p99 ≤ 2 × period`. The design's S4 summary row Rejected cell (line 230) still reads "30fps and 1s; no budget; work time only; time between frames + margin"; see Required Change 3, item 3b. *Second re-check:* the summary row's Rejected cell now lists both (design line 230).
- **S-b. Boundary tests for the rule.** When 7.2's follow-up lands, test p99 at 2.49 and 2.5 periods (pass and fail under the formula), and at a non-60Hz period (for example 6.94ms at 144Hz). The 60Hz-only tests cannot tell the period-based rule from a millisecond constant. *Re-check:* carried into task 9.6 ("at exactly 2.5 periods and at a 144Hz period as well as 60Hz").
- **S-c. Carry-over from round 2.** design.md's ADRs section (line 410) still reads "0005: solo mode motivates the client-side case", which reads differently from proposal line 11. No effect on the verdict.
- **S-d (re-check). The evidence note covers only the current run.** The note added to `evidence/bench-dev-machine.md` (line 11) re-judges the current run's CanvasKit p99 and says "No other verdict changes". The earlier run's CanvasKit block also flips: its p99 is 33.335ms at a 16.67ms period (2.0 periods), with `p99Ok: false` at line 1349. The report doesn't quote that run, so nothing depends on it, but the note could say "in the current run" in its last sentence or name the earlier block too. Not a Required Change. *Second re-check:* applied. Line 11 now also re-judges the earlier run's CanvasKit p99 (33.335ms over 16.67ms, which passes), and that row stays a miss.
- **S-e (second re-check). The test-map row names a v1 test.** tasks.md row 44 now describes "result JSON v2 fields (v1 until task 9.6)", but its Test name column still reads "result JSON v1 and abort publication". That is the test's real name (`benchmark_result_test.dart:10`), so the map is accurate today. When 9.6 updates that test, renaming it to v2 and updating the column keeps the map from naming a version the test no longer checks. Not a Required Change.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **Clarify the p99 bound (M-1). Put it to the owner first: S4 and D4 are `Chosen by: user`.** Options:
   - (a, recommended) keep the formula and fix the gloss. Replace "(about 33.3ms at 60Hz; amended 2026-11-18, below)" in proposal S4 line 73 with "(an interval rounds to two periods up to 2.5 periods, so p99 passes below about 41.7ms at 60Hz; amended 2026-11-18, below)", and make the same edit to the parenthetical in design D4 line 134. In the amendment bullet (proposal line 74), change "The limit is now two refresh periods, rounded as the missed-frame count rounds" to "The limit is now two refresh periods, rounded as the missed-frame count rounds: p99 passes while `round(p99 / period) ≤ 2`, that is below 2.5 periods".
   - (b) keep "two periods, about 33.3ms" and change the formula to `p99 ≤ 2 × period` everywhere it appears: proposal S4 line 73, design D4 line 134, summary S4 row line 230, tasks 7.2 line 121. Rounding error then decides again near the limit, which is the problem the amendment set out to remove.

   Whichever is chosen, record the owner's words in the amendment bullet.

   **Re-check: applied.** The owner chose (a), "Rounded, below 2.5 periods". Proposal S4 line 73 and design D4 line 134 carry the required parenthetical word for word. The amendment bullet (proposal line 74) carries the required sentence and the owner's words. The formula is unchanged in all five places, so nothing else needed editing.
2. **Carry the amendment into apply (M-2).** In tasks.md, add an unticked task in group 9 (for example 9.6, before 9.5), or untick 7.2 and 9.3 and add the steps to them. The steps:
   - change `bench_metrics.dart` so `S4Verdict` judges p99 against the calibrated period with the rule chosen in Required Change 1, and fix the `p99Ok` doc comment;
   - make `result_panel.dart` show the limit as periods (with the millisecond equivalent from the run's period);
   - update `bench_metrics_test.dart`: the 40ms case, plus boundary cases per S-b;
   - update `docs/spikes/web-grid.md`: the S4 budget table (line 28), the CanvasKit verdict row (line 48; p99 now passes, and the miss stays on missed frames and work) and the CanvasKit verdict bullet (line 110);
   - verify with `mise run test:spike` and `mise run check`.

   **Re-check: applied.** Unticked task 9.6 sits before 9.5 (tasks.md lines 170-176) and covers every step: the `S4Verdict` rule and `p99Ok` doc comment, the result panel in periods with the millisecond equivalent, the boundary tests, the report's budget row and CanvasKit row and bullet, and `mise run check` (which runs `test:spike`) plus `spec:validate`. It does not name the existing 40ms test case. That case would fail `mise run check` once the rule changes, so the task's own verification forces the fix. It also adds a note in the report that the evidence is version 1, which is consistent with Required Change 3.
3. **Settle `p99Ok` versioning under C6 (M-3). Put it to the owner first: D4 is `Chosen by: user`.** Options (a), (b) and (c) as in M-3; (a) is recommended. Record the choice in D4 Result and, for (a) or (b), in C6's text (design line 262) and the `BenchmarkResult` doc comment step of the task from Required Change 2.

   **Re-check: partly applied.** The owner chose (a), "Bump to version 2". These parts are done:
   - D4 Result (design line 138) says `schemaVersion: 2` and the reason;
   - C6 (line 262) is widened to "fields or to a verdict rule" and keeps one destination;
   - task 9.6 bumps `BenchmarkResult`, its doc comment and the runner;
   - the proposal's amendment bullet records the owner's words.

   Four places in the plan still say version 1, so the decision and its summary disagree, and an implementer following the ticked text gets mixed instructions:
   - **3a.** design.md Decision summary D4 row (line 238) still says "JSON v1". Change it to "JSON v2". The workflow requires the summary table to follow an applied Decisions change.
   - **3b.** design.md S4 summary row (line 230), Rejected cell: append "; literal p99 ≤33ms; strict p99 ≤2 × period", matching proposal line 75 (from S-a). Same rule.
   - **3c.** design.md benchmark sequence diagram (line 329): change `window.gridBenchResult = JSON v1` to `JSON v2`.
   - **3d.** tasks.md: the test map row at line 44 ("result JSON v1 fields", test name "result JSON v1 and abort publication") and task 7.3's Result bullet (line 129: `schemaVersion: 1` and `{schemaVersion: 1, aborted: reason}`). Leave 7.3 ticked, but either say "v2 (from 9.6)" in both places or add to 9.6 that the abort payload and `benchmark_result_test.dart` move to version 2. 9.6 names `BenchmarkResult` and the runner, but not the abort payload or its test.

   Once 3a–3d are made, Required Change 3 is complete. They are edits to make the text agree with what the owner already chose, so they need no new owner decision.

   **Second re-check: applied.** Required Change 3 is now complete:
   - **3a:** the D4 summary row (design line 238) reads "JSON v2 (v1 until the 2026-11-18 p99 amendment)".
   - **3b:** the S4 summary row's Rejected cell (line 230) ends "literal p99 ≤33ms; strict p99 ≤2 × period", matching proposal line 75.
   - **3c:** the sequence diagram (line 329) reads `JSON v2`.
   - **3d:** test-map row 44 now says v2 fields, with v1 until 9.6. Ticked task 7.3 (line 129) marks "2 since task 9.6". Its aborted-run payload still reads `{schemaVersion: 1, aborted: reason}`, which is the record of what 7.3 delivered. Task 9.6 (line 174) now names the payload as `{schemaVersion: 2, aborted: reason}` and the four test files, so the open task carries the change, as option 3d allowed.

   A final grep of proposal.md, design.md and tasks.md finds "v1" or `schemaVersion: 1` only in historical notes (C6, D4 Result, the D4 summary row, 7.3, test-map row 44) and the test name covered by S-e. None of them instructs anyone to implement version 1.

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals

None.
