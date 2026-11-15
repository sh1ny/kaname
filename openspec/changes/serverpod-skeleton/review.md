# Review

## Metadata

- **Round:** 3
- **Prior round:** Round 2 returned APPROVE_WITH_CHANGES. Its re-check confirmed all eight Required Changes (R2-1 to R2-6) and set `CHANGES_APPLIED: yes`, with Suggestions S-6 and S-7 left open (S-2 to S-5 unchanged from round 2). Round 3 (amendment re-check of commit ae49053) returned APPROVE_WITH_CHANGES with Required Changes R3-1 and R3-2 and `CHANGES_APPLIED: no`.
- **Run:** Required Changes re-check of round 3. Only commit dfac727 is in scope, which is the author's application of R3-1 and R3-2. The check covers whether R3-1 and R3-2 are applied and whether the edits introduce a contradiction. This is not a full re-review. The owner chose option (b) for R3-1 (amend ADR 0002 in place) and judged that SSPL v1 counts as AGPL-compatible for this project. This run checks that the judgement is recorded accurately and consistently. It does not assess whether the judgement is right. The owner wrote the ADR text in this session, so the `[user]` approval task R3-1 proposed is not required. Because the owner counts SSPL as compatible, CONTRIBUTING.md:12 needs no wording change unless a concrete contradiction is found, and none was.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** `git show dfac727` (docs/adr/0002, design.md, proposal.md, review.md hunks); openspec/changes/serverpod-skeleton/{proposal.md, design.md:31, 143-150, 175, 192-201, 308, review.md (round 3), tasks.md:66-68}; a grep of the change's specs for SSPL and ADR 0002; docs/adr/0002-licence-clean-room-and-eula-boundary.md (full); CONTRIBUTING.md:1-20; licence-policy.yaml (working tree, plus its uncommitted diff against HEAD); openspec/specs/dependency-licences/spec.md:4, 47-48, 59-86, 96-97; openspec/schemas/specwright/schema.yaml (review instruction) and templates/review.md. Project skills loaded: serverpod-overview and dart-run-static-analysis (both loaded). No referenced stores.

## Findings

### Required Changes re-check

| Item | Status | Evidence |
|---|---|---|
| R3-1, ADR amended in place (option b) | Applied | The last Decision bullet of ADR 0002 now records the owner's judgement: SSPL v1 is "the AGPL-3.0 plus a service clause", its extra obligation "applies only to offering the SSPL-licensed program itself as a hosted service", and "Kaname publishes its full source anyway". It accepts `serverpod` as an unmodified runtime dependency "through an exception pinned to its exact version in `licence-policy.yaml`" and says each Serverpod version change returns to the owner. It ends with the dated note "(Amended 2026-11-15, change `serverpod-skeleton`.)". The CI-fails rule is kept unchanged, so the bullet stays consistent with itself. |
| R3-1, D13 Choice and Rejected | Applied | design.md:146 names the in-place amendment and gives the same reading of the service clause, worded as "offering Serverpod itself as a hosted service". design.md:147 adds "leaving ADR 0002 unamended" to Rejected, with the reason R3-1 asked for. |
| R3-1, D13 summary row | Applied | design.md:175 adds "ADR 0002 amended" to the Choice column and "ADR 0002 unamended" to the Rejected column. Reversal cost, importance and chooser are unchanged and match the entry. |
| R3-1, design Context | Applied | design.md:31 now reads "0002 (AGPL, clean room; its CI licence bullet amended for `serverpod`, D13)". This is the option (b) wording. |
| R3-1, proposal Impact | Applied | proposal.md:42 adds `licence-policy.yaml` and the ADR file to "Changed:". proposal.md:44 references the amendment and states the owner's reading. CONTRIBUTING.md is correctly absent, because under the owner's judgement it needs no edit. openspec/architecture.md is correctly absent, because option (b) adds no ADR row. |
| R3-1, tasks | Not required (owner) | The owner wrote the ADR text directly, so neither the `[user]` approval task nor the ADR-writing task is needed. The ADR edit is already committed in dfac727. The licence-policy.yaml entries stay under tasks 1.6 and 1.7 (tasks.md:67-68), which already cover writing approved exceptions and getting `mise run licences` to pass. No task is now missing. |
| R3-1, CONTRIBUTING.md:12 | No change needed; consistent | "subject to its licence being compatible with the AGPL-3.0" matches the amended ADR, which counts SSPL v1 as compatible. CONTRIBUTING.md:9 links ADR 0002, so a contributor reaches the amended reading from there. |
| R3-1, dependency-licences spec | No change needed; consistent | Purpose (spec:4) and "Only AGPL-compatible licences pass" (spec:47-48) agree with the owner's reading. `serverpod` passes through an exception, the spec's only route for a package the check would fail (spec:59), and not through the allowlist. So the rule that an allowlist entry must be one the check recognises (spec:86) is not touched. |
| R3-1, licence-policy.yaml | Consistent | The `serverpod` entry (4.1.2, `unrecognised`, "Server Side Public License v1 (SSPL) ... accepted by the owner (design D13)", 2026-11-15) matches D13, the ADR's "exception pinned to its exact version" and the header rule "Only the owner approves exceptions". The postgres entry matches D13. |
| R3-2, C10 | Applied | design.md:201 adds C10 with the required content: `serverpod` is the only runtime dependency accepted under SSPL v1, and any Serverpod version change or other non-allowlisted licence goes back to the owner (D13). It has Kind "deliberate gap" and exactly one destination, ADR 0002 (CI licence bullet, amended 2026-11-15). That destination holds the version-change part verbatim. The "any other licence" part is enforced by licence-policy.yaml:9 and spec:59. |
| Scope of edits | Confined | dfac727 changes only the lines that R3-1 and R3-2 name: design.md:31, 146-147, 175 and 201, proposal.md:42 and 44, the one ADR bullet, and review.md. No other part of the proposal, design or specs changed, so the verdict is not voided. |

### Contradiction check

No contradiction was introduced. The ADR, D13 and its row, design Context, C10, the proposal and licence-policy.yaml all describe the service clause the same way. They all pin the exception to the exact version and all send each Serverpod version change back to the owner. The amended bullet does not conflict with ADR 0002's "Non-commercial: no ... hosted service" bullet: that bullet limits what Kaname itself offers, and the SSPL reading concerns offering Serverpod as a service. C10 says `serverpod` is the only SSPL dependency, while the ADR treats SSPL as compatible in general. These do not conflict: the check cannot recognise SSPL, so another SSPL package would still need its own exception, and only the owner can approve one (licence-policy.yaml:9, spec:59).

### Critical (blocking)

None open. C-1 is resolved by R3-1.

### Moderate

None open. M-1 is resolved by R3-2.

### Suggestions

- **S-11 (policy reason cites a change-local decision).** The `serverpod` exception's reason in licence-policy.yaml cites "design D13". Once the change is archived, that design lives only under the archive. The in-force record is ADR 0002. When the entry is next written (task 1.7), consider citing "ADR 0002; design D13" so that a reader of the policy file reaches the durable record. This does not block.
- **S-8 (carried forward unchanged from round 3).** The SBOM records no licence for a package excepted as `unrecognised`. Teaching the check `SSPL-1.0` would let the exception, and therefore the SBOM, carry it. This is a tooling scope change and an owner decision.
- **S-9 (carried forward unchanged from round 3).** A7 (design.md:185) should be marked checked once task 1.1 is committed.
- **S-10 (carried forward unchanged from round 3).** The THEN at specs/server-runtime/spec.md:14 cannot be asserted literally. Reword it when the spec is next edited.
- **S-6 (carried forward unchanged from round 2).** The WHEN of the scenario "An analysis info" should say "hand-written code".
- **S-7 (carried forward unchanged from round 2).** C9 is still listed before C8 (design.md:199-200).

Round 2 Suggestions S-2 to S-5 remain as they were.

## Verdict

Commit dfac727 applies R3-1 under the owner's option (b) and applies R3-2. The owner's judgement that SSPL v1 is AGPL-compatible is recorded accurately and in the same terms in ADR 0002, D13 and its summary row, design Context, C10, proposal Impact and licence-policy.yaml. Under that judgement, CONTRIBUTING.md:12 and the dependency-licences spec stay consistent without edits. The edits are confined to the Required Changes and introduce no contradiction. Only non-blocking Suggestions remain.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R3-1 (C-1).** Applied under the owner's option (b) (dfac727: ADR 0002 last Decision bullet, design.md:31, 146-147, 175, proposal.md:42, 44). The owner waived the `[user]` ADR approval task, the ADR-writing task and the CONTRIBUTING.md:12 amendment, as recorded in Metadata.
2. **R3-2 (M-1).** Applied (design.md:201, C10, destination ADR 0002).

CHANGES_APPLIED: yes

## Rebuttals

- C-1: fixed in dfac727 (ADR 0002 amended in place, option (b), owner decision). Accepted by reviewer.
- M-1: fixed in dfac727 (C10 added). Accepted by reviewer.
