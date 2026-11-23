# Tasks

## Test map

Server tests live under `server/kaname_server/test/`: `unit/network/client_identity_test.dart` (new), `unit/network/trusted_proxies_test.dart` (new), `unit/static_data/refusal_log_test.dart` (new), and `integration/static_data/bundle_stream_test.dart` (existing, extended). Stack tests live in `server/kaname_client/test/stack/stack_test.dart`. The app test is in `app/test/static_data/static_data_notifier_test.dart`. A green row is unchanged behaviour in a MODIFIED requirement with a passing test, which task 7.1 re-runs.

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| client-static-data → The app follows the announced bundle while connected | Start with an old bundle | app/test/static_data/static_data_notifier_test.dart | old bundle and new announcement downloads once | green |
| client-static-data → The app follows the announced bundle while connected | Same bundle announced | app/test/static_data/static_data_notifier_test.dart | same announcement downloads nothing | green |
| client-static-data → The app follows the announced bundle while connected | Stream drops | app/test/static_data/static_data_notifier_test.dart | stream failures resubscribe after 5 s then 10 s | green |
| client-static-data → The app follows the announced bundle while connected | No bundle announced | app/test/static_data/static_data_notifier_test.dart | none announcement keeps the held bundle | green |
| client-static-data → The app follows the announced bundle while connected | Stale announcement | app/test/static_data/static_data_notifier_test.dart | lower revision of the same epoch is ignored | green |
| client-static-data → The app follows the announced bundle while connected | Server has no bundle yet | app/test/static_data/static_data_notifier_test.dart | the existing test for this scenario, named in task 7.1 | green |
| client-static-data → The app follows the announced bundle while connected | No server configured | app/test/static_data/static_data_notifier_test.dart | the existing test for this scenario, named in task 7.1 | green |
| client-static-data → The app follows the announced bundle while connected | Server refuses the subscription | app/test/static_data/static_data_notifier_test.dart | a refused subscription keeps build N, resubscribes after 5 s then 10 s and sends no other request | red |
| realtime-bus → Apps learn the current bundle from one stream | Subscribe | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | first event names the announced active build | green |
| realtime-bus → Apps learn the current bundle from one stream | Subscribe (A6 timing: fake clock, no real-time wait) | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the first event is sent within 20 s of subscribing on the fake clock, also when the first state read is held | red |
| realtime-bus → Apps learn the current bundle from one stream | Subscribe (A6 order: generated client, order and occurrence only, suite timeout as hang guard) | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | each subscription is admitted, then listened to, then receives its first event, for 1 and for 16 concurrent subscriptions | red |
| realtime-bus → Apps learn the current bundle from one stream | Subscribe before a switch is announced | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | subscribe after the switch commits but before its byte load ends … | green |
| realtime-bus → Apps learn the current bundle from one stream | First read held at start | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the generated-client startup test at :114 (first events within 20 s of subscribing) | green |
| realtime-bus → Apps learn the current bundle from one stream | Switch while subscribed | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the existing test for this scenario, named in task 7.1 | green |
| realtime-bus → Apps learn the current bundle from one stream | Active build without a bundle | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | failed active bundle announces previous, then active | green |
| realtime-bus → Apps learn the current bundle from one stream | Old-format bundle after a rollback | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the existing test at :369, named in task 7.1 | green |
| realtime-bus → Apps learn the current bundle from one stream | Nothing imported yet | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | no stored build gives a none first event | green |
| realtime-bus → Apps learn the current bundle from one stream | Refused subscription | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a refused subscription completes with no event and no error, and is never sent one later | red |
| realtime-bus → Announcements are ordered and bounded | Changes during subscribe | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the existing test for this scenario, named in task 7.1 | green |
| realtime-bus → Announcements are ordered and bounded | Rollback while subscribed | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | rollback after a switch ends on A with rising revisions | green |
| realtime-bus → Announcements are ordered and bounded | Switch and rollback between two reads | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | the existing test for this scenario, named in task 7.1 | green |
| realtime-bus → Announcements are ordered and bounded | Late wake-up for a retired announcement | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | an idle stream woken late by H's message after H2 was installed … | green |
| realtime-bus → Announcements are ordered and bounded | Stalled subscriber | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a stream that stops reading is sent at most one event per … | green |
| realtime-bus → Announcements are ordered and bounded | Stalled past the limit | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a stream whose client stopped reading is ended at 30 min, frees … (extended: replacement from a client under its own limit) | red |
| realtime-bus → Announcements are ordered and bounded | Stream expiry | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | healthy stream ends at 30 min, frees its place, removes its bus … (extended: frees its place under both limits) | red |
| realtime-bus → Announcements are ordered and bounded | Stream limit | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | stream 2,001 is refused, health stays under 1 s, and a later … (extended: refused under a second client key holding none) | red |
| realtime-bus → The bus delivers within one server instance | Worker publishes | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | worker switch reply reaches every bus subscription, and each open … | green |
| realtime-bus → The bus delivers within one server instance | No subscribers | server/kaname_server/test/integration/realtime/serverpod_realtime_bus_test.dart | the existing test for this scenario, named in task 7.1 | green |
| realtime-bus → Every delivery passes the delivery scope | Public topic | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | public event reaches a client stream through the endpoint with an … | green |
| realtime-bus → Every delivery passes the delivery scope | Scoped topic without a privacy scope | server/kaname_server/test/integration/realtime/serverpod_realtime_bus_test.dart | the existing test for this scenario, named in task 7.1 | green |
| realtime-bus → Announcement streams are bounded per client | One client cannot exhaust the pool | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a client's 17th subscription is refused cleanly while its 16 stay live and another client is admitted | red |
| realtime-bus → Announcement streams are bounded per client | Admitted before anyone listens | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | 16 unlistened streams from the endpoint hold the client's places and the 17th is refused | red |
| realtime-bus → Announcement streams are bounded per client | Publish before listen | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a stream listened to after B and C were announced first sends C, with no replay of B | red |
| realtime-bus → Announcement streams are bounded per client | Concurrent subscriptions from one client | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | 40 concurrent subscriptions from one client admit exactly 16 | red |
| realtime-bus → Announcement streams are bounded per client | Place freed when a stream ends | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a cancelled stream frees its client's place for the next subscription | red |
| realtime-bus → Announcement streams are bounded per client | Global bound still applies | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | with the global bound at 32 and two clients at 16, a third client is refused | red |
| realtime-bus → Announcement streams are bounded per client | Stream listened to late but before its expiry | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a stream first listened to 10 min after admission sends the current build at once | red |
| realtime-bus → Announcement streams are bounded per client | Stream listened to only after its expiry | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a stream first listened to after its 30 min ends with no event, no bus listener, and both places freed | red |
| realtime-bus → A client is identified by its network address | Direct connection | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a direct WebSocket client's forwarded header is ignored and its streams count for its peer | red |
| realtime-bus → A client is identified by its network address | Behind a trusted proxy | server/kaname_server/test/unit/network/client_identity_test.dart | trusted proxy: rightmost untrusted entry is the client | red |
| realtime-bus → A client is identified by its network address | Chain of trusted proxies | server/kaname_server/test/unit/network/client_identity_test.dart | chain of trusted proxies: walks past every trusted entry | red |
| realtime-bus → A client is identified by its network address | Repeated header lines | server/kaname_server/test/unit/network/client_identity_test.dart | repeated header lines are read in arrival order | red |
| realtime-bus → A client is identified by its network address | Entries with ports and brackets | server/kaname_server/test/unit/network/client_identity_test.dart | ports and brackets are stripped; a bare IPv6 entry keeps every group | red |
| realtime-bus → A client is identified by its network address | Trusted proxy sends no usable header | server/kaname_server/test/unit/network/client_identity_test.dart | no usable header falls back to the proxy's own address with a fallback reason | red |
| realtime-bus → A client is identified by its network address | Trusted proxy reached over an IPv4-mapped address | server/kaname_server/test/unit/network/client_identity_test.dart | a mapped peer matches its IPv4 trust entry | red |
| realtime-bus → A client is identified by its network address | Neighbour of a trusted IPv6 proxy | server/kaname_server/test/unit/network/client_identity_test.dart | a /64 neighbour of a trusted IPv6 host is not trusted | red |
| realtime-bus → A client is identified by its network address | Connection with no known address | server/kaname_server/test/unit/network/client_identity_test.dart | an unknown peer is never trusted and counts as unknown | red |
| realtime-bus → A client is identified by its network address | Header cut through an entry | server/kaname_server/test/unit/network/client_identity_test.dart | a fragment cut by the 2 KiB budget is ignored | red |
| realtime-bus → A client is identified by its network address | Twenty-entry cap | server/kaname_server/test/unit/network/client_identity_test.dart | an untrusted 21st entry from the right is never read | red |
| realtime-bus → A client is identified by its network address | Rightmost entry ends the header | server/kaname_server/test/unit/network/client_identity_test.dart | the rightmost entry ends at the end of the header | red |
| realtime-bus → A client is identified by its network address | IPv6 addresses in one /64 | server/kaname_server/test/unit/network/client_identity_test.dart | IPv6 clients in one /64 share a key | red |
| realtime-bus → A client is identified by its network address | IPv4-mapped address | server/kaname_server/test/unit/network/client_identity_test.dart | a mapped client counts as its IPv4 address | red |
| realtime-bus → Trusted proxies are configured at start | Setting unset | server/kaname_server/test/unit/network/trusted_proxies_test.dart | unset or empty setting trusts nobody | red |
| realtime-bus → Trusted proxies are configured at start | Valid list | server/kaname_server/test/unit/network/trusted_proxies_test.dart | addresses and ranges with spaces parse | red |
| realtime-bus → Trusted proxies are configured at start | Invalid entry | server/kaname_server/test/unit/network/trusted_proxies_test.dart | the first invalid entry is named and start-up stops | red |
| realtime-bus → Trusted proxies are configured at start | IPv4-mapped range | server/kaname_server/test/unit/network/trusted_proxies_test.dart | a mapped IPv6-form range is refused with a write-as-IPv4 hint | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Client loops on subscribing | server/kaname_server/test/unit/static_data/refusal_log_test.dart | 500 refusals in a minute log one warning | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Refusals continue past a minute | server/kaname_server/test/unit/static_data/refusal_log_test.dart | the next warning after a minute gives the count since the last | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Refusal just after a warning | server/kaname_server/test/unit/static_data/refusal_log_test.dart | no second warning within the minute | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Full map reused after a minute | server/kaname_server/test/unit/static_data/refusal_log_test.dart | a full map evicts the oldest warning on elapsed time, despite a wall-clock step back | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Many distinct clients | server/kaname_server/test/unit/static_data/refusal_log_test.dart | 5,000 clients log at most 4,096 named warnings and one other-clients warning | red |
| realtime-bus → Announcement refusals are logged at a bounded rate | Server runs no announcer | server/kaname_server/test/integration/static_data/bundle_stream_test.dart | a server with no announcer refuses 100 subscriptions with one warning | red |
| self-host-stack → The stack's server trusts only Caddy as proxy | Two clients through Caddy | server/kaname_client/test/stack/stack_test.dart | a host client holding 16 does not stop a container client on the stack network | red |
| self-host-stack → The stack's server trusts only Caddy as proxy | Client sends its own forwarded header | server/kaname_client/test/stack/stack_test.dart | 17 WebSocket upgrades with spoofed headers: 16 live, the 17th completes cleanly, another client still served | red |
| self-host-stack → The stack's server trusts only Caddy as proxy | Configuration check | tools/kaname_tools/test/compose_config_test.dart | pinned subnet, dynamic range, Caddy's fixed address outside it, and trusted proxies equal to Caddy's address | red |
| self-host-stack → The stack's server trusts only Caddy as proxy | Local client through Docker's gateway | server/kaname_client/test/stack/stack_test.dart | a host browser's streams count for the gateway with no forwarded-header warning | red |

## 1. Settle the assumptions the server work relies on

- [ ] 1.1 Verify A1: read Serverpod 4.1.2's `MethodStreamSession` construction and Relic's `Request.connectionInfo` in the pub cache (`relic` 2.0.0-rc.4, `relic_core` 2.0.0, `pubspec.lock`). Record in one line in the PR description whether `session.request` carries the upgrade request's peer and its raw `X-Forwarded-For` lines. If it does not, stop: design drift.
- [ ] 1.2 Verify A2 and A6: read Serverpod's stream manager in the pub cache. Note whether the endpoint's returned stream is listened to within the same handling of the open message (A6) or after asynchronous work (A2). D5 holds either way. A late listen would put A6, and with it the 20-second promise, in doubt, so treat that as design drift.
- [ ] 1.3 Check A5 is not relied on: confirm that the client-identity unit tests in group 2 bound the work at 2 KiB and 20 entries for an oversized header. No task depends on Dart's HTTP header-size limit.

## 2. Client identity and the trusted-proxy setting

- [ ] 2.1 Write the failing unit tests in `server/kaname_server/test/unit/network/trusted_proxies_test.dart` for the four "Trusted proxies are configured at start" rows. Verify they fail because the parser does not exist yet.
- [ ] 2.2 Implement the trusted-proxy parser in `server/kaname_server/lib/src/network/` (D2, D3): addresses and CIDR ranges, with spaces trimmed. An invalid entry, including a mapped IPv6-form range, raises an error that names it. Verify task 2.1's tests pass and flip their rows green.
- [ ] 2.3 Write the failing unit tests in `server/kaname_server/test/unit/network/client_identity_test.dart` for the thirteen client-identity rows, excluding "Direct connection". Verify they fail because `clientKeyFor` does not exist yet.
- [ ] 2.4 Implement `clientKeyFor` in `server/kaname_server/lib/src/network/client_identity.dart` (D1, D3, D7). It walks the raw lines backwards, joined by a virtual comma, within 2 KiB counting separators and at most 20 entries. It counts only complete entries, matches trust on the whole normalised address, groups IPv6 keys by /64, never trusts an unknown peer, and returns the fallback reason. Write C8 as its doc comment, and C1's rule in the same comment as the reason for right-to-left reading. Verify task 2.3's tests pass and flip their rows green. Then run `mise exec -- dart analyze server/kaname_server`.
- [ ] 2.5 Read `KANAME_TRUSTED_PROXIES` in `serve()` (`server/kaname_server/lib/server.dart`) before `pod.start()`, next to the pool-size check. An invalid entry stops start-up with the parser's error. Verify with a unit test of the start-up check that names `172.30.0.0/33`, and with the "Invalid entry" row already green.

## 3. Per-client admission in the runtime and the endpoint

- [ ] 3.1 Write the failing integration tests in `bundle_stream_test.dart` for the eight "Announcement streams are bounded per client" rows and the "Refused subscription" row. Each refusal assertion requires normal completion with zero events and zero errors, and checks that the client's other streams are still live (D7). Tests that need several clients replace the runtime's session-to-key function with per-test-client keys (D4). Verify they fail on the missing per-client bound.
- [ ] 3.2 Add to `BundleAnnouncementRuntime`: `defaultMaxStreamsPerClient = 16`, `maxStreamsPerClient`, per-client counts, the session-to-client-key function, and `admit`/`release`. `reset()` restores them. Write C3 on `BundleAnnouncementRuntime`, and C5 and C10 on `defaultMaxStreamsPerClient`, as doc comments. Verify with `mise exec -- dart analyze server/kaname_server`.
- [ ] 3.3 Change `StaticDataEndpoint.bundleAnnouncements` (D5). Admission takes both places and starts the 30-minute expiry in one synchronous step. `onListen` subscribes to the bus and schedules the first send only for a stream that is still open; an ended stream closes at once. `end()` releases both places once. Write C2 as its doc comment. Verify task 3.1's tests pass and flip their rows green.
- [ ] 3.4 Extend the existing tests for "Stalled past the limit", "Stream expiry" and "Stream limit". Both saturation fixtures set `maxStreamsPerClient` to 2,001 during setup and restore it through `reset()`. The 2,000-stream fixture sends its refused subscription under a second client key, checked to hold no stream. The stalled-reader fixture's refusal stays on the key holding 1,999. Verify they pass and flip their rows green.
- [ ] 3.5 Add the direct WebSocket test for "Direct connection": an untrusted loopback peer sends `X-Forwarded-For`, and its streams count for 127.0.0.1. Verify it passes and flip its row green.
- [ ] 3.6 Write the A6 timing test at endpoint level, "the first event is sent within 20 s of subscribing on the fake clock, also when the first state read is held". The owner chose it after the design review ("Add the test" and "Just as long as it doesn't become another timeout that's flaky"; Chosen by: user). It never waits on real time: it injects the runtime's fake `ServerClock` and advances fake time explicitly. It subscribes through the endpoint at fake time T, records the fake elapsed time at admission, at listen and at the first send, then asserts that the first send happens before T + 20 s. It covers both a ready announcement and a held first read, where the announcer installs "none" at 19 s. With the endpoint's sends driven by the fake clock, the 20-second bound stays below the generated client's idle timeout (about 40 s, recorded in `announcement_stream_probe_test.dart`) without any real wait. Verify it passes in CI, or locally only when the owner's machine is free.
- [ ] 3.7 Write the A6 order test through the generated client, "each subscription is admitted, then listened to, then receives its first event, for 1 and for 16 concurrent subscriptions". It asserts only order and occurrence: the runtime records the order of the admission and listen events, and the test awaits each stream's first event as a future. It sets no wall-clock budget, only a generous suite-level timeout as a guard against hangs. A listen that never comes, or comes after the first event, disproves A6: stop and treat it as design drift. Verify it passes in CI, or locally only when the owner's machine is free.

## 4. Bounded refusal logging

- [ ] 4.1 Write the failing unit tests in `server/kaname_server/test/unit/static_data/refusal_log_test.dart` for the five refusal-log rows that use a fake clock. Also write the failing integration test for "Server runs no announcer". Verify they fail because every refusal currently logs.
- [ ] 4.2 Add `elapsed()` to `ServerClock`, backed in production by a `Stopwatch` started with the clock, and to the test fakes. Verify `mise exec -- dart analyze server/kaname_server` reports no issue and the existing fakes compile.
- [ ] 4.3 Implement `BundleAnnouncementRuntime.noteRefusal` (D6). Each client and reason pair warns once a minute on elapsed time, with the count since its last warning. The map holds 4,096 pairs in insertion order, a pair moves only when it warns, and the oldest is evicted when more than a minute old. Other pairs share an `other clients` total. Route every refusal reason and the proxy-fallback warning through it. Write C9 as its doc comment. Verify task 4.1's tests pass and flip their rows green.

## 5. Self-host stack

- [ ] 5.1 Write the failing Compose configuration test in `tools/kaname_tools/test/compose_config_test.dart` for "Configuration check". Verify it fails on the current `deploy/compose.yaml`.
- [ ] 5.2 In `deploy/compose.yaml`, pin the stack network's subnet, set its `ip_range`, and give Caddy a fixed IPv4 address outside that range. Set the server's `KANAME_TRUSTED_PROXIES` to exactly Caddy's address (C4). Verify task 5.1 passes and flip its row green.
- [ ] 5.3 Write C6 as a comment in `deploy/Caddyfile`'s global options block. Update `deploy/README.md` with:
  - the setting;
  - the shipped loopback stack versus a public deployment;
  - the front proxy: fixed address outside the dynamic range, in both trust lists, appending its peer's address, and the two checks, repeated after any network change;
  - changing the subnet, range and Caddy's address together;
  - adopting the pinned subnet through `docker compose down`, which keeps volumes, not `mise run stack:down`.

  Verify by reading the rendered README section.
- [ ] 5.4 Write the stack tests for "Two clients through Caddy", "Client sends its own forwarded header" (17 separate WebSocket upgrades) and "Local client through Docker's gateway" in `server/kaname_client/test/stack/stack_test.dart`. They run in CI. Run them locally only with the owner's approval, when the owner's machine is free. Flip their rows green when CI passes them.

## 6. App behaviour on refusal

- [ ] 6.1 Add the test "a refused subscription keeps build N, resubscribes after 5 s then 10 s and sends no other request" to `app/test/static_data/static_data_notifier_test.dart`. It uses a fake source whose stream ends at once with no event, and checks that no status or other call is made (C7, already at its spec destination). It is expected to pass at once, because the app is unchanged (S2). Run it, and flip its row green.

## 7. Integration checks

- [ ] 7.1 Name the existing tests for the green rows marked "named in task 7.1" in the test map, then re-run every green row's test. Do this through CI, or locally only when the owner's machine is free. Verify they all pass.
- [ ] 7.2 Run `mise run check` (through CI, or locally only when the owner's machine is free) and `mise exec -- openspec validate limit-announcement-streams-per-client --strict`. Verify both pass.
- [ ] 7.3 Confirm that C1, C4 and C7 are present at their spec destinations, and that C2, C3, C5, C6, C8, C9 and C10 are present as doc comments where tasks 2.4, 3.2, 3.3, 4.3 and 5.3 put them. Verify by reading each destination.

## Workflow follow-up

- The design review ended in USER_OVERRIDE after round 8 (see review.md). The owner may ask for another review before apply.
- Pre-ship review, PR and archive follow the Specwright workflow after apply.
