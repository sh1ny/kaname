# Review

## Metadata

- **Round:** 2
- **Prior round:** 1: REVISE - D4 exact template match would reject most locked licences (critical); Dependabot vs signoff, runner label in job names, policy validation without spec home, C2 destination (moderate); 5 suggestions
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** Re-check of the round 2 Required Changes only, plus suggestions 5-7. Re-read: openspec/changes/ci-matrix/review.md (round 2), proposal.md, design.md, specs/continuous-integration/spec.md, specs/dependency-licences/spec.md, specs/contribution-policy/spec.md; new citations `THIRD_PARTY_NOTICES:171`, `:406` (tracked, checked with `git ls-files`) and `:539`; `.gitignore` (the `.mise/locks/` sidecar path is not ignored, checked with `git check-ignore`); mise documentation through Context7 (`/websites/mise_jdx_dev`, "Native dependency sidecars" and "Listing sidecars"), for D8's new claim. No skills were named for this re-check. No referenced stores are configured.

## Findings

Round 1 status (from round 2, unchanged): findings 1-5 and suggestions 6-10 resolved.

Round 2 status:

1. **Forgeable Dependabot exemption (Moderate): resolved.** D6 adds `--pr-author <login>`. CI passes `github.event.pull_request.user.login` to it, and a commit is skipped only when the opener is `dependabot[bot]` and the author identity matches exactly. "Anywhere else that identity is checked like any commit". The exemption is reworded consistently in S6 (proposal), C9, the continuous-integration requirement, the contribution-policy requirement and the proposal's What Changes. The scenario "Bot identity outside a Dependabot pull request" is added. The owner approved the change to S6/D6 ("Chosen by: user", with a round 2 note).
2. **D4 step 2 dropped body lines (Moderate): resolved.** Step 2 now drops only the leading header block: an optional title line, consecutive copyright lines (after any indentation), then an optional `All rights reserved.` line. No line after the first body line is ever dropped. The new citations hold. `THIRD_PARTY_NOTICES:171` is `      copyright notice, this list of conditions and the following` and `:406` is `      (c) You must retain, in the Source form…`. Both are body lines that start with these words. The scenario "Separate rights line" is added. The title moved from the slots into the header block. This is consistent with `:539` ("The MIT License (MIT)" before the copyright line) and with the unchanged "Optional title or appendix" scenario. The decision summary row is updated.
3. **npm sidecars missing from the plan (Moderate): resolved.** `.mise/locks/` sidecars are named in D8, the proposal's Impact, C2, the State & Ownership row and the summary table. The spec adds the scenario "npm dependency graph missing" and puts "its committed dependency-graph sidecars" in the requirement text. The Required Change asked for an extended "Lockfile out of date" scenario; a separate scenario covers the same failure and is equivalent. D8's new claim, that an entry records the sidecar directory and a SHA-256 digest and that `mise lock --sidecars` lists them, matches the mise docs ("Native dependency sidecars", "Listing sidecars"). `.mise/locks/` is not git-ignored, so the sidecars can be committed.
4. **`sky_engine` given a wrong licence (Moderate): resolved.** The classification requirement limits BSD-3-Clause to `flutter` and `flutter_test`. `sky_engine` is accepted as an SDK package with `LicenseRef-flutter-engine-bundle`, and the scenario "Engine bundle" covers this. The SBOM requirement allows "licence identifier or licence reference", and its "Generate" scenario asserts the `sky_engine` component's LicenseRef. D13 names the reference and the LICENSE it points to. C5 still lists the engine's bundled components as a gap.
5. **Allowlist could accept incompatible licences (Suggestion): addressed.** D5 has templates carry an AGPL-compatibility flag and rejects incompatible `allowed:` ids. The spec adds the scenario "Incompatible allowlist entry". The fix brings a small naming inconsistency, recorded as new suggestion 8.
6. **Superseded-run THEN (Suggestion): addressed.** The first run now ends `cancelled`, and the second run reports the pull request's result. Both can be asserted.
7. **`signoff` runner OS (Suggestion): addressed.** D6 names `ubuntu-24.04`.

### Critical (blocking)

None.

### Moderate

None open.

### Suggestions

8. **SPDX id spelling for the copyleft templates.** D4 lists the disallowed templates as `GPL-2.0`, `LGPL-2.1`, `LGPL-3.0`, `GPL-3.0`, `AGPL-3.0`. These are deprecated SPDX short forms. The new spec scenario "Incompatible allowlist entry" uses `GPL-2.0-only`. If the templates are keyed by the D4 spelling, `allowed: [GPL-2.0-only]` takes the "Unknown allowlist entry" path, so a test written from that scenario never reaches the incompatibility branch. Pick one spelling (the current SPDX `-only` and `-or-later` forms), and note that a text match alone cannot tell `-only` from `-or-later`. C8's summary ("unknown keys and unknown allowlist ids") could also mention incompatible ids, though its destination requirement already does. Not blocking.

Claims check (re-check scope): the new citations `THIRD_PARTY_NOTICES:171`, `:406` and the re-used `:539` support their claims. D8's new mise-docs claim is supported by the cited documentation section.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **S6/D6, C9 and continuous-integration spec (finding 1).**
   - In D6, add an input for the pull request opener (for example `--pr-author <login>`). CI passes `${{ github.event.pull_request.user.login }}` to it. Skip a commit only when the opener is `dependabot[bot]` and the commit's author is the exact Dependabot identity. Otherwise check the commit normally.
   - Reword C9 and the requirement "CI checks DCO sign-off on pull requests" to say so.
   - Add the scenario "Bot identity outside a Dependabot pull request": WHEN a commit in a pull request that a person opened has the Dependabot author identity, THEN the sign-off job checks it like any other commit and fails it when it has no matching `Signed-off-by`.
   - S6 is `Chosen by: user`, so put this to the owner first.
   - **Applied.**
2. **D4 step 2 and the dependency-licences spec (finding 2).**
   - Replace step 2 with: drop the leading header block only, meaning an optional title line, then consecutive copyright lines (`Copyright`, `(c)` or `©` after any indentation, case ignored), then an optional `All rights reserved.` line. Never drop lines after the first body line.
   - Add the scenario "Separate rights line": WHEN a BSD-3-Clause text has `All rights reserved.` on its own line after the copyright line, THEN it classifies as `BSD-3-Clause`.
   - D4 is `Chosen by: user`, so put this to the owner first.
   - **Applied.**
3. **D8, C2, Impact and State & Ownership (finding 3).**
   - Name the committed npm sidecar directory (the one `mise lock --sidecars` lists, by default under `.mise/locks/`) next to `mise.lock`.
   - Extend the "Lockfile out of date" scenario: a missing locked dependency graph for an npm tool also makes the setup step fail.
   - **Applied** (as the separate scenario "npm dependency graph missing", which is equivalent).
4. **Dependency-licences requirement "Locked packages are classified by licence", and D13 (finding 4).** Limit "take the SDK's licence, BSD-3-Clause" to `flutter` and `flutter_test`, or to SDK packages other than `sky_engine`. State that `sky_engine` is recorded with no SPDX identifier (or a `LicenseRef-` that names its LICENSE) and is covered by C5. Add a scenario asserting this for the SBOM.
   - **Applied** (the `LicenseRef-flutter-engine-bundle` option).

CHANGES_APPLIED: yes

## Rebuttals

- **Finding 1:** fixed. See design.md D6 (`--pr-author`, skipped only when the opener is `dependabot[bot]`), C9, the decision summary row S6/D6, proposal.md S6 and What Changes, specs/continuous-integration/spec.md "CI checks DCO sign-off on pull requests" and the scenario "Bot identity outside a Dependabot pull request", and specs/contribution-policy/spec.md. Accepted by reviewer.
- **Finding 2:** fixed. See design.md D4 step 2 (header block only, citing `THIRD_PARTY_NOTICES:171`, `:406`), the D4 summary row, and specs/dependency-licences/spec.md scenario "Separate rights line". Accepted by reviewer.
- **Finding 3:** fixed. See design.md D8, C2 and the State & Ownership row, proposal.md Impact, and specs/continuous-integration/spec.md requirement text and scenario "npm dependency graph missing". Accepted by reviewer.
- **Finding 4:** fixed. See specs/dependency-licences/spec.md classification requirement, scenario "Engine bundle", the SBOM requirement and the "Generate" scenario, and design.md D13. Accepted by reviewer.
- **Suggestions 5-7:** addressed. See design.md D5 and the spec scenario "Incompatible allowlist entry"; the continuous-integration scenario "Superseded run"; and design.md D6 (`ubuntu-24.04`). Suggestion 5's fix leads to new suggestion 8, which is not blocking.
