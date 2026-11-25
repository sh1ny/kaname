# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 (fresh-context subagent) returned APPROVE_WITH_CHANGES with no Critical findings, four Moderate findings and four Required Changes outstanding (`CHANGES_APPLIED: no`).
- **Reviewer:** cross-model CLI (Claude CLI, claude-opus-5-5), independent, read-only
- **Reviewed:** openspec/changes/restore-refused-take/review.md (round 1), proposal.md, design.md, specs/esi-sso/spec.md; app/lib/esi_sso/logic/account.dart, app/lib/esi_sso/data/device_store.dart, app/lib/esi_sso/data/desktop_platform_io.dart, app/lib/esi_sso/data/connected_account.dart; server/kaname_server/lib/src/esi/sso_handoff.dart; openspec/schemas/specwright/templates/review.md

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

None. This round re-checks only the four Required Changes from round 1. All four are applied, and their citations match the tracked source:

1. **Required Change 1 (server invariant C3): made.** `design.md` "Carried constraints" now has C3 after C2. It carries the required invariant, kind and destination (`server/kaname_server/lib/src/esi/sso_handoff.dart SsoHandoff.take`); the only difference from the required text is that one sentence is split in two.
   - I checked the invariant against the source. Every `blocked` return happens before the `toDevice` CAS writes this digest (`sso_handoff.dart:55-56,63,72-74,79-81,100`), or when the stored digest does not match (`sso_handoff.dart:68-70,98`).
   - After the CAS at `sso_handoff.dart:83-96`, the only returns are pending (`sso_handoff.dart:102-127`) or a reservation (`sso_handoff.dart:128`).
   - `_reservation` cannot return `blocked`, because it only builds a reservation (`sso_handoff.dart:226-229`).

2. **Required Change 2 (uncertain-take scenario WHEN): made.** The WHEN line in `specs/esi-sso/spec.md` "Scenario: An uncertain take keeps the original proof" matches the required text exactly. It now names the cases of a 403 without the fixed refusal body and a refused resumed take for an existing pending journal.

3. **Required Change 3 (keyring and store boundary): made.** D2 "Choice" now names three additions, with the required citations; the wording is the same except that one sentence is split in two:
   - `delete(String name)` on `DeviceSecrets` (`device_store.dart:12-18`, which today has only `read` and `write`).
   - Its OS keyring implementation (`desktop_platform_io.dart:41-51`) and the test keyring.
   - One `DeviceStore` method that restores or deletes the character row and the `selected-character` setting in a single transaction. Today the store has only the autocommit `setSetting` and `save` and no setting deletion (`device_store.dart:167-226`).

   In `proposal.md`, Impact now reads "the local character journal, the device keyring boundary and native handoff tests".

4. **Required Change 4 (connected-session guard precondition): made.**
   - **Context, third paragraph:** the replacement text states all three conditions. `account.dart:259-267` checks the same character, a present session, `holder != null` and no owned reservation. The paragraph also states the refresh-and-drop behaviour (`account.dart:276-281,309-311`), and the added citation `connected_account.dart:40-47` is correct: `refresh` returns `null` on any non-200 reply or a viewer that cannot be parsed. It keeps the clause that this matches the pre-take authority accepted by ADR 0017.
   - **Risks / Trade-offs:** now says the check applies only under the conditions in Context, that the local linked-row checks are unchanged, and that rollback adds no authority beyond the pre-take row. The wording differs slightly from the required text, but the meaning is the same.
   - **Spec Scenario 1:** the AND line matches the required text exactly.

### Suggestions

None new. Round 1 Suggestions 1–6 stay advisory. Two of them are partly reflected in the current design:
- **Suggestion 3:** Flow & State Gaps now cites `_one`, and says the restore runs outside `withCharacter`.
- **Suggestion 5:** D1 now says "no extra keys".

Following the owner's scope limit, the follow-up issues from round 1 Suggestion 2 should be filed separately rather than added to this change:
- a permanent `taking` row after rare interruptions,
- the post-refresh session drop.

## Verdict

All four round 1 Required Changes are present in proposal.md, design.md and specs/esi-sso/spec.md, and each one matches the tracked source it cites. No new Critical or Moderate findings were raised within this re-check's scope. The design stays limited to #39, and there is no manual acceptance gate.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

These are the round 1 Required Changes; all four have been applied and re-checked by this reviewer.

1. C3 server invariant added under "Carried constraints" in design.md: applied.
2. WHEN line of "Scenario: An uncertain take keeps the original proof" in specs/esi-sso/spec.md replaced: applied.
3. D2 "Choice" boundary additions in design.md, and the Impact wording in proposal.md: applied.
4. Guard precondition in the design.md Context, the Risks / Trade-offs sentence, and the AND line of spec Scenario 1: applied.

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals

None. The author rebutted no findings; every Moderate finding from round 1 was resolved by applying Required Changes 1–4.