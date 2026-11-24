# Review

## Metadata

- **Round:** 8 (limited recheck of the one remaining Round-7 Required Change)
- **Prior round:** Round 7 returned APPROVE_WITH_CHANGES with one Required Change and `CHANGES_APPLIED: no`.
- **Reviewer:** fresh-context subagent (Claude Agent SDK, read-only)
- **Reviewed:**
  - `openspec/changes/esi-call-log/review.md` (Round 7 Required Change 1)
  - `openspec/changes/esi-call-log/tasks.md` (task 2.1)
- **Scope:** this round checks only whether the Round-7 Required Change was applied. It does not review anything else.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

None.

**Required Changes verified in this round:**
- **Required Change 1 (applied).** Task 2.1 (`tasks.md:33`) now contains the required text word for word: "reporting any production reference to the call-log model class or its table class, and any string literal naming the call-log table, outside the call-log store and scoped reader files and `src/generated/`, with positive and negative source samples as `tools/kaname_tools/test/esi_boundary_test.dart:10-26` does." This fixes the three Round-7 gaps:
  - The exemption set is now defined by the call-log store and scoped reader files, which `design.md` names.
  - The "production" scope is back, so test sources such as `esi_call_log_test.dart` fall outside the guard.
  - The `esi_boundary_test.dart:10-26` citation is back.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **Moderate 1 (Round-6 Required Change 4, carried through Round 7).** In task 2.1 (`tasks.md:33`), replace "detecting references to the model and table classes or a table-name string literal outside the repository and generated code" with:
   > "reporting any production reference to the call-log model class or its table class, and any string literal naming the call-log table, outside the call-log store and scoped reader files and `src/generated/`, with positive and negative source samples as `tools/kaname_tools/test/esi_boundary_test.dart:10-26` does."

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals