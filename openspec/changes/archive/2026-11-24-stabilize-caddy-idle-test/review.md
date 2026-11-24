# Review

## Metadata

- **Round:** 3
- **Prior round:** Approved with changes pending three required design edits.
- **Reviewer:** Cross-model CLI (Codex)
- **Reviewed:** Current design, round-2 `review.md`, and the FULL Specwright review template. The recheck covered the three required edits and the reset wording in the diagrams. No files were edited or tests run.

## Findings

### Critical (blocking)

None open.

### Moderate

None open. All three required edits pass the design recheck.

### Suggestions

The round-2 suggestion is resolved. The fixture-stage and close-order diagrams now allow TCP reset as an alternative to a truncated response followed by EOF, consistent with the flow text stating that reset can discard the buffered prefix.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **A2 effective timeout and configuration equivalence — applied and verified in design.** A2 requires separate adaptation of both scratch configurations with the pinned Caddy and the same stub port. The effective JSON must encode the primary listener’s explicit positive timeout and the control’s explicit negative disablement. Omission and zero are excluded. The configurations must match after normalizing that one field. Full delivery remains a separate check, and live verification of the primary trace is retained.
2. **Subprocess shutdown and cleanup — applied and verified in design.** Resource Bounds allocates 30 seconds per cleanup subprocess for CLI exit and both output pipes together, with the final five seconds reserved for forced termination and cancellation of pending reads. Failure & Visibility requires registering removal by container name before launch, attempting removal, and confirming absence before deleting the scratch configuration. If absence cannot be confirmed, CI output reports the container name, retained scratch location, and cleanup error.
3. **C3 disabled drain control — applied and verified in design.** C3 names the `caddy_idle_test.dart` library doc comment as its single destination. It requires verified timer disablement and an open upstream with unsent body data and a zero advertised receive window before client reads resume. Resumption must deliver the full body.

CHANGES_APPLIED: yes

## Rebuttals

- **Round 2 Moderate 1–3 — fixes accepted by reviewer.** The design now independently verifies effective disablement and configuration equivalence, bounds subprocess shutdown and verifies cleanup, and carries the drain-control acceptance rule into the test library documentation.
- **Round 1 Critical 1 and 2 and Moderate 1, 3, and 4 — resolutions retained.** The required edits did not reopen these findings. A2’s live checks remain apply-time verification.
- **Round 1 Moderate 2 — fully resolved in design.** The subprocess shutdown and cleanup requirements close the portion left open in round 2.