# Review: esi-request-scheduler, design round 4 (scope confirmation and delegation recheck)

This round checks only the revisions made after round 3. Those are the owner's S1–S3 scope choices, the delegation of inner design, and the decision records in `proposal.md` and `design.md`. It also checks that the approved behavior did not change. I read `review.md`, `proposal.md`, `design.md`, both delta specs, `tasks.md`, the Specwright schema rules for decision mode, `openspec/specwright.yaml`, the roadmap and the archived generator proposal. I did not edit any files.

## Decision records

| Item | Status | Evidence |
|---|---|---|
| S1 corp in-flight coalescing | **Matches the owner's choice** | `proposal.md:37-43`, recorded `Chosen by: user`. It agrees with C3 and C9 (`design.md:55,62`) and with the spec requirement (`esi-request-scheduling/spec.md:104-115`). |
| S2 page-local scheduling, traversal moved to M5 | **Matches; the supersession is accurate** | `proposal.md:45-51`. The archived generator proposal did give "pagination loops" to this change (`archive/2026-11-24-esi-client-generator/proposal.md:25`). M5 "ingestion recipes" exists in `roadmap.md:34`. C5 (`design.md:58`) and the out-of-scope list (`proposal.md:14`) agree. |
| S3 server composition and native solo factory, no product consumer | **Matches** | `proposal.md:53-59`. The rejected public status endpoint is kept separate from the internal `/status` probe in D6. That fits "solo engine or store setup" being out of scope and C8 deferring durable solo state to M4. Task 3.2 builds factories only. |
| Mode and delegation | **Matches the schema** | `DECISION_MAKING: all` with `Source: setting` is right, because the mode comes from `openspec/specwright.yaml:2`. The owner's delegation of inner design is recorded as a handback note (`proposal.md:35`, `design.md:13`), so D1–D6 stay `Chosen by: agent`, as the schema requires (`schema.yaml:120-122`). S1–S3 stay `Chosen by: user`. Under `schema.yaml:778`, any scope drift during apply goes back to the owner, which matches "scope changes are not delegated". |
| Decision summary table | **Matches** | `design.md:35-45`. The S1–S3 and D1–D6 rows match the full entries. |

## Behavioral design unchanged

- Every line cited as evidence in round 3 still points to the same content. That covers `design.md` lines 20, 29, 33, 45, 61, 62, 108-109, 129, 136 and 155, `esi-request-scheduling/spec.md` lines 19-21, 100-102 and 106, and `esi-client/spec.md` lines 6, 30 and 32-34. So the post-round-3 edits are limited to the decision and provenance text.
- The specs still hold 21 scheduling scenarios and 7 client scenarios. `tasks.md` maps all 28 of them, and only the 5 client cases that were already green are marked green. Requirements, thresholds, bounds, reasons and failure behavior are unchanged.

## Non-blocking suggestions

These don't affect the verdict:
- **`design.md:24`** says "under the coordinator's handback". Given `proposal.md:35`, "under the owner's delegation of inner design" would name the right actor.
- **Roadmap:** when you archive, consider adding pagination traversal to the M5 line in `roadmap.md:34`. The move is currently recorded only in this change's S2.
- **Round-3 leftovers are still open and optional:** the state-table wording at `design.md:109` ("bounded eviction"), "HTTP status" versus "wire HTTP status" at `esi-client/spec.md:30`, and round-2 suggestions S1–S5.

## Verdict

The S1–S3 scope matches the owner's choices, and the delegation of inner design is recorded consistently with the Specwright mode rules. The behavioral design approved in round 3 is unchanged, so apply can go ahead under the owner's authorization.

VERDICT: APPROVE

CHANGES_APPLIED: n/a