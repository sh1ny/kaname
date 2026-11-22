# Spec Delta

## ADDED Requirements

### Requirement: Build changes are announced to apps
When the announced bundle changes (a switch, a rollback, or a missing active bundle built), the server SHALL publish it on the static-data topic of the realtime bus: at once, after loading its bytes, for changes made in the server, and for changes made by another process (such as rollback) by the first refresh that starts after the change and succeeds; refreshes SHALL run one at a time and be attempted every 60 seconds. A failure to publish SHALL be logged and SHALL NOT undo the change.

#### Scenario: Switch announced
- **WHEN** the server switches from build N to build N+1 and build N+1's bundle is stored
- **THEN** one build-change message naming build N+1 is published

#### Scenario: Rollback announced
- **WHEN** a rollback makes build N active again, build N's bundle is stored in the current format and is not the bundle already announced
- **THEN** one build-change message naming build N is published by the first refresh that starts after the rollback and succeeds, having read the state and loaded build N's bytes, with no bundle build

#### Scenario: Rollback during a slow refresh
- **WHEN** a refresh holding build B's preload is still running at the next tick, and a rollback to build A has committed
- **THEN** a refresh queued by that tick starts after the running one's database work has ended, and build A is published by it, or by the first later refresh that succeeds

#### Scenario: Byte load fails
- **WHEN** loading build N+1's bundle bytes fails or misses the refresh deadline before it is announced
- **THEN** the previous announcement stays, and build N+1 is announced by a later refresh that loads its bytes

#### Scenario: Late bundle
- **WHEN** build N+1 became active without a bundle and a later build check builds it
- **THEN** a build-change message naming build N+1 is published after the bundle is stored

#### Scenario: Publish fails
- **WHEN** publishing the build-change message fails after a switch
- **THEN** the failure is logged, build N+1 stays active, and apps learn of it when their stream next subscribes
