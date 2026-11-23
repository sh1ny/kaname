# Proposal

## Why

Issue [#20](https://github.com/sh1ny/kaname/issues/20): the bundle-announcement stream needs no sign-in, and its only bound is the server-wide cap of 2,000 open streams. One unauthenticated client can open all 2,000 and hold them for 30 minutes at a time. While it does, every new app is refused and never learns of a new SDE build. Apps keep their stored bundle and offline search, so the result is stale static data, not an outage. The weekly security check on #15 found it on 2026-11-23. It is not exploitable yet, because Kaname is not deployed publicly, but it must be closed before a public deployment.

This is a side change outside the roadmap's milestones; it advances no milestone exit criterion.

## What Changes

- **Per-client bound on announcement streams:** the server holds at most 16 open announcement streams per client, besides the existing 2,000 in all. A subscription over either bound is refused as today: the stream ends at once with no event. Both places are taken when the subscription is admitted, in the same step as the check, so concurrent subscriptions cannot pass the check together and overshoot either bound. Until it is listened to, an admitted stream only holds its places and receives nothing. A stream's 30-minute life runs from admission and its first-event limit, as today, from subscribing, and a stream that has ended never starts sending, even if it is listened to later.
- **Client identity without sign-in:** a client is the address its connection comes from. When that address belongs to a trusted proxy, the client is the nearest untrusted address in the proxy's `X-Forwarded-For` header, read from right to left over at most 20 entries. Only the last 2 KiB and 20 entries of the header are read. When they give no untrusted address, the proxy's own address counts, with a warning. Trust matches whole addresses, and a connection with no known address is never trusted. IPv4 addresses count whole. IPv6 addresses count by their /64 prefix, and IPv4-mapped IPv6 counts as IPv4, for trust matching too. A client cannot choose its own identity through a header unless it is itself a trusted proxy.
- **Trusted-proxy setting:** a new server setting, `KANAME_TRUSTED_PROXIES`, holds a comma-separated list of IP addresses and CIDR ranges. It is empty by default, which trusts nobody. A server with an invalid entry does not start, and its error names the entry.
- **Self-host stack:** Compose pins the stack's internal network subnet, keeps its dynamic address range away from a fixed IPv4 address for Caddy, and passes only that address to the server as its trusted proxy. Caddy is meant to be a public deployment's edge: it sees the real client address and writes it into `X-Forwarded-For`. The shipped stack itself is loopback-only. Connections that reach Caddy through Docker's gateway (the loopback-only local stack) count as the gateway's address, with no warning. `deploy/README.md` documents the setting and separates the shipped loopback stack from a public deployment, and explains how to put a trusted proxy in front of Caddy (on the stack network, with its address in both trust lists, checked before going public). Any trusted proxy must append the address it received the connection from rather than pass a caller's header through. It also explains that adopting the pinned subnet on an existing install needs `docker compose down` (which keeps the volumes) and how to change the subnet and Caddy's address together.
- **Refusal logging:** refusals, for every reason, are logged at most once per client and reason per minute, with the number of refusals since the last log line, so a client that loops on subscribing cannot flood the log. At most 4,096 client and reason pairs are tracked; others share one total. A client that stops being refused, or whose entry is evicted to make room, does not get its last suppressed count reported.
- **App:** unchanged. A refused stream already ends without an event, and the app resubscribes after 5 seconds, doubling to at most 5 minutes. The client-static-data spec gains a scenario for a refusal, and a test pins it.
- **Out of scope:** per-client limits on other unauthenticated calls (status, operation, bundle download), a distinct "refused" signal on the wire, a status poll while refused, and a configurable per-client limit.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `realtime-bus`: a per-client bound on announcement streams, admission that takes both places at once and starts the stream's life, how a client is identified behind a trusted proxy, the trusted-proxy setting, and refusal logging.
- `client-static-data`: a scenario that pins what the app does when the server refuses its subscription: it keeps its bundle, backs off and makes no other request to learn the build.
- `self-host-stack`: the stack's server trusts only Caddy's fixed address as its proxy, so the per-client bound applies to each real client and not to Caddy.

## Impact

- **Server:** `server/kaname_server/lib/src/static_data/static_data_endpoint.dart` (admission and refusal), `bundle_announcement_runtime.dart` (per-client counts), a new client-identity module under `server/kaname_server/lib/src/`, and server start-up (reading and checking `KANAME_TRUSTED_PROXIES`). Integration tests in `server/kaname_server/test/integration/static_data/bundle_stream_test.dart` and unit tests for client identity.
- **Deployment:** `deploy/compose.yaml` (a pinned network subnet and the new environment variable), `deploy/README.md`, and the compose configuration test in `tools/kaname_tools/test/compose_config_test.dart`.
- **App:** test only, in `app/test/static_data/static_data_notifier_test.dart`.
- **Wire protocol, database and generated client:** no change.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

All decisions below were put to the owner through the Orca coordinator on 2026-11-23. The owner chose the recommended option for each: "rec for all. S1 A, S2 A, S3 A, D1 A, D2 A, D3 A, D4 A, D5 A, D6 A." After design-review rounds 1 and 2 the owner took the recommended fixes: "Take all 4 recommendations" and "Take all 6 recommendations".

### S1: Only the announcement stream gets the per-client limit

- **Choice:** limit only the announcement stream per client. The client-identity code is a separate module that other endpoints can adopt later, but nothing else adopts it in this change.
- **Rejected:** a general per-client limit for every unauthenticated call (status, operation, bundle download). The bundle download already has its own bound (16 in flight), and the status call is served from a 1-second shared cache. Neither holds a resource for 30 minutes, so widening the scope adds work without closing a known hole.
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour that users see (who can subscribe).
- **Chosen by:** user

### S2: The app stays as it is

- **Choice:** leave the app unchanged, add a test that pins its backoff after a refused stream, and record the behaviour as a client-static-data scenario. The owner chose the scenario over a doc comment after the design review (2026-11-23).
- **Rejected:** polling `status()` while refused, which adds a second path to the announced build; a distinct "refused" signal, which changes the wire contract and the generated client.
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour that users see (what the app does when refused).
- **Chosen by:** user

### S3: The self-host stack is configured too

- **Choice:** the stack's Compose file pins its network subnet, limits its dynamic address range (`ip_range`) so that it excludes a fixed IPv4 address for Caddy, and passes only Caddy's address to the server as its trusted proxy. The deploy README documents the setting and separates the shipped loopback stack from a public deployment. It says how to put a proxy or tunnel in front of Caddy: the proxy joins the stack network with a fixed address outside the dynamic range, writes the client's address, and Caddy appends the proxy's. The proxy's address then goes into both Caddy's `trusted_proxies` and the server's `KANAME_TRUSTED_PROXIES`, beside Caddy's. The README gives two checks: before trusting the proxy, that Caddy sees the proxy's own address; then, with both trust lists set and before the route is public, an end-to-end check, both repeated after any network or address change. It also explains how to change the subnet and Caddy's address together, and that an existing install adopts the pinned subnet through `docker compose down`, which keeps the volumes. The owner chose the `ip_range` detail after design-review round 1, and the front-proxy condition after round 2 (both 2026-11-23).
- **Rejected:** a server-only change that leaves operators to set up trust. Behind the stack's own Caddy, every client would then share Caddy's address, and 16 streams would be the limit for the whole install. Also rejected: trusting the whole subnet, the owner's first choice. Local connections reach Caddy from Docker's gateway, which is inside the subnet, so every local subscription would fall back to Caddy's address with a warning. The owner chose the narrower trust in a follow-up question (2026-11-23).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes (a deployment configuration key).
- **Chosen by:** user
