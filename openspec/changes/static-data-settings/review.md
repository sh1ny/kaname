# Review

## Metadata

- **Round:** 42
- **Prior round:** Round 41 requested fixes to report transfer retention, the app deadline, migration atomicity, and API routing. The revised design addresses the latter three and drops producer-owned report bytes on expiry.
- **Reviewer:** Cross-model CLI (OMP)
- **Reviewed:** Proposal, FULL design, seven delta specs, five corresponding main specs, M1 roadmap, architecture, in-force ADRs, and cited repository source. No tasks or test map were present. Git index membership could not be verified with the available tools. Returned inline for the review runner.

## Findings

### Critical (blocking)

1. **D31 still releases a transfer place while the HTTP writer can retain the entire report allocation.** `design.md:462–463` drops the transfer's references to the encoded array and *unsent* views, but sends views backed by that same array. The cited bundle pump hands a `Uint8List.sublistView` to the stream (`bundle_route.dart:201–218`), and its contract explicitly distinguishes body completion from the HTTP writer's final buffering and flush (`bundle_route.dart:46–57`). A view already handed off can pin the whole array after the place is reused. With successive slow readers, eight places do not cap retained report allocations. The app deadline does not bind public callers, and Caddy's timeout is write-idle, not an absolute response deadline (`deploy/Caddyfile:7–16`). Define the bound through the writer handoff: confirm cancellation or release downstream ownership before recycling capacity, or account for downstream buffers under a separate hard bound. Extend the expiry scenario (`specs/static-data-admin/spec.md:256–258`) to stall **after** the writer has taken a chunk and verify that admitting replacements does not increase retained report allocations beyond the stated bound.

### Moderate

1. **A replay can report “update failed” or “rollback failed” for a job that already succeeded.** D19 explicitly allows two calls for X to miss their initial lookups, then lets the second attempt the insert after the first ends and releases the slot (`design.md:332–333`; `specs/static-data-admin/spec.md:371–377`). If the second insert finds the existing X but its acknowledgement is lost or misses the budget, D19 answers a final failure. The settler preserves X's existing success, so the RPC and operation read disagree. Not dispatching the second request proves nothing about the original job. When an ambiguous store can have conflicted with an existing id, return the authoritative row if available; otherwise return the existing nonfinal answer and keep following X. Add a lost-conflict-acknowledgement case for a successful rollback.

2. **D30's live reply cannot distinguish a lookup before noon from one after noon.** `design.md:447–449` adds a boolean reply mark but also requires catch-up to use the actual lookup timestamp for live and stored evidence. A pending check can begin its lookup on either side of 12:00 UTC, reply after noon, and have no stored record because its record write failed, which the build spec permits (`specs/static-data-builds/spec.md:330–331`). Both replies would carry `true`, but only the post-noon lookup satisfies today's cutoff. Carry the nullable lookup-start timestamp in the existing final reply as the mark; no progress message or extra watchdog is needed. Cover both sides of noon with no stored row.

### Suggestions

- Narrow D31's claim that Relic gives no earlier disconnect signal. The existing middleware subscribes to `request.cancelled` (`bundle_route.dart:147`); that does not establish when it fires during a database read. Keep the conservative 17-second reservation if desired without relying on the stronger claim.
- Keep the owner-approved restart recovery for rare internal stalls and the accepted C26 gap. Neither needs a new safeguard for this review.

## Verdict

VERDICT: USER_OVERRIDE

## Required Changes

CHANGES_APPLIED: yes

User decision: "yea go with your suggestion and wrap this up. Also write a reminder to not make too strict promises in the future, so we don't have to loop again." (2026-11-23). The suggestion it accepts: fix round 41's findings, simplify the start-up watchdogs to one 30-minute rule, run one more round, then stop looping and write tasks.md rather than loop until the reviewer finds nothing.

Applied after round 42, not re-reviewed by a further design round (the pre-ship review covers the implementation):
- Critical 1: report bodies stream 64 KB copies, never views of the encoded array; at the deadline the transfer drops the array, so an expired response keeps at most one copied chunk; new scenario "Reader stalls after the writer took a chunk" (D31).
- Moderate 1: a store of unknown outcome answers the nonfinal "no answer yet" or "outcome unknown" and the app follows X; the settler ends X only when not already ended; new scenario "Replay conflict answer lost after a successful rollback" (D4, D5, D19, failure table).
- Moderate 2: the check reply carries a nullable `lookupStartedAt`; new scenario "Pending check replies with no stored record" (D30, C36).
- Suggestion 1: D31 no longer claims Relic gives no earlier disconnect sign.

## Rebuttals

Return the remaining findings to the owner before another review round.