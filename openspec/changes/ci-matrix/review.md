# Review

## Metadata

- **Round:** 4
- **Prior round:** 3: APPROVE_WITH_CHANGES (D8 provenance pin, A6 for aube's tarball verification; both applied and re-checked, changes marked applied). A D4 amendment made during apply of task group 2 voided that verdict. It covers the appendix copyright-line slot, exact canonical variants per id, the D4 Chosen-by note and summary row, A4's checked part, and the task 2.3 wording.
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:**
  - First pass:
    - The uncommitted amendment (`git diff -- openspec/changes/ci-matrix/design.md openspec/changes/ci-matrix/tasks.md`).
    - openspec/changes/ci-matrix/design.md (in full, focusing on D4, A4, the Carried constraints and the decision summary).
    - review.md (round 3), tasks.md (test map and groups 1 and 2) and specs/dependency-licences/spec.md (in full).
    - The ADR list under docs/adr/. ADR 0002's Decision bullet "CI fails on dependencies whose licences are not AGPL-compatible" (`docs/adr/0002-licence-clean-room-and-eula-boundary.md:16`) is the one the amendment bears on.
    - The tracked `THIRD_PARTY_NOTICES`. Searched for "OWNER OR CONTRIBUTORS" (18 lines), "HOLDER OR CONTRIBUTORS" (0 lines), "APPENDIX" (lines 484 and 908) and "Neither the name" (18 lines, all BSD-3-Clause clause 3). Also read sections L1 (161-189), the Apache appendices (470-505, 895-932), L16 (933-981) and the package index lines 125 and 128.
  - Re-check pass (this file): the round 4 Required Changes 1 to 3 only, through the updated uncommitted diff of design.md and tasks.md:
    - the Context bullet "Licence text variants", D4, A4 and the new C10 in design.md;
    - tasks 2.2 and 2.3 and the three renamed test-map rows in tasks.md;
    - `THIRD_PARTY_NOTICES:915-922`, to check the corrected line number.
  - Not opened: the untracked implementation (`licence_matcher.dart`, `licence_texts.dart`, `licence-policy.yaml` and the new tests). The local pub cache was not opened either. The two package claims (`material_color_utilities` 0.13.0 and `node_preamble` 2.0.2) are confirmed against the tracked `THIRD_PARTY_NOTICES`, not against the pub cache. That their real LICENSE files failed the first run is recorded, not checked.
  - Not verifiable from the artifacts: the owner's choice recorded in D4's Chosen-by note, and A4's statement that the owner approved the `node_preamble` exception on 2026-11-15. Task 2.7 is a `[user]` task and is still unticked, so the owner's own tick remains the record.
  - Skills: `dart-add-unit-test` (`.claude/skills/dart-add-unit-test/SKILL.md`), loaded and used for the test-map judgement. Referenced stores: none configured.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

Rounds 1 to 3: all Critical and Moderate findings stay resolved, and the amendment touches none of them:
- D4 keeps the header-block rule (round 2 finding 2) and the fixed order of operations.
- D8, A2, A6 and tasks 1.4 and 1.5 are unchanged.

Of the earlier suggestions:
- Round 2 suggestion 8 (current SPDX ids) is carried by task 2.3. D4's own list still says `GPL-2.0, GPL-3.0` (design.md:58). That is harmless, because task 2.3 governs the implementation.
- Round 3 suggestions 3 to 7 are unchanged and not blocking.

### Attempts to break the amendment

The attempts the request asked for, and what they showed:
- **Overlap between variants.** No text can match two templates. The HOLDER and OWNER variants of one id differ in a fixed word, so no text matches both. BSD-2-Clause and BSD-3-Clause differ by the whole of clause 3, and the holder slot sits inside that clause. A full-sequence match therefore separates them. The appendix slot exists only in Apache-2.0, and no other template shares its fixed text.
- **The appendix slot.** It cannot let a different licence or a changed clause pass:
  - The slot sits after "END OF TERMS AND CONDITIONS", outside the licence terms.
  - It is fenced on both sides by fixed words ("…within third-party archives" and "Licensed under the Apache License, Version 2.0 …").
  - The match must reach the end of the word sequence. So a bundled second licence after the appendix still makes the text unrecognised, as the `node_preamble` case shows (`THIRD_PARTY_NOTICES:933-981`, MIT, then `===`, then BSD-3-Clause).

  One limit remains (Suggestion 4).
- **"Changed clause".** The scenario still holds, because no slot or variant reaches into a terms clause except two parts reviewed earlier: the holder slot (round 1) and the single OWNER word, which is matched exactly. Finding 2's negative tests now pin that guarantee, and C10 protects it from later changes.

### Critical (blocking)

None.

### Moderate

1. **Missing carried constraint: the tolerated differences are a closed list, and widening it bypasses C4. Resolved.**
   - The finding: a later change could add a variant or widen a slot in the template file to make a failing package pass. Such a change leaves no `licence-policy.yaml` entry and no approval date, and C4 and C8 do not cover it.
   - The fix: design.md adds **C10** with the wording proposed in round 4. It is of kind invariant and has one destination: the library doc comment of `tools/kaname_tools/lib/src/licence_texts.dart`.
   - Task 2.3 now carries it ("Carry C10 in the library doc comment of `licence_texts.dart`").
   - C10 sits between C8 and C9 in the list, which is only cosmetic.
2. **The new variants and the appendix slot have no complete red-first tests, and nothing checks that a variant is not a wildcard. Resolved.**
   - Task 2.2's fixtures now include:
     - BSD-3-Clause in both the HOLDER (SPDX) and the OWNER wording;
     - a BSD-2-Clause SPDX text;
     - the filled-in Apache appendix.
   - The changed-clause test gains both negatives: a third word in place of HOLDER/OWNER, and an appendix slot of more than 12 words.
   - The fixture sentence is gone from task 2.3.
   - The three test-map rows ("Holder named inside a clause", "Optional title or appendix" and "Changed clause") are renamed to cover these cases. Each row still maps to the matcher unit test, the cheapest complete layer.
   - **Deviation, accepted.** Round 4 cited `THIRD_PARTY_NOTICES:895-932` for the fixture. That range starts inside clause 9, so as a fixture it would be a truncated Apache text that no template matches, and the test would not prove the slot works. The author's whole-section citation, `THIRD_PARTY_NOTICES:730-932`, is correct: L15 starts at 730, and L16 starts at 933.
   - **Wording in task 2.2, acceptable.** The note "the cases added then fail first against the existing matcher where it lacks them" is consistent with a matcher that already exists in the work tree. Against a correct matcher, the two negative cases will pass on their first run. That is expected for negative tests and does not weaken them.
3. **The apply-time evidence cites the pub cache, an outside path, although tracked evidence exists. Resolved.**
   - D4 now cites `THIRD_PARTY_NOTICES:908-919` for the filled appendix and `THIRD_PARTY_NOTICES:182` for the OWNER wording ("18 occurrences and none with HOLDER").
   - A4 cites `THIRD_PARTY_NOTICES:933-981` for `node_preamble`.
   - The Context bullet "Licence text variants" now lists the filled appendix copyright line (`:919`), states that every BSD text uses the OWNER wording (`:182`), and notes that none uses the SPDX HOLDER wording.
   - Re-checked: `THIRD_PARTY_NOTICES:919` is `   Copyright 2021 Google LLC`. Round 4's `:920` was my miscount, and the author's `:919` is correct. Lines 908-919 run from the APPENDIX heading to that line, and `:182` holds "OWNER OR CONTRIBUTORS BE LIABLE".
   - A4 still says "not every text was walked one by one" next to its checked part. That was optional in round 4, and both statements remain true.

### Suggestions

4. **The appendix slot is a 12-word window, not "that one line". Open, for the owner.** Step 3 turns the text into a word sequence, so line boundaries are gone. "The boilerplate line … is itself a slot" therefore means any 1 to 12 words between the fixed words "archives" and "licensed". These words may span several lines and need not be a copyright statement. For example, a fill such as `Copyright 2021 Foo. Non-commercial use only.` (seven words) would classify as Apache-2.0 without a human look.
   - This is no worse than the holder slot accepted in round 1, which has the same window property. The text also sits outside the terms, so it is not blocking.
   - A cheap tightening reuses step 2's line-level recogniser. The slot must then consist of whole lines that each start with `Copyright`, `(c)` or `©`, matched before step 3, plus an optional `All rights reserved.` line.
   - It is a D4 change (`Chosen by: user`), so it goes to the owner. The author did not take it up, which is correct. C10 now makes any such change an owner decision.
5. **"Matches more than one" should say "more than one SPDX id". Open.** The variants of one id are disjoint today. An implementation that models each variant as its own template could, however, count two hits on the same id as ambiguous, if a future variant overlapped another through the optional tail.
6. **Spec wording (clarification). Open.** The "Changed clause" scenario reads "matches a known licence except for a changed word". A sentence such as "a known licence includes the variants the tool lists for its id" would stop a later reader from taking the OWNER variant for a defect. The requirement's "licence texts the tool knows" already covers it, so nothing contradicts it.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **Carried constraints (finding 1).** Add C10 as worded in finding 1, with the one destination given there: the library doc comment of the canonical-template file. Then add a task in group 2 (or a sentence in task 2.3) that carries it.
   - **Applied:** C10 is in design.md with a single doc-comment destination, `tools/kaname_tools/lib/src/licence_texts.dart`. Task 2.3 carries it. Re-checked and accepted.
2. **tasks.md, task 2.2, task 2.3 and the test map (finding 2).**
   - Task 2.2's fixtures gain BSD-3-Clause in both the HOLDER (SPDX) and the OWNER form, a BSD-2-Clause SPDX text, and the filled-in Apache appendix.
   - Its "changed clause word" test gains two negatives: a third word in place of HOLDER/OWNER, and an appendix slot of more than 12 words.
   - Remove the fixture sentence from task 2.3.
   - Update the test names of the three test-map rows to match.
   - **Applied:** all of these are done. The fixture citation is the whole L15 section, `THIRD_PARTY_NOTICES:730-932`, in place of the round 4 range `895-932`, which started mid-text. That deviation is accepted as the correct reading of the change's intent. Re-checked and accepted.
3. **design.md D4, A4 and Context (finding 3).**
   - Cite the filled appendix copyright line, `node_preamble`'s MIT and BSD file, and one of the 18 OWNER lines.
   - Add the filled appendix and the OWNER wording to the Context bullet "Licence text variants", and note that no BSD text uses the HOLDER wording.
   - **Applied:** the citations are `:908-919` and `:919`, `:933-981` and `:182`. The line number is corrected from round 4's `:920`. The Context bullet is updated. Re-checked and accepted.

None of these reverses a `Chosen by: user` decision. Suggestion 4 would change D4 and stays open for the owner.

CHANGES_APPLIED: yes

## Rebuttals

- **Finding 1:** fixed. See design.md C10 (Carried constraints) and tasks.md task 2.3 ("Carry C10 in the library doc comment of `licence_texts.dart`"). Accepted by reviewer.
- **Finding 2:** fixed. See:
  - tasks.md task 2.2 (HOLDER, OWNER and BSD-2-Clause fixtures, the filled-in L15 appendix at `THIRD_PARTY_NOTICES:730-932`, and the two negatives);
  - task 2.3 (the fixture sentence removed);
  - the test-map rows "Holder named inside a clause", "Optional title or appendix" and "Changed clause".

  The citation deviates from round 4 (`730-932` in place of `895-932`), because a fixture needs the whole licence text. Accepted by reviewer.
- **Finding 3:** fixed. See design.md Context "Licence text variants" (`:919`, `:182`), D4 (`:908-919`, `:182`) and A4 (`:933-981`). The author's `:919` corrects the reviewer's `:920`. Accepted by reviewer.
- **Suggestion 4:** not taken. It is a D4 change and is left open for the owner.
- **Suggestions 5 and 6:** not addressed. They are not blocking.
