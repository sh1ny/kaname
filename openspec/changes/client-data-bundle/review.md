# Review

## Metadata

- **Round:** 16
- **Prior round:** Round 15 (OMP) ended in REVISE with 1 Critical and 4 Moderate findings. The first Round 16 re-check accepted Required Changes 2–4 and found Required Change 1 partially applied.
- **Reviewer:** cross-model CLI (OMP)
- **Reviewed:** `openspec/changes/client-data-bundle/{proposal,design,tasks,review}.md` and the six spec deltas (`client-data-bundle`, `client-static-data`, `static-data-search`, `realtime-bus`, `server-workers`, `static-data-builds`), scoped to the four Required Changes. Context: `.claude/skills/serverpod-streams/SKILL.md`; ADRs 0003–0006 and 0008–0012; relevant sections of `openspec/architecture.md` and `openspec/roadmap.md`; cited ranges in `DESIGN.md`, `app/pubspec.yaml`, `app/lib/server/{data/server_address,logic/server_status}.dart`, `deploy/Caddyfile`, `mise.toml`, the ten cited `kaname_static_data` sources, `server/kaname_server/lib/server.dart`, the cited server static-data and worker sources and 13 typed models, and `tools/kaname_tools/lib/src/purity.dart`. No runtime probes run; this was a read-only design re-check.

## Findings

### Critical (blocking)

None.

### Moderate

1. **The retired-hash fix covers pending writes, not every live handoff.** D8 tells an idle writer to forward each higher-revision bus message, but tells a stalled writer to re-read the installed announcement. D7 exposes a Dart `Stream`; synchronous local Serverpod publication does not require the adapter's stream callback to run inline. If a notification for H reaches an idle writer after H2 is installed and publication of H2 fails, H can pass the revision check even though D4 now returns 404 for H. The stalled scenario at `realtime-bus/spec.md:88–90` also says “H2's announcement or nothing newer than it,” which does not clearly require delivery of H2 or allow a later installed H3.
2. **The startup probe can observe the right build without proving that the expired refresh was discarded.** `realtime-bus/spec.md:53–55` and task 7.2 distinguish the expired refresh from a fresh one, but if both return the same build, the named event after release is identical in either case. The scenario also says *each* first event is `none`, which includes a reconnect after the active announcement has been installed unless the interval is stated explicitly.
3. **The early A14 probe does not require proof that the WebSocket write actually blocked.** Task 2.1 says the generated client stops reading. Stopping consumption of its application stream can leave the WebSocket draining into client buffers. An endpoint closing in that state does not establish that it can free capacity while its transport write is blocked. Task 7.2 already requires an observably blocked write; the early go/no-go probe needs that same precondition.
4. **Three test-map entries can pass despite breaking their scenarios.** `tasks.md:32` omits `Retry-After`; `tasks.md:69` omits loading N+1 on a later restart; `tasks.md:103` omits continued delivery to admitted streams after rejecting stream 2,001. The existing assertions would not catch a missing retry hint, an unreadable kept copy, or admission handling that also breaks existing subscriptions.

### Suggestions

None.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. In D8 and `realtime-bus/spec.md`, use the bus notification as a wake-up for every live delivery: select the installed announcement at handoff, apply the scope and revision checks, and never forward the notification payload as a stale snapshot. Carry this invariant to C16's existing destination. Rewrite the stalled scenario to require H2 if still installed, or the later installed announcement if replaced, never H. Add an idle-writer case with delayed delivery of H's notification and failed publication of H2.
2. In the startup scenario, test-map row and task 7.2, require `none` as the first event only for subscriptions opened while the initial read is held; retain the 20-second bound for every subscription. Make the read results distinguishable or gate the queued refresh separately so the test proves that releasing the expired read does not publish and that the fresh read produces the active announcement.
3. In A14 and task 2.1, require the fixture to stop transport reads and observe a blocked server write before asserting pull behavior, slot release and replacement admission. Pausing only the application listener does not satisfy the probe.
4. Update the three test-map rows and their implementation tasks to assert `Retry-After` on the 503, load N+1 with a fresh notifier over the same store after `none` during its save, and deliver a later announcement to already admitted streams after refusing stream 2,001.

CHANGES_APPLIED: yes

## Rebuttals

1. **Accepted by reviewer.** D8 and C16 make bus messages wake-ups only at every handoff. “Announcements are ordered and bounded” now requires every send to carry the announcement installed at that moment, never an earlier copy. The stalled and idle cases, mapped in task 7.2, reject H even when H2's publication fails.
2. **Accepted by reviewer.** The startup scenario limits mandatory `none` to subscriptions opened during the hold and retains the 20-second bound for every subscription. The test-map row and task 7.2 distinguish expired build A, which must never be published, from fresh build B, which must arrive.
3. **Accepted by reviewer.** A14 and task 2.1 require paused socket reads and an observably blocked server write before checking pull behavior, slot release, and replacement admission while the peer still does not read.
4. **Accepted by reviewer.** The test-map rows require `Retry-After` on the 503, a fresh notifier loading N+1 from the same store after `none` during its save, and later delivery to admitted streams after refusing stream 2,001. Tasks 7.3 and 7.2 state the server assertions directly; task 9.1 names the updated notifier row.
## Apply drift (round 17)

Task 2.1 and 2.2 probes against Serverpod 4.1.2 disproved parts of A11 to A14 during apply. A12's `sendAsRaw` half was disproved too: returning a relic `Response` sets Content-Type. A13 was disproved for a deadline that closes a stalled transfer: the paused socket stalls the body, and relic gives no socket to close. A14 was disproved because Serverpod pipes endpoint streams with no backpressure; its end-and-replace half holds. A11 was disproved for a quiet healthy stream: pongs reset the idle timer. A7, A8, A9 and A10 hold. The owner chose to bound announcement streams by rate and lifetime, which drops the 60-second write-stall end and the one-pending-event rule. For downloads, the owner chose to free a download slot at the 2-minute deadline, end the body at its next chunk, and let the deploy proxy close stalled connections. D4, D8, A11 to A14, C19, C20, the bounds tables, the `realtime-bus` and `client-data-bundle` requirements and tasks 2.1, 2.2, 7.2, 7.3, 11.2 and 11.4 were amended to match. The pre-ship review covers the amendments.
