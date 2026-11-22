# realtime-bus Specification

## Purpose
Defines the realtime bus that carries server events to subscribers, and the build-change stream through which apps learn which static-data bundle is current.

## Requirements

### Requirement: Bus messages are typed per topic
Every message on the bus SHALL be a typed, versioned model of the topic it is published on. A subscriber SHALL receive only messages of the topic it subscribed to, and a message of an unknown version SHALL be dropped and logged, never delivered.

#### Scenario: Subscriber gets its topic
- **WHEN** a subscriber listens to the static-data topic and a static-data message is published
- **THEN** that subscriber receives the message once, as the typed model

#### Scenario: Unknown version
- **WHEN** a message with a version the receiver does not know arrives on a topic
- **THEN** it is logged with its topic and version, no subscriber receives it, and later messages are still delivered

### Requirement: The bus delivers within one server instance
The bus SHALL deliver each message to every subscriber in the same server process. Only the main isolate SHALL publish; a change a worker isolate reports reaches the bus through the main isolate. Delivery across server instances is not part of this capability.

#### Scenario: Worker publishes
- **WHEN** the compute worker reports a switch and the main isolate publishes the build change
- **THEN** every bus subscription in that process receives it, and every open build-change stream sends it or a newer announcement

#### Scenario: No subscribers
- **WHEN** a message is published while nothing subscribes to its topic
- **THEN** the message is dropped and publishing does not fail

### Requirement: Every delivery passes the delivery scope
A topic SHALL be declared public or scoped, and every delivery to a client stream SHALL pass the topic's scope. A public topic SHALL carry only public, non-character data, and its scope SHALL pass every message. The static-data topic SHALL be public. A scoped topic SHALL NOT be delivered to a client stream until the privacy scope exists to filter it.

#### Scenario: Public topic
- **WHEN** a build-change message is published on the public static-data topic
- **THEN** it passes the public scope and reaches every open client stream, which sends it or a newer announcement

#### Scenario: Scoped topic without a privacy scope
- **WHEN** a client stream subscribes to a topic declared scoped
- **THEN** the subscription is refused with reason "topic needs the privacy scope"

### Requirement: Apps learn the current bundle from one stream
The server SHALL offer an unauthenticated stream that first sends, within 20 seconds of subscribing, a limit kept below the generated client's idle timeout, the bundle last made downloadable (build, size and SHA-256), then an event when it changes; changes between two reads of the server's state MAY be merged. The announced bundle SHALL be the active build's built bundle in the current format, else the previous build's, else none, which the event SHALL say.

#### Scenario: Subscribe
- **WHEN** an app subscribes while build N is active and its bundle has been announced
- **THEN** the first event names build N with its size and SHA-256

#### Scenario: Subscribe before a switch is announced
- **WHEN** the switch to build N+1 has committed but the server has not yet loaded N+1's bundle, and an app subscribes
- **THEN** the first event names build N, and an event naming build N+1 follows once its bundle can be downloaded

#### Scenario: First read held at start
- **WHEN** the server starts, its first state read is held for 3 minutes, and an app subscribes through the generated client
- **THEN** every subscription's first event arrives within 20 seconds of subscribing, each subscription opened while the read is held first says no bundle is available, the app resubscribes whenever a stream ends, no second state read starts until the held one ends, the held read's result is never published, and the app receives an event naming the active build from the fresh read that follows

#### Scenario: Switch while subscribed
- **WHEN** an app is subscribed and the server switches to build N+1 whose bundle is stored, and nothing changes until the app receives an event
- **THEN** the app receives one event naming build N+1

#### Scenario: Active build without a bundle
- **WHEN** an app subscribes while the active build's bundle failed to build and the previous build has one
- **THEN** the first event names the previous build, and an event naming the active build follows once its bundle is built

#### Scenario: Old-format bundle after a rollback
- **WHEN** a server that builds format 2 has rolled back to a build whose stored bundle is format 1, and the previous build's bundle is format 2
- **THEN** the stream announces the previous build's format 2 bundle until the active build's bundle is rebuilt

#### Scenario: Nothing imported yet
- **WHEN** an app subscribes before any build is stored
- **THEN** the first event says no bundle is available

### Requirement: Announcements are ordered and bounded
Each announcement SHALL carry the server's epoch and a revision that rises with each change, and a stream SHALL never send a revision lower than or equal to one it already sent. The server SHALL hold at most 2,000 announcement streams, refusing more, SHALL end each after 30 minutes, and SHALL send each stream at most one event per change of the installed announcement. Each send SHALL carry the announcement installed when the stream hands it to Serverpod, never an earlier copy.

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
- **THEN** the server ends that stream and frees its place while the app still does not read, and a new subscription is admitted into that place

#### Scenario: Stream expiry
- **WHEN** a stream whose client keeps reading has been open for 30 minutes
- **THEN** the server ends it, frees its place and removes its bus listener, and a new subscription from that app is admitted and first receives the current announcement

#### Scenario: Stream limit
- **WHEN** 2,000 announcement streams are open and another app subscribes
- **THEN** that subscription is refused, the open streams keep working, and the health endpoint still answers in under 1 second
