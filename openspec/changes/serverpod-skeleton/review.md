# Review

## Metadata

- **Round:** 4
- **Prior round:** Round 3 re-check (commit dfac727) returned APPROVE_WITH_CHANGES with R3-1 and R3-2 applied and `CHANGES_APPLIED: yes`, leaving Suggestions S-6 to S-11 open (S-2 to S-5 unchanged from round 2).
- **Run:** amendment re-check of commit ae70576 (design.md D7 and A9 only), after drift found during apply group 2. This is not a full re-review. In scope: whether D7 and A9 now match the tracked code and the group 2 working tree, whether any stale `server:generated` remains, whether C9 and the workspace-layout delta still agree with D7, and whether the intent-to-add side effect needs a Failure/State note.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** `git show ae70576`; openspec/changes/serverpod-skeleton/{proposal.md, design.md (D7 :96-102, summary row :169, A9 :187, C8/C9 :199-200, State & Ownership :243-253, Failure & Visibility :255-266, Flow & State Gaps :278-283), review.md (round 3), tasks.md (test map :10, :43, :45; groups 1-2 :60-76; :91, :115), specs/workspace-layout/spec.md}; server/kaname_server/config/generator.yaml (tracked, HEAD and work tree identical); evidence/scaffold.md:50-56 (tracked). Uncommitted group 2 work-tree files, read as evidence of intent only: server/kaname_server/analysis_options.yaml, server/kaname_client/analysis_options.yaml, analysis_options.yaml (root, unchanged), the `server:generate`/`server:drift` tasks and `analyze`/`format:check` tasks in mise.toml, tools/kaname_tools/test/analysis_options_test.dart, evidence/drift-check.md. Repository-wide grep for `server:generated`, `server:drift`, `intent-to-add` and the generated paths. Project skills loaded: dart-run-static-analysis and serverpod-overview (both loaded). No referenced stores.

## Findings

### Amendment re-check

| Item | Status | Evidence |
|---|---|---|
| Task name `server:drift` | Consistent | design.md:98 names `mise run server:drift`. It matches tasks.md:10, :43, :45, :75, :76, :91 and :115, and the work-tree mise.toml task `[tasks."server:drift"]`. |
| No stale `server:generated` | None remains | A grep over the tracked and work-tree Markdown, TOML, YAML and Dart files finds no `server:generated`. The summary row (design.md:169) names no task, so it needed no edit. |
| Generated test tools path | Supported | generator.yaml:4 sets `server_test_tools_path: test/integration/test_tools`, and the tracked file `server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart` exists. evidence/scaffold.md:53-54 records it as generated. The work-tree server `analysis_options.yaml` excludes exactly that file, and the new test derives the file from generator.yaml rather than hard-coding it. |
| Excludes in each package's own options, which include the root | Matches the work tree | Both server packages' `analysis_options.yaml` now `include: ../../analysis_options.yaml` and add only their generated excludes. The scaffold's `recommended.yaml`-only include and its `formatter: trailing_commas: preserve` are gone, so the shared strict modes required by the workspace-layout delta ("The shared analysis options SHALL enable strict casts, strict inference and strict raw types") now govern the server packages. The test asserts both the include and the exact exclude set. These files are uncommitted (group 2). |
| Intent-to-add step | Matches the work tree; works | The work-tree task runs generate, then `dart format`, then `git add --intent-to-add`, then `git diff --exit-code --stat` over the three generated locations. evidence/drift-check.md (uncommitted) shows that a new model and endpoint make the check exit 1, and that it names the two newly created `probe.dart` files. Without the intent-to-add step, `git diff` would have ignored those files. |
| Format check still covers generated code | Holds | `format:check` (mise.toml:42-49) formats every workspace member directory, and the analysis excludes do not affect `dart format`. |
| A9 marked checked | Supported | tasks.md:63 (1.2) is ticked, and scaffold.md:50-56 records the paths that A9 now states. |
| C9 and the workspace-layout delta | Still agree with D7 | C9 (design.md:199) says generated paths are excluded from analysis but format-checked, and its destination is the delta's "Analysis and formatting are clean". The delta says generated code is excluded from analysis and that every Dart file, "generated code included", is in formatter output form. The test tools file is generated, so it falls under both. The "Generated code" scenario is worded per server package, so it covers that file too. No edit is needed. |
| Scope of the amendment | Confined | ae70576 changes only design.md:98 and :187. It does not touch the proposal, the specs or any other decision. |

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

- **S-12 (intent-to-add leaves index entries; no Failure/State note).** When a local `server:drift` run fails because generation created new files, those files stay in the developer's index as intent-to-add entries. Consequences: `git status` lists them as tracked new files, `git commit -a` now commits them, and deleting the files afterwards leaves index entries that need `git reset -- <paths>`. evidence/drift-check.md's revert needed "the index reset" for this reason. In CI the checkout is disposable, so nothing is affected, and the usual fix for drift (commit the regenerated files) uses up the entries. So this does not block. The only record of the cleanup is the comment in the uncommitted mise.toml. Consider one line in D7, or a "drift check fails locally" row in Failure & Visibility (design.md:255-266): "newly generated files stay as intent-to-add entries; commit them, or `git reset -- <generated paths>` to undo". Alternatively, the task could reset those entries itself before it exits.
- **S-13 (drift scope is the test tools directory, D7 names the file).** D7 and the analysis exclude name `test/integration/test_tools/serverpod_test_tools.dart`. The work-tree task instead runs `dart format`, `git add --intent-to-add` and `git diff` over the whole `test/integration/test_tools` directory. If someone later adds a hand-written helper there, the task would reformat it. While the helper is untracked, the task would also add it to the index as intent-to-add and fail drift locally. Narrow the task to the file, or have D7 say "directory", so that the design and the task agree.
- **S-14 (tasks 2.2 and 2.4 wording lags D7).** tasks.md:73 says to exclude the generated paths "in `analysis_options.yaml`", which reads as the root file. D7 now places them in each server package's file. tasks.md:75 lists "generate, `dart format`, `git diff --exit-code`" without the intent-to-add step. The test and the work tree already follow D7, so this is a wording fix to make when the tasks are ticked.
- **S-15 (the comment says "commit", the command compares with the index).** `git diff` compares the work tree with the index, not with HEAD. The work-tree mise.toml comment ("lists every difference from the commit") and the drift-check evidence describe the comparison against the commit. In CI the two are the same. Locally, staged regenerated files would pass. D7 itself only says `git diff --exit-code`, which is accurate. Correct the comment when the task is committed. Separately, the work-tree mise.toml was edited during this review (`--stat` became `--stat=200`). The evidence quotes `--stat`, so align the two before group 2 is committed.
- **S-11 (carried forward unchanged from round 3).** The `serverpod` exception's reason in licence-policy.yaml should cite "ADR 0002; design D13".
- **S-8 (carried forward unchanged from round 3).** The SBOM records no licence for a package excepted as `unrecognised`. Teaching the check `SSPL-1.0` is an owner decision.
- **S-9 (carried forward unchanged from round 3).** A7 (design.md:185) should be marked checked once task 1.1 is committed. Task 1.1 is now ticked, and A7 still reads "Not checked".
- **S-10 (carried forward unchanged from round 3).** The THEN at specs/server-runtime/spec.md:14 cannot be asserted literally. Reword it when the spec is next edited.
- **S-6 (carried forward unchanged from round 2).** The WHEN of the scenario "An analysis info" should say "hand-written code".
- **S-7 (carried forward unchanged from round 2).** C9 is still listed before C8 (design.md:199-200).

Round 2 Suggestions S-2 to S-5 remain as they were.

## Verdict

Commit ae70576 brings D7 and A9 in line with the tracked generator configuration and with the group 2 work tree. The task is `server:drift` everywhere and no `server:generated` remains. The generated test tools file is listed, analysed by neither package and still format-checked. The excludes live in each server package's options file, which now includes the root strict options. C9 and the workspace-layout delta still agree with D7. The intent-to-add side effect is local, documented only in an uncommitted comment, and harmless in CI, so it is a Suggestion (S-12) rather than a Required Change. No Critical or Moderate finding is open. The Required Changes of round 3 stay applied.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R3-1 (C-1).** Applied under the owner's option (b) (dfac727). Unaffected by ae70576.
2. **R3-2 (M-1).** Applied (design.md:201, C10). Unaffected by ae70576.

ae70576 adds no Required Change.

CHANGES_APPLIED: yes

## Rebuttals

- C-1: fixed in dfac727 (ADR 0002 amended in place, option (b), owner decision). Accepted by reviewer.
- M-1: fixed in dfac727 (C10 added). Accepted by reviewer.
