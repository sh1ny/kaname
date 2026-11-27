# Review

## Metadata

- **Round:** 9
- **Prior round:** Round 8 approved the shortened ESI SSO admission requirement and confirmed the two round 7 edits.
- **Reviewer:** Codex
- **Reviewed:** Proposal, design, round 8 review, tasks, all three delta specs, M3 roadmap, architecture, ADRs 0003, 0005, 0006, 0007, 0010, 0017, 0018 and 0019, applicable main-spec requirements, the Riverpod guide, the listed project skill guidance, and the admission, append, exclusion, release and prune paths.
- **Checks:** Verified tracking and checked every path component for symlinks in the working tree and at `e177950` before opening the 57 cited ranges across 18 files. Inspected the current source and regression fixtures separately. No files were written, no network, agents or secrets were used, and no builds, tests or OpenSpec validation were run.
- **Recheck:** Read the round 9 review, task map, call-log specification delta and named regression. The recheck used file reads only.

## Findings

### Critical (blocking)

None.

### Moderate

- **The amendment’s regression is missing from the task map.** The call-log delta adds the stamped-receipt scenario, the design describes its expected outcomes, and the working tree contains a matching integration test. The task map still lists only the existing cutoff and clock-step cases. Those cases do not require a `true` stamp on a receipt inside the older window after an exclusion at or after cutoff. Record the new scenario and its test so the amendment has a tracked verification result. [Test map](openspec/changes/member-accounts/tasks.md#test-map) · [Regression fixture](server/kaname_server/test/integration/esi_call_log_release_test.dart#L267)
- **The cutoff rule is consistent across D13, D14 and C16.** Set the cutoff to the window end plus one minute. If the first exclusion commits at or after that cutoff before the window seals, a backward database-clock step can allow a new receipt dated inside the window to pass the existing append deadline. Its admission stamp is `true` because the exclusion row exists. At first release, the immutable `excludedAt` fails the strict `< cutoff` predicate, so that exclusion leaves the account eligible. A later window that still contains the receipt and has a cutoff strictly after `excludedAt` applies the exclusion. D9 independently checks recorded character overlap across routes. M2 attribution stays intact, and qualifying private totals still count all attributed calls. The proposed fixture isolates the rule with five distinct account and character pairs. It checks the stored stamp, publication with five contributors, and suppression at the next cutoff while all five receipts are still in range. The separate exact-cutoff scenario covers equality. [D13–D16](openspec/changes/member-accounts/design.md#d13-exclude-accounts-a-detached-character-starts-or-joins) · [Call-log delta](openspec/changes/member-accounts/specs/esi-call-log/spec.md#requirement-known-membership-splits-do-not-qualify-as-independent-accounts)
- **Ownership and commit ordering support the rule without another receipt or a live account row.** Admission reads the account, signer and exclusion flag in one snapshot. The scheduler carries those values through append. First sign-in and link persist any first exclusion with the membership change under the shared release lock. The exclusive seal waits for those writers to settle or returns unavailable at its deadline. A committed pre-cutoff exclusion applies to earlier receipts even if there is no new append. A rollback leaves no exclusion to apply. Retirement preserves the keyed evidence and the original receipt ID, so a cold recomputation reaches the same eligibility decision. [Admission snapshot](server/kaname_server/lib/src/esi/sso_sessions.dart#L180) · [Link](server/kaname_server/lib/src/esi/member_accounts.dart#L101) · [Exclusion writer](server/kaname_server/lib/src/esi/esi_call_log_store.dart#L243)
- **The seal closes both inputs and fences publication.** Once the seal commits, append refuses receipts before the sealed end and first-exclusion writes record a time at least as late as the sealed cutoff. A restart can recover a seal whose acknowledgement was lost. Readers compute against a matching snapshot, then recheck the durable end at response admission, including for cache hits and callers sharing a calculation. Prune commits the replacement seal with any deletions that would touch the latest sealed inputs. The existing implementation also establishes a seal on the first nonempty prune when no seal exists. The plan covers commit, rollback, deadline refusal, lost acknowledgement and supersession through controlled clocks and ordered barriers. The current aggregate query still reads the stamp as an independent disqualifier. That is the implementation difference the amendment’s regression targets. [Release store](server/kaname_server/lib/src/esi/esi_call_log_store.dart#L374) · [Response admission](server/kaname_server/lib/src/esi/esi_call_log_endpoint.dart#L105) · [Seal scenarios](openspec/changes/member-accounts/specs/esi-call-log/spec.md#requirement-released-aggregate-windows-cannot-go-backward)
- **The mechanism and bounds fit the amendment.** One immutable keyed row per ever-excluded account supports pre-cutoff joins without new receipts and survives retirement. Storage grows with account churn, while release checks accounts observed in the bounded window. One durable seal and the existing lock, statement, admission and cache limits bound release work. A stamp-only rule misses pre-cutoff joins with no new receipt. A membership graph adds retained history. A memory-only seal loses closure on restart, and an external clock would change the approved pre-seal contract. The amendment needs no new generated model, RPC or Flutter state. The existing typed server contracts, Riverpod ownership and Ember Settings scope still fit. [Resource bounds and mechanism ledger](openspec/changes/member-accounts/design.md#resource-bounds-full)

### Suggestions

- In the new regression, assert the selected end on the second read as well as the empty result. That makes the later-cutoff check explicit. [Regression fixture](server/kaname_server/test/integration/esi_call_log_release_test.dart#L267)

### Outside the approved threat model

- Direct database edits, a compromised Postgres or host, repeated or malicious clock manipulation, and control of CCP SSO remain outside scope. One ordinary backward database-clock step is in scope and is covered by the cutoff scenario. [Threat model](openspec/changes/member-accounts/design.md#threat-model)

## Verdict

VERDICT: APPROVE_WITH_CHANGES

The design implements item 96’s precedence rule and preserves the existing overlap, attribution and seal constraints. The required task-map change is complete.

## Required Changes

1. In the `tasks.md` test map, add a row under “Known membership splits do not qualify as independent accounts” for “A stamped receipt lands in an older window after a clock step.” Map it to `a post-cutoff stamp cannot disqualify an older window` in `server/kaname_server/test/integration/esi_call_log_release_test.dart`. Record both expected outcomes: the stamped receipt’s account qualifies in the first release, and the next applicable cutoff excludes it from qualification. Mark verification pending until the test passes.

CHANGES_APPLIED: yes

### Applied

The task map names the scenario and the exact regression under the required heading. It records that the stamped receipt’s account qualifies at first release and is excluded from qualification at the next applicable cutoff, matching the call-log delta. The row is `red` because the previous real run returned no rows on the first release. Passing verification remains pending until the production change that follows this review. [Task map](openspec/changes/member-accounts/tasks.md#L84) · [Call-log delta](openspec/changes/member-accounts/specs/esi-call-log/spec.md#L119)

The regression checks that the first read selects `day` and returns the route with five calls. The second read asserts that its actual selected window end, `next.window`, equals `day.add(const Duration(days: 1))`, then checks that `next.rows` is empty. [Regression assertions](server/kaname_server/test/integration/esi_call_log_release_test.dart#L310)

## Rebuttals

- **A pre-seal clock crossing and a committed exclusion are different observations.** Item 96 permits a later write to use the current database time when no seal recorded the crossing. An exclusion already committed at or after cutoff retains that timestamp across the clock step. A first exclusion recorded only after the step can have an earlier timestamp and apply at first release. These are separate test cases. [D14–D16](openspec/changes/member-accounts/design.md#d14-include-exclusions-effective-before-the-fixed-release-cutoff)
- **Existing constraints still apply.** C13 preserves D9’s overlap check and receipt attribution. C19 preserves the admission snapshot. C20 and C22 preserve sealed inputs and response admission. ADRs 0005, 0017, 0018 and 0019 keep holder, grant and admin authority tied to the signing character. The amendment leaves the later M3 transfer, affiliation, member-state and capability decisions in their own changes. [Carried constraints](openspec/changes/member-accounts/design.md#carried-constraints) · [M3 roadmap](openspec/roadmap.md#now-m3---identity-and-access)