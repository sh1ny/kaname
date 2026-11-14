# Review

## Metadata

- **Round:** 3
- **Prior round:** 2: APPROVE_WITH_CHANGES (Dependabot exemption, D4 header block, npm sidecars, `sky_engine` licence; all four applied and re-checked, CHANGES_APPLIED: yes). An amendment made during apply (D8, A2, the D8 summary row, the tasks.md "Checksum mismatch" row, tasks 1.4 and 1.5) voided that verdict.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - First pass: the uncommitted amendment (`git diff -- openspec/changes/ci-matrix/`), openspec/changes/ci-matrix/proposal.md, design.md (in full), review.md (round 2), tasks.md, specs/continuous-integration/spec.md (the requirement "CI uses the toolchain pinned in mise.toml" and its scenarios), the ADR list under docs/adr/ (0001 and 0002 are the ones that bear on CI; the amendment does not touch them) and mise.toml.
  - External sources: mise's lockfile reference at v2026.11.8 (`docs/dev-tools/mise-lock-reference.md`, sections "Format versions", "Entry fields", "npm package provenance" and "Native dependency sidecars"), mise's 2026.11.1 release notes, and the npm registry metadata for `@fission-ai/openspec@1.16.0` (`dist.attestations.provenance`).
  - Re-check pass (this file): the round 3 Required Changes only, through the updated uncommitted diff. That covers design.md D8, its summary row, A2, the new A6 and the new Risks entry for A6, plus tasks.md task 1.4, task 1.5 and the "Checksum mismatch" test-map row.
  - Not opened: `mise.lock` and `.mise/locks/`, which are still untracked (`git ls-files` returns nothing). The apply-time evidence recorded in A2 was therefore not opened, and is judged as recorded evidence.
  - Skills: none named for this amendment. Referenced stores: none configured.

## Findings

Round 1 and 2 status: all findings resolved (see the round 2 review). Round 2 suggestion 8 (SPDX `-only` spelling) is still open and still not blocking. The amendment does not touch the round 1 or round 2 resolutions. D8 still names the `.mise/locks/` sidecars, C2 still regenerates them together with `mise.lock`, and the "npm dependency graph missing" scenario is unchanged.

The amendment itself is sound. The mise reference supports it: an `npm:` entry carries `aube = { path, digest }` (field added in format 2), and platform metadata applies only to archive tools. The format-4 claim also holds: the release notes say new lockfiles are written at revision 4 from 2026.11.1 on. Splitting the repository test's rule by tool kind fixes a real defect in the old task 1.4: an `npm:` entry has no `platforms.*` tables, so a test that required three platform checksums on every tool could never pass.

### Critical (blocking)

None.

### Moderate

1. **The format-4 npm provenance pin is not planned, so the committed `mise.lock` will churn: resolved.**
   - What was found: from 2026.11.1 on, `npm.provenance` is on by default, and only `mise install` writes the `provenance = { repository }` field, never `mise lock`. OpenSpec 1.16.0 publishes SLSA provenance. So a lockfile made with `mise lock` on a machine where OpenSpec is already installed would carry no pin. A fresh clone's first install would then rewrite the tracked `mise.lock`, and CI would not enforce the source repository.
   - The owner chose to commit the pin. D8 stays `Chosen by: user` and records the choice, consistent with the rule for user decisions.
   - D8 now states that format 4 adds the pin, that OpenSpec 1.16.0 publishes provenance (`github.com/Fission-AI/OpenSpec`), and that `mise lock` does not write it. It also gives the procedure: `mise lock --platform …`, then `mise install --force` on each `npm:` tool, then commit.
   - The test-map row and task 1.4 require `provenance.repository` on `npm:` entries.
   - Task 1.5 runs `mise install --force npm:@fission-ai/openspec`. It stops if the `provenance` line is missing, and it requires `git diff -- mise.lock .mise` to be empty after `mise install --locked` on the staged files. That check is equivalent to the requested `git status --porcelain` check.
   - The summary row is updated. A2 records that a scratch run added the expected pin. This matches the lockfile reference ("run `mise lock --upgrade` and then `mise install --force`").

2. **D8's integrity claim for npm packages has neither a citation nor an Assumptions entry: resolved.** The claim is now split into a checked part and an unchecked part:
   - Checked: A2 records the apply-time evidence. Every package under `packages:` in `.mise/locks/npm-fission-ai-openspec/1.16.0/aube-lock.yaml` has `resolution: {integrity: sha512-…}` (57 of 57).
   - Unchecked: the behavioural claim, that aube checks tarballs against those values, is the new assumption A6, because the mise docs are silent on it.
   - Risks has a fallback: the sidecar digest and the provenance pin still hold, and a gap goes to the owner. OpenSpec is a development-only tool that ships in no build.
   - Task 1.5 confirms the `integrity` values. D8 now cites A2 and A6.

### Suggestions

3. **Key the test's rule on `backend`, and require both halves of `aube`: partly addressed.** Task 1.4 now selects `npm:` tools by their `backend` field and requires a sidecar path and a digest. The `sha256:` prefix check is still open. Not blocking.
4. **"Lockfile out of date" wording: open.** The scenario says "no entry in `mise.lock` for the runner's platform". `npm:` entries have no platforms at all. Not blocking.
5. **D9 is now settled by evidence: open.** Format 4 started in 2026.11.1, so `min_version = "2026.11.1"`. Task 1.1 will record it. Not blocking.
6. **New: the `provenance.repository` rule is unconditional, but D8's statement is conditional.** D8 says an `npm:` entry carries the pin "when the package publishes provenance". Tasks 1.4 and the test-map row require it on every `npm:` tool. Today OpenSpec is the only one and it publishes provenance, so nothing breaks. A future `npm:` tool without provenance would, however, fail the repository test with no way to pass. Either make the test rule conditional (for example, an explicit allowlist of `npm:` tools known not to publish provenance), or say in D8 that every `npm:` tool must publish provenance. Not blocking.
7. **New: CONTRIBUTING should name the `mise install --force` step.** Task 1.6 documents C2's rule that a pin change regenerates `mise.lock` and `.mise/locks/` together. It does not mention the extra `mise install --force` step that D8 now requires for `npm:` tools. A contributor who bumps OpenSpec and runs only `mise lock` gets a failing repository test (the pin is dropped) with no hint why. Add the step to task 1.6's CONTRIBUTING text. Not blocking: the test already catches the omission.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **D8, task 1.4 and task 1.5 (finding 1).**
   - In task 1.5, after `mise lock --platform …`, run `mise install --force npm:@fission-ai/openspec` so the provenance repository pin is recorded (the lockfile reference's own procedure: `mise lock`, then `mise install --force`).
   - Inspect the `provenance` line, then run `mise install --locked` and require that `git status --porcelain -- mise.lock .mise` prints nothing.
   - In D8, state that an `npm:` entry also carries the `provenance` repository pin when the package publishes provenance, and that OpenSpec 1.16.0 does.
   - In task 1.4 and the "Checksum mismatch" test-map row, have the `npm:` rule also require `provenance.repository`. Alternatively, record in D8 why the pin is deliberately left out and how lockfile churn from fresh installs is then avoided.
   - D8 is `Chosen by: user`, so put this to the owner first.
   - **Applied** (the owner chose "Commit the pin"; the clean-tree check is done with `git diff -- mise.lock .mise` after staging, which is equivalent).
2. **A2 or D8, and task 1.5 (finding 2).**
   - Either add to A2's checked part the evidence for the integrity claim, plus a reference that aube checks tarballs against it, or list the tarball check as an unchecked assumption, with a fallback under Risks.
   - Have task 1.5 confirm the `integrity` values when it inspects the sidecar.
   - **Applied** (the evidence is in A2; tarball verification is the unchecked assumption A6, with a Risks fallback; the task 1.5 check is added).

CHANGES_APPLIED: yes

## Rebuttals

- **Finding 1:** fixed. See:
  - design.md D8 (the provenance pin, the `mise install --force` procedure, the per-kind test rule) and its `Chosen by` note;
  - the D8 summary row;
  - the A2 scratch-run evidence;
  - tasks.md 1.4, 1.5 and the "Checksum mismatch" row.

  The owner chose "Commit the pin". Accepted by reviewer.
- **Finding 2:** fixed. See:
  - design.md A2 (57 of 57 `integrity` values in the sidecar);
  - the new A6 (aube's tarball verification, unchecked);
  - the new Risks entry for A6;
  - D8's reference to A2 and A6;
  - tasks.md 1.5 (confirm the `integrity` values).

  Accepted by reviewer.
- **Suggestion 3:** partly addressed (task 1.4 selects by `backend`).
- **Suggestions 4 and 5:** not addressed. They are not blocking.
- **Suggestions 6 and 7:** new in this re-check, and not blocking.
