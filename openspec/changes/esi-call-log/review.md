# Review

## Metadata

- **Round:** 10. This is a limited recheck of the single Round 9 Required Change (Moderate 1, the line citations).
- **Prior round:** Round 9 was a full review. It returned APPROVE_WITH_CHANGES with `CHANGES_APPLIED: no`.
- **Reviewer:** read-only. Nothing was written.
- **Reviewed:**
  - `openspec/changes/esi-call-log/review.md`
  - `openspec/changes/esi-call-log/design.md`, the `## Context` section (line 18) and the `## Flow & State Gaps (FULL)` section (line 139)
  - `packages/kaname_esi_scheduler/lib/src/scheduler.dart`, `server/kaname_server/lib/src/esi/server_esi_runtime.dart` and `packages/kaname_esi_scheduler/lib/native.dart`, all at the working tree
- **Limitation:** this session had no shell, so I couldn't diff `design.md` against HEAD. I checked that the six replacements are present and correct, but I couldn't prove that nothing else in `design.md` changed.

## Findings

### Critical (blocking)

None.

### Moderate

None. Round 9 Moderate 1 is fixed. All six replacements are in `design.md`, and each new range shows the code it is cited for:

| Section | New citation | What the source shows | Result |
|---|---|---|---|
| Context | `scheduler.dart:212-253` | The catalogue lookup of the operation (212-215), the owner (216) and the rate group (240-246). It ends where `SchedulerRequest` is built, just before admission starts at 254. | ✓ |
| Context | `scheduler.dart:254-316` | Admission refusals: state unavailable (263-266) and `Denied` (267-275). Bearer refusals (277-293). The sender failing with no head (299-312) and with a head (313-316). | ✓ |
| Context | `scheduler.dart:399-437` | In `_observe`: parsing the upstream `x-ratelimit-group`, checking cost (411-424), and applying the group and cost only when they are valid (433-437). | ✓ |
| Context | `server_esi_runtime.dart:61-81` | `RedisSchedulerState` is built (61-68), then composed with `NativeEsiRuntime.shared` (69-81). | ✓ |
| Flow & State Gaps | `scheduler.dart:327-349` | The settlement in `EsiResponse.withDecodeReceipt`: a poll's `_complete` waits for the decode receipt (339), and a non-poll settles at once (333). | ✓ |
| Flow & State Gaps | `scheduler.dart:267-273,477-491` | The outage probe calls `getStatus()` (267-273), and `_ProbeTransport` sends with `probe: true` and no principal (477-491). | ✓ |

### Suggestions

1. **The `native.dart` range doesn't match what Round 9 recorded.** `design.md:18` cites `native.dart:22-35`, but Round 9 recorded `native.dart:22-31`. The range 22-35 is correct: it covers the whole `NativeEsiRuntime.solo` factory, which composes with `MemorySchedulerState`. Either Round 9 misquoted the range or it was edited outside the Required Change. I couldn't diff, so I can't tell which. It doesn't block, because the citation is accurate either way. If it was edited, the owner should confirm that was intended.

Round 9 Suggestions 1–3 were outside this recheck and weren't re-evaluated.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **Moderate 1 (Round 9).** Change the line ranges in `design.md` (`## Context` and `## Flow & State Gaps (FULL)`). This is applied and verified against the cited source.

<!-- yes (applied, and re-checked by the reviewer - only the reviewer sets it) | no (outstanding) | n/a (any other verdict) -->
CHANGES_APPLIED: yes

## Rebuttals

None.

---

I verified the one Required Change from Round 9, so this round sets `CHANGES_APPLIED: yes`. As asked, I wrote nothing, so `review.md` still holds Round 9 until someone copies this round into it.