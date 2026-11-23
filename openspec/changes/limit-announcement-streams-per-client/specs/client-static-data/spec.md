## MODIFIED Requirements

### Requirement: The app follows the announced bundle while connected
With a server address, the app SHALL subscribe to the build-change stream when it starts. When the stream ends or fails it SHALL subscribe again after 5 seconds, doubling to at most 5 minutes, and at once when the user checks the server again. When the announced bundle is not the one it holds, it SHALL download that bundle once. Within one server epoch it SHALL ignore an announcement whose revision is not higher than the last one it took.

#### Scenario: Start with an old bundle
- **WHEN** the app starts holding build N's bundle and the stream announces build N+1
- **THEN** the app downloads build N+1's bundle once

#### Scenario: Same bundle announced
- **WHEN** the stream announces the bundle the app already holds
- **THEN** the app downloads nothing

#### Scenario: Stream drops
- **WHEN** the build-change stream fails twice in a row
- **THEN** the app subscribes again 5 seconds after the first failure and 10 seconds after the second

#### Scenario: No bundle announced
- **WHEN** the app holds build N's bundle and the stream announces that no bundle is available
- **THEN** the app keeps build N's bundle in use and downloads nothing

#### Scenario: Stale announcement
- **WHEN** the app took revision 5 of an epoch and an announcement with revision 4 of the same epoch arrives
- **THEN** the app ignores it

#### Scenario: Server has no bundle yet
- **WHEN** the app holds no bundle and the stream announces that no bundle is available
- **THEN** the app downloads nothing and its reason is "server has no bundle yet"

#### Scenario: No server configured
- **WHEN** a desktop or mobile build has no server address
- **THEN** the app subscribes to nothing, downloads nothing and keeps any bundle it holds

#### Scenario: Server refuses the subscription
- **WHEN** the app holds build N's bundle and the server refuses its subscription by ending the stream without an event, twice in a row
- **THEN** the app keeps build N's bundle in use, subscribes again 5 seconds after the first refusal and 10 seconds after the second, and sends no other request to learn the announced build
