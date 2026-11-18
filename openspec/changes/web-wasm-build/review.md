# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 was REVISE: 1 Critical (the new checks broke the grid spike's `build:spike` and `bench:spike`), 1 Moderate (the stack `http` helper cannot read headers or binary bodies), 4 Suggestions. The author reports all six as fixed.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** openspec/changes/web-wasm-build/proposal.md, specs/web-build/spec.md, design.md, review.md (round 1 with the author's responses); openspec/architecture.md (in-force ADR index); docs/adr/0001-stack-platforms-and-deployment.md; openspec/roadmap.md (M1 and its exit criteria); openspec/specs/ember-ui/spec.md, self-host-stack/spec.md, continuous-integration/spec.md; docs/spikes/web-grid.md; mise.toml (125-200, 254-268); .github/workflows/ci.yml (60-130, stack job steps); tools/kaname_tools/lib/src/webbuild.dart (whole file); tools/kaname_tools/test/ci_workflow_test.dart (290-315, 590-612); app/web/flutter_bootstrap.js; spikes/kaname_grid_spike/web/flutter_bootstrap.js; deploy/Caddyfile; deploy/compose.yaml (100-120); deploy/README.md; server/kaname_client/test/stack/stack_test.dart (1-40, 170-205); server/kaname_client/test/stack/support/stack_support.dart (140-195). Every file opened is git-tracked, and none is a symlink. A `git grep` over app/, app_packages/ and packages/ found no `dart:html`, `dart:js`, `dart:js_util` or `package:js` import. Skills loaded: dart-use-pattern-matching, dart-write-documentation, dart-run-static-analysis, dart-add-unit-test, dart-build-cli-app. Re-check run: design.md D2 (line 41) and A6 (line 94) only.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

1. **D2 depends on an unrecorded claim about the inlined loader, and its key rule leaves the token boundary open.** D2 (design.md:41) says "Property reads in the inlined loader (`e.forceSingleThreadedSkwasm`) are not keys and are ignored." This is a claim about existing generated code. It has no citation (the loader is ignored build output) and no Assumptions entry: A5 covers the loader's allow list and warning condition, not whether it ever writes `forceSingleThreadedSkwasm` as an object key. The checker scans the whole built bootstrap. `{{flutter_js}}` inlines the loader there (app/web/flutter_bootstrap.js:1), and the existing `fontFallbackBaseUrl` check already reads the whole script (webbuild.dart:110-111). Suppose the minified loader holds `{forceSingleThreadedSkwasm:e.forceSingleThreadedSkwasm}` or a conditional such as `a?e.forceSingleThreadedSkwasm:b`, and the matcher is the obvious one, modelled on `_fallbackSetting` (webbuild.dart:37-39), which has no left boundary. Then `--single-threaded` finds a non-literal value, and every product `webbuild:check` fails: locally, in CI's web job, and in `stack:up`, which goes through `build:web` (mise.toml:254-261). Two consequences follow. The first apply build hits a failure the design did not plan for. And the check's rule has to be re-decided under decision mode `all`. The rule should say when an occurrence counts as a key: not preceded by `.` or an identifier character, and followed by an optional closing quote, whitespace and `:`. The assumption should be recorded, with the first apply build confirming it. **Status (re-check run): fixed by Required Changes 1 and 2. See design.md:41 and design.md:94.**

### Suggestions

2. **Nothing tests that the product tasks pass `--single-threaded`.** The requirement "The product build check requires single-threaded skwasm" (spec.md:161-162) says the local, CI and stack builds ask for the thread-mode check and the spike does not. CI reaches it only through `mise run webbuild:check` (ci.yml:107-109). `ci_workflow_test.dart` checks only that this step exists (`ci_workflow_test.dart:306-308`), and that `build:web` chains `webbuild:check` (`605-608`). If a later edit drops the option from the `webbuild:check` task, every check stays green, and the product build loses the guard that D2 and the mechanism ledger call necessary. Add assertions to `ci_workflow_test.dart` that the `webbuild:check` task's `run` passes `--single-threaded` and that `build:spike:check` does not. That maps the requirement's task clause to an automated test.

3. **Record the user-facing text updates in a decision, not only in Context.** The round-1 fix for the stale command text is a Context citation (design.md:26) plus a note that "tasks will update" it. No Decision or Carried constraint says the text changes. The mise task descriptions also describe only the self-contained rule: `build:web` and `webbuild:check` (mise.toml:134, 149), and `build:spike:check` (mise.toml:170). Add one sentence to D2/D3 listing the `--check` help, the command description, the success line, the class doc comment and these three task descriptions. Then tasks.md has a design line to trace them to.

Round-1 fixes verified:
- Critical 1: fixed. `--single-threaded` is opt-in: D2 (design.md:41), C1 (design.md:97), and spec.md:161-174, including the scenario "Spike build without the thread mode check". The wasm-build check still runs on every build, and the spike's `--wasm` output meets it (mise.toml:164-167, A4). The spike's bootstrap keeps its `?threads=` switch (spikes/kaname_grid_spike/web/flutter_bootstrap.js:18-35).
- Moderate 2: fixed. D4 (design.md:57) and Context (design.md:25) extend the helper. The proposal's Impact lists `stack_support.dart` (proposal.md:28). The cited helper lines show the gap that is being fixed (stack_support.dart:154-155, 174-178).
- Suggestion 3: fixed in substance: D2 states the key rule, and spec.md:168-170 covers a missing setting, `false` and a variable value. The remaining gap was finding 1, now fixed.
- Suggestion 4: fixed. D3 checks the order, and the spec has the scenario "Fallback listed first" (spec.md:157-159).
- Suggestion 5: fixed. The scenario "No single-threaded warning" (spec.md:119-121) maps to D5's browser run, an agent task.
- Suggestion 6: partly fixed: Context cites the text. See finding 3.

Claims check: every other cited range supports its claim. Checked: mise.toml:133-141, 143-146, 148-150, 164-167 and 169-171; ci.yml:72, 77 and 107-109; ci_workflow_test.dart:299-310 and 597-608; webbuild.dart:18-22, 37-40, 43-62, 64-83, 110-131, 153-168, 198-204, 214-216 and 233; app/web/flutter_bootstrap.js:9-16 and 13-15; spikes/kaname_grid_spike/web/flutter_bootstrap.js:18-35; Caddyfile:8-43 and 38-42; compose.yaml:106 and 113-114; stack_test.dart:179-198; stack_support.dart:174-178. The app-code grep claim (design.md:27) holds. A1-A6 rest on unchecked or ignored sources and are recorded as assumptions. Carried constraints C1-C3 each have exactly one destination. No contradiction was found with ADR 0001, or with the `ember-ui`, `self-host-stack` or `continuous-integration` specs. The `ember-ui` self-contained requirement and the `self-host-stack` single-page-app fallback still hold, and the "Missing wasm file" scenario is consistent with that fallback.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. In design.md, D2 **Choice** (design.md:41), replace the sentence "Property reads in the inlined loader (`e.forceSingleThreadedSkwasm`) are not keys and are ignored." with: "An occurrence counts as a key only when it is not preceded by `.` or an identifier character and is followed, after an optional closing quote and whitespace, by `:`. Property reads in the inlined loader, including one inside a conditional such as `a?e.forceSingleThreadedSkwasm:b`, are not keys and are ignored; the checker's tests include a fixture with both forms (A6)."
2. In design.md `## Assumptions`, add after A5: "- **A6:** The pinned Flutter's generated `flutter.js`, which `{{flutter_js}}` inlines into the built bootstrap, reads `forceSingleThreadedSkwasm` only as a property and never writes it as an object key. Not cited because the loader is generated, ignored output. Depends on it: D2. If it is wrong, `webbuild --check --single-threaded` fails on every product build. The first apply build confirms it, and a failure goes back to the owner with the matching loader text."

These edits make D2's rule precise and record its assumption. They do not reverse the owner's choice in D2.

This run re-checked only these two items, and both are applied as written:
1. Applied. design.md:41 holds the required key-boundary sentence, names the ignored property-read forms (including `a?e.forceSingleThreadedSkwasm:b`), and requires a test fixture that cites A6. The superseded sentence is gone.
2. Applied. design.md:94 holds A6 with the required text, directly after A5.

CHANGES_APPLIED: yes

## Rebuttals

