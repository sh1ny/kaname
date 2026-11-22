# static-data-builds Specification

## Purpose
Defines the lifecycle of stored SDE builds after import: which build readers use, how the server switches to a new build and back without a restart, what changed between two builds, and how the server finds new builds each day.

## Requirements

### Requirement: Stored builds have one of three states
Each stored build SHALL be `active`, `previous` or `staged`. At rest the server SHALL hold at most one build in each state, and at most one active build at any moment. While an import runs, at most three builds SHALL be stored, the one being imported included.

#### Scenario: After a switch
- **WHEN** build N is active, no build is previous, and the server switches to build N+1
- **THEN** build N+1 is active, build N is previous, and no other build is stored

#### Scenario: Import while active, previous and staged builds exist
- **WHEN** builds N (active), N-1 (previous) and M (staged) are stored and an import of build N+1 starts
- **THEN** build M's rows are gone before the import writes its first row, and at no moment are more than three builds stored

### Requirement: A newer build is switched to after its import
When an import of a build newer than the active build succeeds, and that build is not held, the server SHALL switch to it without a restart. In one atomic step the new build SHALL become active, the old active build SHALL become previous, and the old previous build SHALL be removed with its rows.

#### Scenario: Daily build arrives
- **WHEN** build N is active, build N-1 is previous, and an import of build N+1 succeeds
- **THEN** build N+1 is active, build N is previous, build N-1 and its rows are gone, and the server process kept running

#### Scenario: Switch fails
- **WHEN** an import of build N+1 succeeds and a statement of the switch then fails while Postgres stays reachable
- **THEN** build N is still active with its rows, build N+1 is staged, a failed switch record holds the reason, and the next check retries the switch without importing again

#### Scenario: Older build imported
- **WHEN** an import of a build older than the active build succeeds
- **THEN** the build stays staged and no switch happens

### Requirement: A request reads one build from start to end
Server-side static-data reads SHALL go through a reader that fixes the active build once, when the request starts, and reads only that build until the request ends. A switch during the request SHALL NOT change what the request reads.

#### Scenario: Switch during a request
- **WHEN** a request fixes build N, the server switches to build N+1, and the request then reads a type
- **THEN** the request reads build N's row of that type, and a request started after the switch reads build N+1's row

#### Scenario: Fixed build removed
- **WHEN** a request still holds build N after two later switches removed build N's rows
- **THEN** the read fails with error "build no longer stored" naming build N, and never returns rows of another build

#### Scenario: No active build
- **WHEN** a request starts while no build is active
- **THEN** the reader fails with error "no active build" and the request reads nothing

### Requirement: The previous build can be rolled back to
A rollback SHALL swap the active and previous builds in one atomic step, without a restart. It SHALL be started through a development task, and SHALL wait for no import, failing at once when one runs.

#### Scenario: Rollback
- **WHEN** build N+1 is active and build N is previous, and a rollback runs
- **THEN** build N is active and not held, build N+1 is previous and held, both keep their rows, and the rollback is recorded

#### Scenario: No previous build
- **WHEN** a rollback runs while no build is previous
- **THEN** it fails with reason "no previous build" and the active build stays active

#### Scenario: Import running
- **WHEN** a rollback runs while an import holds the static-data lock
- **THEN** it fails with reason "import running" and no build changes state

### Requirement: A rolled-back build is held
A rollback SHALL hold the build it rolled back from. The server SHALL NOT switch to a held build again, and SHALL lift the hold when it switches to a build newer than the held one.

#### Scenario: Daily check after a rollback
- **WHEN** build N+1 was rolled back from and CCP's latest build is still N+1
- **THEN** the check switches nothing and records outcome `held` naming build N+1

#### Scenario: Newer build after a rollback
- **WHEN** build N+1 is held and an import of build N+2 succeeds
- **THEN** the server switches to build N+2, the hold on build N+1 is lifted, and build N becomes previous

### Requirement: Each build switched to is compared with the build it replaces
Before a forward switch to a newer build, the server SHALL compare that build file by file with the active build and store the report, unless a report for that pair is already stored. A failed comparison SHALL be recorded with its reason and SHALL NOT stop the switch. A build that stays staged SHALL get no stored report.

#### Scenario: Changed build
- **WHEN** build N+1 adds two types, removes one and changes the volume of three, against active build N, and the server switches to it
- **THEN** the stored report for build N+1 against build N shows the types file with 2 added, 1 removed and 3 changed, those keys, and field `volume` changed in 3 records

#### Scenario: First build
- **WHEN** an import succeeds while no build is active
- **THEN** the build becomes active and no report is stored

#### Scenario: Build imported by the development task
- **WHEN** the development task imports build N+1 while build N is active
- **THEN** build N+1 is staged with no stored report, and a report is stored when the server switches to it

#### Scenario: Comparison fails
- **WHEN** the comparison of build N+1 fails partway
- **THEN** no partial report is stored, the failure reason is recorded for build N+1, and the switch to build N+1 still happens

### Requirement: The diff report lists counts, keys and fields
For each file present in either build, a report SHALL hold the added, removed and changed record counts, and the keys of those records, up to 1,000 keys per file and kind. For a typed file it SHALL also hold each changed field with its record count. A new or removed file SHALL be listed as such.

#### Scenario: More than 1,000 changes in one file
- **WHEN** 5,000 records of the types file changed between two builds
- **THEN** the report shows 5,000 changed and lists 1,000 keys, marked as cut off

#### Scenario: File only in the new build
- **WHEN** build N+1 holds a file that build N does not
- **THEN** the report lists that file as new with all its records added

#### Scenario: Records that differ only in key order
- **WHEN** a record's JSON in two builds has the same fields and values in another order
- **THEN** the record is not counted as changed

### Requirement: Any two stored builds can be compared on demand
A development task SHALL compare any two stored builds and print the report, with the same content as a stored report. It SHALL store nothing.

#### Scenario: Compare active and previous
- **WHEN** the task compares builds N and N+1, both stored
- **THEN** it prints the same counts, keys and fields as the report stored for build N+1 against build N

#### Scenario: Build not stored
- **WHEN** the task names a build that is not stored
- **THEN** it exits with a non-zero code and the message "build not stored" naming the build

### Requirement: The server checks for a new build every day
In the monolith role and the development, staging or production run mode, the server SHALL check CCP's latest build number once a day at 12:00 UTC, after EVE's daily downtime. On start it SHALL also check when no build is active, or when no check has started since the most recent 12:00 UTC. A check SHALL import and switch to the latest build when it is newer than the active build and not held.

#### Scenario: New build found
- **WHEN** the daily check runs, build N is active and CCP's latest build is N+1
- **THEN** build N+1 is imported, compared with build N and switched to, and the check is recorded with outcome `switched`

#### Scenario: No new build
- **WHEN** the daily check runs and CCP's latest build is the active build
- **THEN** nothing is imported and the check is recorded with outcome `up to date`

#### Scenario: CCP unreachable
- **WHEN** the daily check runs and CCP cannot be reached
- **THEN** the active build stays active, the check is recorded with outcome `failed` naming CCP as unreachable, and the next day's check runs as usual

#### Scenario: Start after a long stop
- **WHEN** the server starts and its last check was 30 hours ago
- **THEN** a check runs during start-up, the server answers requests while it runs, and the 12:00 UTC check stays scheduled

#### Scenario: Restart across 12:00 UTC
- **WHEN** the last check started yesterday at 12:20 UTC, and the server stops at 11:58 UTC and starts again at 12:05 UTC
- **THEN** a check runs during start-up

#### Scenario: Restart after today's check
- **WHEN** a check started today at 12:00 UTC and the server restarts at 15:00 UTC
- **THEN** no check runs at start, and exactly one daily check stays scheduled

#### Scenario: Test run mode or migration step
- **WHEN** the server starts in the test run mode or as the maintenance migration step
- **THEN** no check is scheduled and no request goes to CCP

### Requirement: Every check, switch and rollback is recorded
Each check SHALL leave a record with its time, the latest build CCP named when known, and its outcome: `up to date`, `switched`, `held`, `older`, `staged` (imported but not switched) or `failed` with its reason. Each switch and rollback SHALL record its time, the builds involved and its outcome. Records SHALL hold no credentials.

#### Scenario: CCP names an older build
- **WHEN** a check runs, build N is active and CCP's latest build is N-1
- **THEN** nothing is imported and the check is recorded with outcome `older` naming build N-1

#### Scenario: Check while an import runs
- **WHEN** a check starts while another import holds the static-data lock
- **THEN** the check imports nothing and is recorded with outcome `failed` and reason "import already running"

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
