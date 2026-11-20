# 0014. Realtime bus topics

- Status: accepted (2026-11-20)
- Date: 2026-11-20
- Supersedes: none
- Chosen by: user (2026-11-19 to 2026-11-20, `client-data-bundle` proposal S3 and design D7, D8 and D9)

## Context
ADR 0008 routes realtime fan-out through one `RealtimeBus` interface on Serverpod's message system, and requires every delivery to pass the privacy scope (ADR 0006). ADR 0012 leaves open how a worker isolate reaches the bus (R56). The first user of the bus is the static-data build-change announcement (`client-data-bundle`), which carries only public data, while the privacy scope does not exist yet.

## Decision
- **Typed, versioned topics:** the bus, declared in `kaname_core`, offers `publish<T>(Topic<T>, T)` and `subscribe<T>(Topic<T>)`. A `Topic<T>` has a name, a version and a visibility. Every message is a typed, versioned model of its topic; a subscriber receives only its topic's messages, and a message of an unknown version is logged and dropped, never delivered.
- **Public or scoped (C4):** every topic is declared `public` or `scoped`, and every delivery to a client stream passes its topic's delivery scope, as ADR 0008 requires. A public topic carries only public, non-character data, and its scope passes every message. A scoped topic is refused for client streams until the privacy scope exists (ADR 0006); from then on every delivery must pass it. No topic bypasses the scope; a bypass is what ADR 0006's architecture test must catch.
- **Only the main isolate publishes:** a worker's change reaches the bus as a typed worker reply that the main isolate turns into a message (ADR 0009). This settles the bus part of R56 for now; ADR 0012's other open items stay open.
- **Local delivery first (C21):** the server bus posts Serverpod messages with local scope, delivered to every subscriber in the same process, while 1.0 runs one server instance (ADR 0001). A second server instance is the trigger to deliver through Redis. This does not make Redis optional: deployments still run Redis as ADR 0001 requires, and ADR 0008's rejection of a bus that works without Redis stands for multi-instance delivery.
- **Wake-ups, not snapshots:** a client stream that serves a state (such as the announced bundle) treats bus messages as wake-ups and sends the state current at the moment it writes, so a late message never resends a replaced value.

## Consequences
- Every later realtime feature declares its topic's visibility and version, and passes through the same delivery-scope rule.
- The static-data topic is public; character data waits for the privacy scope.
- Moving to Redis delivery changes only the server implementation behind the interface.
- **Rejected:**
  - Redis delivery now: 1.0 runs one instance.
  - A stream fed straight from the publisher with no bus: ADR 0008 routes fan-out through the bus.
  - Letting public topics bypass the scope, or a superseding ADR with a public-topic exception: a bypass is what the privacy architecture test must catch.
- **Reversal cost:** medium. Every later realtime feature uses the interface.
