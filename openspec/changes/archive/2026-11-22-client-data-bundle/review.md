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

## Apply drift (round 18)

- **D12's chunked web parse had no task.** D12 has the web app parse in 2,000-line chunks that yield to the event loop, but no task built it: the group 8 web opener parsed in one pass. The owner chose (2026-11-20) to add an asynchronous, chunked open to `kaname_static_data_bundle` and use it on the web; task 8.4 now covers it, with a unit test that the chunked open yields between chunks and gives the same bundle as the one-pass open. D12 is unchanged.

## Apply drift (round 19)

- **First event at 20 s was 20.003 s at the client.** Group 7's real-time test showed that a stream opened at the announcer's start receives "none" just over 20 s after subscribing, because the server installed it exactly 20 s after start and the WebSocket delivery came on top. The owner chose (2026-11-20) to install "none" 19 s after start; the spec's 20-second limit (C29) is unchanged and the test asserts under 20 s. D8 and task 7.2 amended.
- **A lock cannot hold a stale read.** Task 7.2 had the "first read held" test hold the state read on a separate locking connection, but a read blocked on a lock sees the newest state when it is released, so it can never return the stale build the test must catch. The owner chose (2026-11-20) to let the real read run and hold its result behind a gate before the announcer uses it. Task 7.2 amended.

## Apply drift (round 20)

- **No reason for the first moments.** D21's reasons did not cover the time before the kept copy has loaded and the first announcement has arrived; "downloading" would be untrue then. The owner chose (2026-11-20) to add a "starting" reason with its own localised message.
- **Indexing failures.** A bundle that fails to index while the app holds no bundle is reported as "refused", like hash, format and build failures; the owner confirmed (2026-11-20). D21 amended for both.

## Apply drift (round 21)

- **The web stream never reached the server behind Caddy.** Task 11.1 found that the generated client opens its WebSocket at `<origin>/v1/websocket` whatever path the app configures (serverpod_client 4.1.2 replaces the path), while Caddy forwarded only `/api/*`, so the request got the single-page-app fallback and no announcement arrived. Chrome passed every other 11.1 check through a test proxy that forwarded that path. The owner chose (2026-11-20) to proxy `/v1/websocket` in Caddy: design "Routing" amended, task 11.6 added.
- **Which memory the envelope bounds.** The bundle build added 647 MiB to the server; with 19 served versions that is 742 to 790 MiB, inside a quarter of the 4 GB envelope, but the whole development (JIT) server peaked at 1,319 MiB. The owner chose (2026-11-20) the reading that the limit bounds the memory the bundle work adds; the bounds row says so.
- **Other browsers.** Edge, Firefox and Safari cannot run in this environment; the owner checks them (task 11.7, `[user]`).
