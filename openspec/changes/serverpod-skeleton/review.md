# Review

## Metadata

- **Round:** 3
- **Prior round:** Round 2 returned APPROVE_WITH_CHANGES. Its re-check confirmed all eight Required Changes (R2-1 to R2-6) and set `CHANGES_APPLIED: yes`, with Suggestions S-6 and S-7 left open (S-2 to S-5 unchanged from round 2).
- **Run:** amendment re-check after implementation drift during apply. Only commit ae49053 is in scope: the corrected CLI command form (proposal.md:25, design.md:24, A10 at design.md:188, tasks 1.4 and 7.2), the reworded test-map row "Server packages resolve with the workspace" (tasks.md:9), and the new D13 with its summary row (design.md:144-150, 175) and proposal Impact bullet (proposal.md:44). The check covers whether these amendments contradict specs, in-force ADRs or carried constraints. No full re-review was done.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** `git show ae49053`; openspec/changes/serverpod-skeleton/{proposal.md, design.md, tasks.md, review.md (round 2), specs/server-runtime/spec.md, specs/workspace-layout/spec.md}; a grep across all five delta specs; main specs openspec/specs/dependency-licences/spec.md, continuous-integration/spec.md:79-88 and third-party-notices/spec.md:14; docs/adr/0001 and 0002; CONTRIBUTING.md:12; openspec/strategy.md:15, 44-45; licence-policy.yaml (working tree and diff); pubspec.lock (serverpod*, postgres and kaname entries); pubspec.yaml diff; server/kaname_server/pubspec.yaml dev_dependencies; the tools/kaname_tools/test/workspace_test.dart diff; the installed package files ~/.pub-cache/hosted/pub.dev/serverpod_cli-4.1.2/{pubspec.yaml `executables:`, bin/}, serverpod-4.1.2/{LICENSE, README.md "License", pubspec.yaml}, postgres-3.6.0/LICENSE, serverpod_database-4.1.2/pubspec.yaml, and the LICENSE heads of every locked `serverpod_*` package; the output of `mise exec -- dart run kaname_tools licences --check` (check mode, writes nothing). The untracked evidence/scaffold.md was not opened: a grep matched it, and that is all. Project skills loaded: serverpod-overview, serverpod-configuration, dart-run-static-analysis (all three loaded). No referenced stores.

## Findings

### Amendment re-check

| Amendment | Status | Evidence |
|---|---|---|
| CLI command form (proposal.md:25, design.md:24, tasks 1.4 and 7.2) | Correct | `serverpod_cli-4.1.2/pubspec.yaml` declares `executables: serverpod: serverpod_cli`, and `bin/` holds only `serverpod_cli.dart`. `dart run <pkg>:<name>` runs `bin/<name>.dart`, so `serverpod_cli:serverpod` has no file to run, while `dart run serverpod_cli` runs `bin/serverpod_cli.dart`. The proposal, design Context, A10, 1.4 and 7.2 all use the same form. |
| No stale form left | Correct | A grep for `serverpod_cli:serverpod` finds it only in A10 (design.md:188, cited as the form that fails), in the round 2 review.md row 8 (a historical record that this review replaces) and in the untracked evidence/scaffold.md (not opened). The delta specs never name the command: server-runtime says only "the package-local Serverpod tool run through mise" (specs/server-runtime/spec.md:91) and "`mise exec -- dart run` from the server package" (:14), so the specs need no edit. |
| A10 rewording | Correct | It records what task 1.4 settled and leaves the bridge start to task 7.3. It cites the executable mapping accurately. |
| Test-map row (tasks.md:9) | Correct | The lockfile does mark `serverpod_cli` `dependency: transitive` (pubspec.lock:718-719), and the server pubspec holds `serverpod_cli: 4.1.2` under `dev_dependencies`. The row now asserts what the requirement says: a dev dependency of the server package, resolved through the root lockfile (specs/server-runtime/spec.md:10). |
| D13 facts | Correct as stated | serverpod-4.1.2/LICENSE is "Server Side Public License VERSION 1, OCTOBER 16, 2018", and its README "License" section says that every package except `serverpod` is BSD-3. Each locked `serverpod_*` LICENSE is BSD-3, and the check counts them under BSD-3-Clause. postgres-3.6.0/LICENSE keeps the placeholders `<contributors>`, `<organization>` and `<COPYRIGHT HOLDER>`. The two exceptions in licence-policy.yaml match the locked versions (pubspec.lock: `serverpod` "4.1.2", `postgres` "3.6.0"), and the check passes, listing both as excepted. |

### Critical (blocking)

- **C-1. D13 contradicts in-force ADR 0002, and neither D13 nor the proposal records it.** ADR 0002's Decision says "CI fails on dependencies whose licences are not AGPL-compatible" (docs/adr/0002-licence-clean-room-and-eula-boundary.md, Decision, last bullet). CONTRIBUTING.md:12 admits a dependency "subject to its licence being compatible with the AGPL-3.0". The dependency-licences Purpose is "Keeps every pub dependency of Kaname under a licence that is compatible with AGPL-3.0" (openspec/specs/dependency-licences/spec.md:4). D13 now makes the CI licence job pass for `serverpod` under SSPL v1. Nothing in the design, the ADRs or the policy file says SSPL v1 is AGPL-3.0-compatible. Its section 13 binds anyone who makes the program's functionality available to third parties as a service to release the "Service Source Code" of the whole stack under the SSPL. AGPL-3.0 section 10 forbids imposing further restrictions, and SSPL section 13 is not one of the additional terms AGPL section 7 permits. The SSPL entry already in THIRD_PARTY_NOTICES (third-party-notices spec:14; THIRD_PARTY_NOTICES:53) is for a vendored skills asset, which ADR 0002 carves out. A runtime dependency linked into the server is not covered by that carve-out.

  D13 lists only "stopping the change to revisit ADR 0001" as its rejected alternative (design.md:147). ADR 0001 is not the ADR it departs from. Design Context still lists 0002 as in force without qualification (design.md:31). The consequence: after merge, an in-force ADR, the contribution policy and a main spec's Purpose all say that every pub dependency is AGPL-compatible, and CI green-lights one that is not shown to be. A future contributor or reviewer who applies ADR 0002 will flag the exception, or will take it as precedent for a second non-compatible licence. Self-hosters ("install admins", strategy.md:9), who run the server for the members of their organisation, are never told that SSPL section 13 exists, or how the project reads "third parties as a service". The decision has high reversal cost (D13's own entry), so the departure needs to be recorded where ADR 0002 lives, not only in this change's design. This is the owner's decision (D13 is `Chosen by: user`, `DECISION_MAKING: all`). See Required Change 1.

### Moderate

- **M-1. D13 binds future changes but has no carried constraint.** D13 marks itself "Important: yes, binds future changes (every Serverpod upgrade re-checks the exception)" (design.md:149). The schema's rule sends "a decision that binds future changes beyond one module" to an ADR destination, as a `## Carried constraints` entry. The constraint has two parts. `serverpod` is the one runtime dependency accepted under a licence outside the AGPL-compatible allowlist (SSPL-1.0). Any Serverpod version change, and any other such licence, goes back to the owner. The version pin enforces the first part mechanically (dependency-licences "Version bumped past the exception"). The policy behind it is enforced nowhere a future planner reads during GROUND: licence-policy.yaml's header (licence-policy.yaml:1-12) still describes exceptions in general terms only. Carried constraints C1 to C9 (design.md:192-200) have no entry for it. See Required Change 2.

### Suggestions

- **S-8 (SBOM hides SSPL).** The SBOM records no licence for a package excepted as `unrecognised` (dependency-licences spec:105), so the published CycloneDX artifact will list `serverpod` 4.1.2 with no licence. The exception's reason and THIRD_PARTY_NOTICES do state SSPL. If the licence check learned the SSPL-1.0 text (a valid SPDX identifier), the exception could record `SSPL-1.0` instead of `unrecognised`, as the exceptions requirement allows (spec:59). The SBOM would then carry it. That is a tooling scope change and an owner decision, so it does not block.
- **S-9 (A7 now settled in the working tree).** pubspec.lock already resolves `serverpod_cli` 4.1.2 alongside the Flutter-pinned packages, and `licences --check` runs against it. A7 (design.md:185) still says "Not checked because the CLI is not added yet". The settling code is not committed yet (task 1.1 is unticked), so this is not counted as a Claims finding. When task 1.1 is committed, mark A7 checked, as A10 was.
- **S-10 (spec THEN not literally assertable).** Workspace members never appear as entries in pubspec.lock (a grep for `kaname` in pubspec.lock finds nothing). The THEN "`kaname_server` and `kaname_client` resolve into the root `pubspec.lock`" (specs/server-runtime/spec.md:14) therefore cannot be asserted as written. The reworded test-map row checks the workspace list instead, which is the right test. When the spec is next edited, reword the THEN to "are root workspace members, and the root `pubspec.lock` holds the Serverpod tool". This pre-dates ae49053.
- **S-6 (carried forward unchanged from round 2).** The scenario "An analysis info" still reads "any package contains code that produces an analysis info" (specs/workspace-layout/spec.md:12-14), which pulls against "Generated code". When the spec is next edited, make the WHEN say "hand-written code".
- **S-7 (carried forward unchanged from round 2).** C9 is still listed before C8 (design.md:199-200).

Round 2 Suggestions S-2 to S-5 are outside this re-check and remain as they were.

## Verdict

The command-form correction, the A10 rewording and the test-map row are accurate against the installed `serverpod_cli` 4.1.2 and the lockfile, and no stale form remains in the specs or the live artifacts. D13's facts are correct, and the licence check passes with exactly the two exceptions it describes. D13 does depart from in-force ADR 0002, CONTRIBUTING.md and the dependency-licences Purpose without recording it (C-1), and it lacks the carried constraint that its "binds future changes" mark requires (M-1). Both fixes are bounded edits plus one ADR, so the change can proceed once they are applied and re-checked.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R3-1 (C-1; owner decision first, because D13 is `Chosen by: user`).** Put the reconciliation with ADR 0002 to the owner, with these options:
   - (a) Recommended. Add a new ADR (next free number, `docs/adr/0012-serverpod-sspl-dependency.md`) that supersedes only ADR 0002's last Decision bullet. It records that `serverpod`, the server framework, is accepted under SSPL-1.0 as the one runtime dependency outside the AGPL-compatible allowlist, why the owner accepts it, the project's reading of SSPL section 13 for install admins (the Serverpod README's "as long as you don't offer Serverpod as a cloud service to third parties") and that every Serverpod version change returns to the owner. ADR 0002 gets a status note pointing to it, and openspec/architecture.md's ADR table gets the new row.
   - (b) Amend ADR 0002 in place, with the same content and a dated amendment note.
   - (c) Reject the exception and revisit ADR 0001.

   Then, for (a) or (b):
   - In D13, add "leaving ADR 0002 unamended" to **Rejected** with the reason (ADR 0002 would say CI fails on exactly this dependency), and name the ADR in **Choice**. Update the D13 summary row (design.md:175) to match.
   - In design Context, qualify ADR 0002 at design.md:31 with "(its CI licence bullet superseded by ADR 0012 for `serverpod`)", or with the (b) wording.
   - Add the ADR file, `CONTRIBUTING.md`, `openspec/architecture.md` (for (a)) and `licence-policy.yaml` to proposal.md's Impact "Changed:" line, and reference the ADR in the Licences bullet (proposal.md:44).
   - Add tasks in group 1, after 1.7: an agent task that writes the ADR and carries C10 (see R3-2), a `[user]` task in which the owner approves the ADR text, and an agent task that amends CONTRIBUTING.md:12 to say that a dependency outside AGPL-3.0 compatibility needs an owner-approved exception recorded in an ADR.

   If the owner picks (c), the change stops under the drift rule.
2. **R3-2 (M-1).** Add to `## Carried constraints`: "**C10:** `serverpod` is the only runtime dependency accepted under a licence outside the AGPL-compatible allowlist (SSPL-1.0). Any Serverpod version change, and any other such licence, goes back to the owner (D13). Kind: deliberate gap. Destination: ADR 0012" (or `ADR 0002` under option (b)). The ADR-writing task from R3-1 names C10.

CHANGES_APPLIED: no

## Rebuttals

None yet.
