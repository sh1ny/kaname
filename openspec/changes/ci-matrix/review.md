# Review

## Metadata

- **Round:** 5
- **Prior round:** 4: APPROVE_WITH_CHANGES (C10, the task 2.2/2.3 fixtures and negatives, and tracked `THIRD_PARTY_NOTICES` citations; all three applied and re-checked, changes marked applied). An apply-time amendment to assumption A5 (task 5.1) voided that verdict. This round re-checks that amendment.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - The uncommitted amendment (`git diff -- openspec/changes/ci-matrix/design.md`). It changes one line, A5 (design.md:182). It adds `libstdc++-12-dev` to the apt package list and replaces "Not checked against Flutter 3.47's Linux setup docs" with a checked part (Flutter's Linux setup docs, task 5.1, 2026-11-15) and an unchecked part (whether the docs' list is complete for Flutter 3.47.9, which task 6.2 confirms).
  - openspec/changes/ci-matrix/design.md: Triage, Context, D9 to D12, the decision summary, Assumptions A1 to A6, Carried constraints, State & Ownership, Failure & Visibility, Resource Bounds, Mechanism Ledger, Risks, ADRs.
  - openspec/changes/ci-matrix/review.md (round 4).
  - openspec/changes/ci-matrix/tasks.md: the test map (rows for the three-OS checks and the six-target builds) and tasks 5.1, 5.2, 5.3, 6.1 and 6.2.
  - openspec/changes/ci-matrix/specs/continuous-integration/spec.md: Requirement "CI builds all six app targets" (lines 54-67).
  - The review template, openspec/schemas/specwright/templates/review.md, and `openspec instructions review --change ci-matrix`.
  - Not verifiable from the repository: the Flutter Linux setup docs (Context7 `/flutter/website`, platform-integration/linux/setup.md) and the GitHub runner-images contents that the apply step reported for A1. These are external sources, not tracked files. They are taken as reported by the apply step. The owner's choice to add the sixth package, recorded in A5, is not verifiable from the artifacts either.
  - Skills: none named for this review. Referenced stores: none configured.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

Rounds 1 to 4: all Critical and Moderate findings stay resolved. The amendment touches only A5, so none of them is affected: D4, D8, C10, A2, A4 and A6 are unchanged. Round 4's open suggestions 4 to 6 (the appendix slot window, "more than one SPDX id", and the spec clarification) stay open and non-blocking, as before.

### Attempts to break the amendment

The attempts made, and what they showed:
- **Does the amendment reverse a decision?** No. A5 is an assumption, not a decision. No `Chosen by: user` entry or summary row changes. D10 (caching) and D12 (runner labels) do not name apt packages, so neither needs an edit.
- **Does the package list reach the work?** Yes. Task 5.3 says "install the Linux apt packages from 5.1" (tasks.md:100), and task 5.1 records its findings in the PR description (tasks.md:98). The sixth package therefore reaches `ci.yml` through 5.1's findings, and no task text needs to change. The design does not list the packages anywhere else that would now disagree with A5. The Context bullets, the decisions and the Risks section do not mention them.
- **Is the unchecked part covered?** Yes. A5 now names what remains unchecked, whether the docs' list is complete for Flutter 3.47.9, and says who settles it: the Linux build job on this change's own PR, captured by task 6.2. Task 6.2 is an `[evidence]` task that requires every job's conclusion to be `success` (tasks.md:108). The build row of the test map already cites "evidence: task 6.2" for "All targets build" (tasks.md:18). A missing package therefore turns `build (linux)` red on the PR, and task 6.2 cannot be ticked. That matches the Failure & Visibility row for the `build` job ("The build error is in the log; that target is red").
- **Spec contract.** The requirement builds Linux "in release mode … on a Linux runner" (spec.md:55). It says nothing about how the runner is provisioned. Adding a package keeps the spec's THENs assertable and changes none of them.
- **A version-specific package name and runner bumps.** `libstdc++-12-dev` is tied to the GCC 12 packaging of Ubuntu 24.04. A later runner bump (D12) to an image without that package would fail at the apt step. That failure happens in the reviewed PR that bumps the label, which D12 already treats as a reviewed change. The Failure & Visibility table already covers a broken build job, and the Risks section covers an incomplete runner image (A1). So the failure is visible, and nothing new is needed.
- **Claims.** A5 cites no file in the repository. It names an external source (Context7 docs) and its check date, which is the right form for an assumption checked during apply. No tracked range needs re-reading, and no untracked or outside path is cited.
- **Carried constraints.** The amendment adds no rejected alternative, invariant or deliberate gap. C1 to C10 are unchanged. Keeping the apt list in step with Flutter's docs is ordinary maintenance that a failing build job enforces, not a constraint a future change could break silently.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

7. **A1 still reads "Not checked", although task 5.1 has now checked it. Open.**
   - A1 (design.md:177) still says "Not checked because the runner image lists are external and change". According to the apply step, A1 held:
     - `ubuntu-24.04` has the Android SDK with android-36;
     - `windows-2025` has Visual Studio 2022 17.14 with the NativeDesktop workload;
     - `macos-15` defaults to Xcode 16.4.
   - A2, A4 and now A5 each carry a "Checked during apply" note, but A1 does not, so a later reader of the design cannot tell that it was verified. Task 5.1 puts the findings in the PR description, so nothing is lost before merge. Once the change is archived, though, the design is the lasting record.
   - The fix is to add a "Checked during apply (task 5.1, 2026-11-15)" sentence to A1 in the same form as A5. Any such edit to design.md voids this verdict and needs a re-check, so it is best batched with any other apply-time amendment.
8. **The Android NDK is downloaded on every build run. Open, informational.**
   - The apply step found that Flutter's default NDK (28.2.13676358) is not preinstalled on `ubuntu-24.04`, so AGP downloads it during `build (android)`. D10 caches only mise tools and the pub cache, so every Android build downloads the NDK again.
   - The job's 45-minute `timeout-minutes` bounds the cost. The Mechanism Ledger already names the trigger for reconsidering the cache: "Android/iOS builds over ~15 minutes". No change is needed now.
   - Task 6.2 records each job's name, runner and conclusion, but not its duration. The `startedAt` and `completedAt` fields of `gh run view --json jobs`, which task 6.2 already queries, would give the measurement the ledger asks for. If the NDK download pushes `build (android)` past that threshold, the follow-up is a D10 change, and D10 is `Chosen by: user`, so it goes to the owner.

## Verdict

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals

- **Rounds 1 to 4:** see the round 4 record. Every Critical and Moderate finding from rounds 1 to 4 was fixed and accepted by the reviewer, and the A5 amendment reopens none of them.
- **Suggestions 4 to 6 (round 4) and 7 to 8 (round 5):** open, non-blocking.
