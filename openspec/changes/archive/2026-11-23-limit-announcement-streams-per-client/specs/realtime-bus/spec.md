## MODIFIED Requirements

### Requirement: Apps learn the current bundle from one stream
The server SHALL offer an unauthenticated stream that first sends, within 20 seconds of an admitted subscription being made, a limit kept below the generated client's idle timeout, the bundle last made downloadable (build, size and SHA-256), then an event when it changes; changes between two reads of the server's state MAY be merged. The announced bundle SHALL be the active build's built bundle in the current format, else the previous build's, else none, which the event SHALL say.

#### Scenario: Subscribe
- **WHEN** an app subscribes while build N is active and its bundle has been announced, and the server admits the subscription
- **THEN** the first event names build N with its size and SHA-256

#### Scenario: Subscribe before a switch is announced
- **WHEN** the switch to build N+1 has committed but the server has not yet loaded N+1's bundle, and an app's subscription is admitted
- **THEN** the first event names build N, and an event naming build N+1 follows once its bundle can be downloaded

#### Scenario: First read held at start
- **WHEN** the server starts, its first state read is held for 3 minutes, and an app subscribes through the generated client
- **THEN** every admitted subscription's first event arrives within 20 seconds of subscribing, each subscription opened while the read is held first says no bundle is available, the app resubscribes whenever a stream ends, no second state read starts until the held one ends, the held read's result is never published, and the app receives an event naming the active build from the fresh read that follows

#### Scenario: Switch while subscribed
- **WHEN** an app is subscribed and the server switches to build N+1 whose bundle is stored, and nothing changes until the app receives an event
- **THEN** the app receives one event naming build N+1

#### Scenario: Active build without a bundle
- **WHEN** an app's subscription is admitted while the active build's bundle failed to build and the previous build has one
- **THEN** the first event names the previous build, and an event naming the active build follows once its bundle is built

#### Scenario: Old-format bundle after a rollback
- **WHEN** a server that builds format 2 has rolled back to a build whose stored bundle is format 1, and the previous build's bundle is format 2
- **THEN** the stream announces the previous build's format 2 bundle until the active build's bundle is rebuilt

#### Scenario: Nothing imported yet
- **WHEN** an app's subscription is admitted before any build is stored
- **THEN** the first event says no bundle is available

#### Scenario: Refused subscription
- **WHEN** an app subscribes while its client already holds 16 open streams
- **THEN** the subscription ends at once without an event, and the first-event limit does not apply to it

### Requirement: Announcements are ordered and bounded
Each announcement SHALL carry the server's epoch and a revision that rises with each change, and a stream SHALL never send a revision lower than or equal to one it already sent. The server SHALL hold at most 2,000 announcement streams, refusing more, SHALL end each 30 minutes after admitting it, and SHALL send each stream at most one event per change of the installed announcement. Each send SHALL carry the announcement installed when the stream hands it to Serverpod, never an earlier copy.

#### Scenario: Changes during subscribe
- **WHEN** an app subscribes and two changes, to build B and then to build C, are published before its first event is sent, and the first event names build C
- **THEN** no event naming build B follows

#### Scenario: Rollback while subscribed
- **WHEN** an app subscribed while build A was announced, then build B, and then a rollback announces build A again
- **THEN** the app ends on build A, and each event it receives has a higher revision than the one before

#### Scenario: Switch and rollback between two reads
- **WHEN** an app is subscribed while build A is announced, and a switch to build B and a rollback to build A both happen before the server next reads its state
- **THEN** the app receives either no new event or an event naming build A, and never an event naming build B after one naming build A

#### Scenario: Late wake-up for a retired announcement
- **WHEN** an app's stream is idle, the bus message for hash H is delayed until H2 has been installed, and the publish of H2 fails
- **THEN** when the delayed message arrives the stream sends H2's announcement, and never H

#### Scenario: Stalled subscriber
- **WHEN** one app stops reading its stream while ten announcements are published, and another app keeps reading
- **THEN** the stalled stream is sent at most ten events, each with a higher revision than the one before, and the reading app ends on the latest announcement with each event's revision higher than the one before

#### Scenario: Stalled past the limit
- **WHEN** an app has stopped reading its stream and the stream reaches its 30-minute limit
- **THEN** the server ends that stream and frees its place while the app still does not read, and a new subscription from a client under its own 16-stream limit is admitted into that place

#### Scenario: Stream expiry
- **WHEN** a stream whose client keeps reading has been open for 30 minutes
- **THEN** the server ends it, frees its place under both limits and removes its bus listener, and a new subscription from that app is admitted and first receives the current announcement

#### Scenario: Stream limit
- **WHEN** 2,000 announcement streams are open and another app, whose client holds fewer than 16, subscribes
- **THEN** that subscription is refused, the open streams keep working, and the health endpoint still answers in under 1 second

### Requirement: The bus delivers within one server instance
The bus SHALL deliver each message to every subscriber in the same server process. Only the main isolate SHALL publish; a change a worker isolate reports reaches the bus through the main isolate. Delivery across server instances is not part of this capability.

#### Scenario: Worker publishes
- **WHEN** the compute worker reports a switch and the main isolate publishes the build change
- **THEN** every bus subscription in that process receives it, and every build-change stream that is being listened to sends it or a newer announcement

#### Scenario: No subscribers
- **WHEN** a message is published while nothing subscribes to its topic
- **THEN** the message is dropped and publishing does not fail

### Requirement: Every delivery passes the delivery scope
A topic SHALL be declared public or scoped, and every delivery to a client stream SHALL pass the topic's scope. A public topic SHALL carry only public, non-character data, and its scope SHALL pass every message. The static-data topic SHALL be public. A scoped topic SHALL NOT be delivered to a client stream until the privacy scope exists to filter it.

#### Scenario: Public topic
- **WHEN** a build-change message is published on the public static-data topic
- **THEN** it passes the public scope and reaches every client stream that is being listened to, which sends it or a newer announcement

#### Scenario: Scoped topic without a privacy scope
- **WHEN** a client stream subscribes to a topic declared scoped
- **THEN** the subscription is refused with reason "topic needs the privacy scope"

## ADDED Requirements

### Requirement: Announcement streams are bounded per client
The server SHALL admit at most 16 announcement subscriptions per client, besides 2,000 in all, and SHALL refuse one over either bound by ending its stream at once without an event. Admission SHALL take both places in one step, so simultaneous subscriptions never exceed a bound. An admitted stream SHALL receive no bus message until it is listened to, and SHALL then first send the current bundle. A stream that ends for any reason SHALL free both places and never start sending.

#### Scenario: One client cannot exhaust the pool
- **WHEN** one client holds 16 open announcement streams and opens a 17th
- **THEN** the 17th ends at once without an event, the client's 16 streams keep working, and a subscription from another client is admitted and receives the current announcement

#### Scenario: Admitted before anyone listens
- **WHEN** a client is admitted 16 times and none of the 16 streams has been listened to yet, and the client opens a 17th
- **THEN** the 17th ends at once without an event

#### Scenario: Publish before listen
- **WHEN** a subscription is admitted, build B is announced and then build C, and its stream is then listened to before its expiry
- **THEN** its first event names build C, and it receives no replay of build B

#### Scenario: Concurrent subscriptions from one client
- **WHEN** one client with no open streams opens 40 subscriptions at the same moment
- **THEN** exactly 16 of them are admitted and the other 24 end at once without an event

#### Scenario: Place freed when a stream ends
- **WHEN** a client holds 16 open streams, one of them is cancelled by the client or reaches its 30-minute limit, and the client then subscribes again
- **THEN** the new subscription is admitted and first receives the current announcement

#### Scenario: Global bound still applies
- **WHEN** the server's whole bound is full of admitted subscriptions from several clients, none of them over 16, and another client holding none subscribes
- **THEN** that subscription ends at once without an event

#### Scenario: Stream listened to late but before its expiry
- **WHEN** a subscription is admitted by the server's endpoint, nothing listens to the stream it returned for 10 minutes, and a listener then attaches while build N is announced
- **THEN** the stream sends build N as soon as it is listened to. This is a server-internal case: an app's subscription is listened to as it is made, so its 20-second first-event promise is unchanged

#### Scenario: Stream listened to only after its expiry
- **WHEN** a subscription is admitted by the server's endpoint, nothing listens to the stream it returned for 30 minutes, and a listener then attaches
- **THEN** the stream ends at once without an event, no bus listener is added for it, and its places under both bounds were freed at the 30-minute mark

### Requirement: A client is identified by its network address
Without sign-in, a client SHALL be its connection's address or, behind a trusted proxy, the rightmost complete untrusted `X-Forwarded-For` entry in the header's last 2 KiB and 20 entries. Trust SHALL match whole addresses or listed ranges; counting SHALL group IPv6 by /64; IPv4-mapped addresses SHALL count as IPv4. Other connections' headers SHALL be ignored, and an unknown peer SHALL never be trusted. Only proxies that append their peer's address SHALL be configured as trusted.

#### Scenario: Direct connection
- **WHEN** a client at 203.0.113.7 connects without a proxy and sends `X-Forwarded-For: 198.51.100.1`
- **THEN** the server counts its streams for 203.0.113.7 and ignores the header

#### Scenario: Behind a trusted proxy
- **WHEN** the connection comes from a trusted proxy and carries `X-Forwarded-For: 198.51.100.1, 203.0.113.7`, where 203.0.113.7 is not trusted
- **THEN** the server counts the stream for 203.0.113.7, never for 198.51.100.1 or the proxy: entries left of the ones trusted proxies appended are written by the client, so reading the leftmost entry, or trusting an address because it is private rather than listed, would let a client choose its own bucket

#### Scenario: Chain of trusted proxies
- **WHEN** the connection comes from a trusted proxy and carries `X-Forwarded-For: 203.0.113.7, 10.0.0.5`, where 10.0.0.5 is also a trusted proxy
- **THEN** the server counts the stream for 203.0.113.7

#### Scenario: Repeated header lines
- **WHEN** the connection comes from a trusted proxy and carries two `X-Forwarded-For` lines, `198.51.100.1` and then `203.0.113.7`
- **THEN** the server reads them as `198.51.100.1, 203.0.113.7` and counts the stream for 203.0.113.7

#### Scenario: Entries with ports and brackets
- **WHEN** a trusted proxy forwards `203.0.113.7:4711`, `[2001:db8:1:2::a]:4711`, `[2001:db8:1:2::a]` or `2001:db8:1:2::a`
- **THEN** the server reads the address 203.0.113.7 or 2001:db8:1:2::a, and never reads the last group of a bare IPv6 address as a port

#### Scenario: Trusted proxy sends no usable header
- **WHEN** the connection comes from a trusted proxy and its `X-Forwarded-For` header is missing or empty, every entry is a trusted proxy, an entry that is not an IP address comes before any untrusted address, or no untrusted address is within the header's last 2 KiB and rightmost 20 entries
- **THEN** the server counts the stream for the proxy's own address and logs a warning that names the proxy, at the rate the refusal log allows

#### Scenario: Trusted proxy reached over an IPv4-mapped address
- **WHEN** 172.30.0.10 is a trusted proxy and a connection arrives from ::ffff:172.30.0.10 with `X-Forwarded-For: 203.0.113.7`
- **THEN** the server treats the connection as the trusted proxy and counts the stream for 203.0.113.7

#### Scenario: Neighbour of a trusted IPv6 proxy
- **WHEN** 2001:db8:1:2::10 is a trusted proxy and a connection arrives from 2001:db8:1:2::11 with `X-Forwarded-For: 203.0.113.7`
- **THEN** the server ignores the header and counts the stream for the client 2001:db8:1:2::/64

#### Scenario: Connection with no known address
- **WHEN** a stream's connection reports no peer address and carries `X-Forwarded-For: 203.0.113.7`
- **THEN** the server ignores the header and counts the stream under one shared `unknown` client

#### Scenario: Header cut through an entry
- **WHEN** a trusted proxy's `X-Forwarded-For` is longer than 2 KiB, its last 2 KiB hold fewer than 20 complete entries, all trusted proxies, and begin inside the untrusted entry 198.51.100.123, so that the cut part 8.51.100.123 is itself a valid untrusted address
- **THEN** the server ignores that partial entry and counts the stream for the connecting proxy's own address

#### Scenario: Twenty-entry cap
- **WHEN** a trusted proxy sends a short `X-Forwarded-For` whose rightmost 20 entries are all trusted proxies and whose 21st entry from the right is 203.0.113.7
- **THEN** the server counts the stream for the connecting proxy's own address

#### Scenario: Rightmost entry ends the header
- **WHEN** a trusted proxy sends `X-Forwarded-For: 10.0.0.9, 203.0.113.7`, with no separator after the last entry
- **THEN** the server counts the stream for 203.0.113.7

#### Scenario: IPv6 addresses in one /64
- **WHEN** clients at 2001:db8:1:2::a and 2001:db8:1:2::b each open 10 streams
- **THEN** the server counts them as one client, admits 16 streams and refuses the other 4

#### Scenario: IPv4-mapped address
- **WHEN** one connection comes from ::ffff:203.0.113.7 and another from 203.0.113.7
- **THEN** the server counts both under the client 203.0.113.7

### Requirement: Trusted proxies are configured at start
The server SHALL read its trusted proxies at start from `KANAME_TRUSTED_PROXIES`, a comma-separated list of IP addresses and CIDR ranges, and SHALL trust no proxy when it is unset or empty. A server whose list holds an entry that is not an IP address or CIDR range, or an IPv4-mapped range written in IPv6 form, SHALL NOT start, and SHALL report that entry.

#### Scenario: Setting unset
- **WHEN** the server starts without `KANAME_TRUSTED_PROXIES`
- **THEN** it starts, and every client is identified by its connection's address

#### Scenario: Valid list
- **WHEN** the server starts with `KANAME_TRUSTED_PROXIES=172.30.0.0/24, 10.0.0.5`
- **THEN** it starts, and trusts connections from 172.30.0.0/24 and 10.0.0.5 as proxies

#### Scenario: Invalid entry
- **WHEN** the server starts with `KANAME_TRUSTED_PROXIES=172.30.0.0/33,caddy`
- **THEN** it exits without serving, with an error that names the first invalid entry `172.30.0.0/33`

#### Scenario: IPv4-mapped range
- **WHEN** the server starts with `KANAME_TRUSTED_PROXIES=::ffff:172.30.0.0/120`
- **THEN** it exits without serving, with an error that names `::ffff:172.30.0.0/120` and says to write the range as IPv4

### Requirement: Announcement refusals are logged at a bounded rate
The server SHALL log refusals of announcement subscriptions, for every reason, and proxy-header fallbacks at most once per client and reason per minute. A warning SHALL name the client and reason and give the refusals since that pair's previous warning while it was tracked. At most 4,096 pairs SHALL be tracked; refusals of others SHALL share one `other clients` total under the same rule.

#### Scenario: Client loops on subscribing
- **WHEN** a client at its limit opens 500 more subscriptions within one minute
- **THEN** every one is refused, and the server logs one warning for that client in that minute

#### Scenario: Refusals continue past a minute
- **WHEN** the same client keeps being refused, and more than a minute has passed since its last warning
- **THEN** the next refusal logs a warning that gives the number of refusals since the last one

#### Scenario: Refusal just after a warning
- **WHEN** a client is refused, a warning is logged for it, and it is refused again within the same minute
- **THEN** no second warning is logged for it in that minute

#### Scenario: Full map reused after a minute
- **WHEN** 4,096 clients have each been refused and warned in turn, the first ten of them are refused again more than a minute later, the wall clock is set back an hour, and a new client is then refused
- **THEN** time is measured as elapsed time: each of the ten gets a warning with its count, and the new client takes the place of the eleventh client, whose warning is now the oldest, and gets a warning naming it, not `other clients`

#### Scenario: Many distinct clients
- **WHEN** 5,000 distinct clients are each refused once within one minute
- **THEN** the server logs at most 4,096 warnings naming a client and at most one `other clients` warning in that minute

#### Scenario: Server runs no announcer
- **WHEN** the server runs no announcer and one client subscribes 100 times within one minute
- **THEN** every subscription ends at once without an event, and the server logs one warning for that client and reason in that minute
