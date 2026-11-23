# Spec Delta

## ADDED Requirements

### Requirement: Auto-update is on until an admin turns it off
The server SHALL treat auto-update as on when no setting is stored, and SHALL read the setting once at the start of each check, after the check holds the static-data lock. Auto-update SHALL govern only switching away from an active build: the first build a server imports SHALL become active whatever the setting.

#### Scenario: Fresh install
- **WHEN** no auto-update setting has ever been stored and the daily check finds a newer build
- **THEN** the check imports and switches to it

#### Scenario: First build with auto-update off
- **WHEN** no build is stored, an admin has turned auto-update off, and the start-up check imports build N
- **THEN** build N becomes active and the check is recorded with outcome `switched`

#### Scenario: Daily check recorded
- **WHEN** the 12:00 UTC check runs
- **THEN** its record names `daily`

#### Scenario: Start-up check recorded
- **WHEN** a check runs during start-up
- **THEN** its record names `start`

#### Scenario: Records from before this change
- **WHEN** check records stored before the trigger existed are read
- **THEN** each names `daily`

#### Scenario: Update now recorded
- **WHEN** an admin's update now runs a check that ends `switched`
- **THEN** the check record names `update now` and outcome `switched`

#### Scenario: Update now refused
- **WHEN** an admin's update now is refused because an import is running
- **THEN** the number of check records naming `update now` is unchanged

### Requirement: Switch and rollback records follow their outcome
A committed switch or rollback SHALL store its succeeded record, with its time and builds, in its own transaction. A confirmed failure SHALL attempt a failed record, which MAY be missing when storing it fails. An outcome the server cannot confirm SHALL write no failed record; if it committed, its succeeded record committed with it.

#### Scenario: Committed switch recorded
- **WHEN** a switch from build N to build N+1 commits
- **THEN** its succeeded switch record naming both builds is stored in the same transaction

#### Scenario: Failed record cannot be stored
- **WHEN** a rollback's statement fails with a server error before `COMMIT` on a live connection, and storing its failed record fails too
- **THEN** no rollback record is stored, the failure is logged, and the job outcome says "rollback failed"

#### Scenario: Development rollback with unknown commit
- **WHEN** the development rollback task loses its connection, or gets an error from `COMMIT`, so its commit result cannot be established
- **THEN** it reports "outcome unknown" and writes no failed rollback record

#### Scenario: Outcome unknown
- **WHEN** a switch's commit acknowledgement is lost and the server cannot read whether it committed
- **THEN** no failed switch record is written; the succeeded record exists exactly when the switch committed, and the outcome is settled from the operation row or recorded as "switch outcome unknown"

## MODIFIED Requirements

### Requirement: Each build switched to is compared with the build it replaces
Before a forward switch to a newer build, the server SHALL compare that build file by file with the active build and store the report, unless a successful one is stored; an update now restoring a held build SHALL also compare again a pair whose comparison failed. A failed comparison SHALL be recorded with its reason, as far as storing succeeds, and SHALL NOT stop the switch. A build staged after its comparison (switch failed or not reached) SHALL keep it; other staged builds SHALL get none.

#### Scenario: Changed build
- **WHEN** build N+1 adds two types, removes one and changes the volume of three, against active build N, and the server switches to it
- **THEN** the stored report for build N+1 against build N shows the types file with 2 added, 1 removed and 3 changed, those keys, and field `volume` changed in 3 records

#### Scenario: First build
- **WHEN** an import succeeds while no build is active
- **THEN** the build becomes active and no report is stored

#### Scenario: Build imported by the development task
- **WHEN** the development task imports build N+1 while build N is active, with auto-update on
- **THEN** build N+1 is staged with no stored report, and a report is stored when the server switches to it

#### Scenario: Comparison fails
- **WHEN** the comparison of build N+1 fails partway and storing its `failed` row succeeds
- **THEN** no partial report is stored, the `failed` row holds the reason for build N+1, and the switch to build N+1 still happens

#### Scenario: Report lookup fails
- **WHEN** reading the stored report of the pair throws on a connection that still holds the lock, before build N+1's comparison
- **THEN** the lookup failure is logged, the switch to build N+1 still happens, and the report is treated as a failed comparison

#### Scenario: Comparison fails and its row cannot be stored
- **WHEN** the comparison of build N+1 fails partway and storing its `failed` row fails too
- **THEN** the switch to build N+1 still happens, no report row of the pair is stored, and the failed store is logged at warning level

#### Scenario: Switch fails after the comparison
- **WHEN** a successful report for build N+1 against build N is stored and the switch to build N+1 then fails
- **THEN** build N+1 stays staged with its stored report, and the retried switch compares nothing again

#### Scenario: Failed comparison, then failed switch
- **WHEN** the comparison of build N+1 against build N failed and was stored as failed, the switch then fails, and the switch is retried
- **THEN** the retry compares the pair again before switching

#### Scenario: Worker stops after the comparison
- **WHEN** a successful report for build N+1 against build N is stored and the compute worker stops before the switch transaction
- **THEN** build N+1 stays staged with its stored report and no failed switch record, and the next eligible check switches to it without importing or comparing again

#### Scenario: Compared again before a restore
- **WHEN** build N+1 is held, the stored comparison of N+1 against N failed, and an update now restores build N+1
- **THEN** the pair is compared again before the swap

### Requirement: A request reads one build from start to end
Server-side reads of static-data contents SHALL go through a reader that fixes the active build once, when the request starts, and reads only that build until the request ends. A switch during the request SHALL NOT change what the request reads. Reads of build metadata (build states, records, reports and admin jobs) for the status, change-report and operation calls are not content reads: they use one committed snapshot instead.

#### Scenario: Switch during a request
- **WHEN** a request fixes build N, the server switches to build N+1, and the request then reads a type
- **THEN** the request reads build N's row of that type, and a request started after the switch reads build N+1's row

#### Scenario: Fixed build removed
- **WHEN** a request still holds build N after two later switches removed build N's rows
- **THEN** the read fails with error "build no longer stored" naming build N, and never returns rows of another build

#### Scenario: No active build
- **WHEN** a request starts while no build is active
- **THEN** the reader fails with error "no active build" and the request reads nothing

#### Scenario: Status on a fresh install
- **WHEN** no build is active and a status call runs
- **THEN** the status call succeeds from its snapshot, without the content reader

### Requirement: Build changes are announced to apps
When the announced bundle changes (switch, rollback, or missing bundle built), the server SHALL publish it on the bus's static-data topic once its bytes load, if still current when a refresh reads it: at once for changes made in the server, settled admin jobs too, else by the first later refresh that succeeds. Refreshes run one at a time every 60 s; each finished check SHALL request one, and requests made during one join into one more. A failed publish SHALL be logged, not undo the change.

#### Scenario: Switch announced
- **WHEN** the server switches from build N to build N+1 and build N+1's bundle is stored
- **THEN** when a refresh then selects build N+1's bundle, loads its bytes and finds the announcement changed, one build-change message naming build N+1 is published

#### Scenario: Rollback announced
- **WHEN** a rollback makes build N active again, build N's bundle is stored in the current format and is not the bundle already announced
- **THEN** while build N stays active, one build-change message naming build N is published by the first refresh that starts after the rollback and succeeds, having read the state and loaded build N's bytes, with no bundle build

#### Scenario: Rollback during a slow refresh
- **WHEN** a refresh holding build B's preload is still running at the next tick, and a rollback to build A has committed
- **THEN** a refresh queued by that tick starts after the running one's database work has ended, and, while build A stays active, build A is published by it, or by the first later refresh that succeeds

#### Scenario: Byte load fails
- **WHEN** loading build N+1's bundle bytes fails or misses the refresh deadline before it is announced
- **THEN** the previous announcement stays, and build N+1 is announced by a later refresh that still selects its bundle, loads its bytes and finds the announcement changed

#### Scenario: Late bundle
- **WHEN** build N+1 became active without a bundle and a later build check builds it
- **THEN** a refresh is requested, and, if build N+1 is still the bundle the refresh selects, a build-change message naming it is published once its bytes load

#### Scenario: Publish fails
- **WHEN** publishing the build-change message fails after a switch
- **THEN** the failure is logged, build N+1 stays active, and apps learn of it when their stream next subscribes

#### Scenario: Admin rollback announced
- **WHEN** an admin's rollback makes build N active again, build N's bundle is stored and is not the bundle already announced
- **THEN** a refresh is requested once the job is settled, and, if it selects build N's bundle and finds the announcement changed, one build-change message naming build N is published once its bytes load, without waiting for the next tick

#### Scenario: Change found when settling
- **WHEN** an admin update now's switch to build N+1 committed and its worker exited before replying
- **THEN** a refresh is requested once the job is settled, and it publishes build N+1 only if it selects build N+1's bundle, loads its bytes and finds the announcement changed

#### Scenario: Recovered change superseded
- **WHEN** update now X's switch to build N+1 is settled after its worker exited, build N+1 was never announced, and another admin's rollback to build N commits before the requested refresh runs
- **THEN** that refresh reads build N as current; if build N's bundle is the one already announced it publishes nothing, else it publishes build N, and either way X's job still answers `switched` naming build N+1

#### Scenario: Settled change already announced
- **WHEN** an admin job settles with changed builds, and the bundle current when the requested refresh runs is the one already announced
- **THEN** the refresh publishes no message, and the job's own outcome is still read from its stored row

#### Scenario: Update now repairs the bundle
- **WHEN** an admin's update now finds the active build up to date and builds its missing bundle
- **THEN** the finished check requests a refresh, and the bundle is announced by the first refresh after it that still selects it and loads its bytes

### Requirement: A newer build is switched to after its import
When a build check's import of a build newer than the active build succeeds, or the check reuses such a staged build, the server SHALL switch to it without a restart if auto-update is on and the build is not held, or if an admin's update now started the check. In one atomic step the new build SHALL become active, the old active build SHALL become previous, and the old previous build SHALL be removed with its rows. Otherwise the build SHALL stay staged.

#### Scenario: Daily build arrives
- **WHEN** auto-update is on, build N is active, build N-1 is previous, and the daily check's import of build N+1 succeeds
- **THEN** build N+1 is active, build N is previous, build N-1 and its rows are gone, and the server process kept running

#### Scenario: Switch fails
- **WHEN** an import of build N+1 succeeds and a statement of the switch then fails while Postgres stays reachable
- **THEN** build N is still active with its rows, build N+1 is staged, a failed switch record holds the reason when its own write succeeds, and the next check retries the switch without importing again

#### Scenario: Older build imported
- **WHEN** an import of a build older than the active build succeeds
- **THEN** the build stays staged and no switch happens

#### Scenario: Auto-update off
- **WHEN** auto-update is off and the daily check's import of build N+1 succeeds while build N is active
- **THEN** build N+1 is staged, build N stays active, and the check is recorded with outcome `staged`

#### Scenario: Update now with a staged build
- **WHEN** auto-update is off, build N+1 is staged, CCP's latest is N+1 and an admin's update now runs
- **THEN** the check switches to build N+1 without importing it again, and build N becomes previous

### Requirement: The server checks for a new build every day
In the monolith role and the development, staging or production run mode, the server SHALL attempt a check of CCP's latest build number once a day at 12:00 UTC, after EVE's daily downtime, sending none while the previous daily request is unanswered. On start it SHALL also check when no build is active, or when no check has started since the most recent 12:00 UTC. A check SHALL import the latest build when newer than the active build and not held, and switch as the switch requirement says.

#### Scenario: New build found
- **WHEN** auto-update is on, the daily check runs, build N is active and CCP's latest build is N+1
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

#### Scenario: Start-up fails once on a fresh install
- **WHEN** the server starts with no stored build, its start-up sweep fails because Postgres does not answer, and Postgres answers 40 seconds later
- **THEN** a later start-up pass sweeps, schedules exactly one daily check and runs the check that imports CCP's latest build

#### Scenario: Worker exits before the start-up check is sent
- **WHEN** the server starts with no stored build, the worker becomes ready and then exits before the start-up check request is sent
- **THEN** that pass sends nothing and is retried 30 seconds later, and once a worker runs the check is sent and imports CCP's latest build

#### Scenario: Start-up check not entered with an active build
- **WHEN** build N is active, the last check started yesterday, and today's start-up catch-up check reaches the worker but the worker fails before running the job
- **THEN** the pass is retried 30 seconds later and its catch-up check goes to CCP, not only a bundle repair

#### Scenario: Start-up retry crosses 12:00 UTC
- **WHEN** the last check started yesterday, a start-up pass schedules the daily check and fails before its catch-up decision, and the daily check is sent at 12:00 UTC, has reached its CCP lookup and still runs when the retry decides
- **THEN** the retry sends no catch-up check while the daily request is unanswered, and once it replies having asked CCP the retry still sends none, only one check goes to CCP, and the retry goes on to its repair dispatch

#### Scenario: Pending daily check fails before entry
- **WHEN** build N is active, the last check started yesterday, the daily request was sent at 12:00 UTC and has not entered its job when the start-up pass decides, and it then fails before entry
- **THEN** the pass sends no duplicate check and no repair while the daily request is pending, and is retried once the daily request fails, so a check goes to CCP

#### Scenario: Repair could win the lock from a pending daily check
- **WHEN** build N is active with its bundle missing, the last check started yesterday, and the daily request is sent at 12:00 UTC but has not yet reached the CCP lookup when the start-up pass decides
- **THEN** the pass sends its repair only after the daily check replied, so exactly one check asks CCP, and an "import already running" record never counts as a started check

#### Scenario: Worker exits before the start-up check enters
- **WHEN** the start-up catch-up check is sent and the worker exits before the job is entered
- **THEN** the pass is retried 30 seconds later and its check goes to CCP once a worker runs

#### Scenario: Restart after a check that failed before its lookup
- **WHEN** build N is active, the last check started yesterday, today's check failed in its stale-import sweep before asking CCP and stored a `failed` record, and the server restarts
- **THEN** that record does not count as a started check, and the start-up catch-up check goes to CCP

#### Scenario: Restart after a check that crossed 12:00 UTC
- **WHEN** build N is active, today's daily check entered its job at 11:59:59 UTC and began its CCP lookup at 12:00:01 UTC, and the server restarts at 13:00 UTC
- **THEN** that check counts for today and no catch-up check runs at start

#### Scenario: Pending daily check never replies
- **WHEN** the start-up pass waits on a daily request that never replies, while the worker stays alive
- **THEN** after 30 minutes the status says worker stuck, the announcer's tick repairs are released, no duplicate check is sent, and a server restart recovers

#### Scenario: Valid lookup hidden behind a newer failed row
- **WHEN** build N is active, today's daily check began its CCP lookup at 12:00 UTC, a later check today failed before its lookup and stored a newer record, and the server restarts
- **THEN** the earlier lookup counts for today and no catch-up check runs at start

#### Scenario: Start-up catch-up check never replies
- **WHEN** the start-up pass sends its catch-up check and the worker, alive, never replies
- **THEN** after 30 minutes the status says worker stuck and the announcer's tick repairs are released, and no duplicate check is sent

#### Scenario: Start-up sweep never returns
- **WHEN** the server starts and its start-up sweep's database call never completes
- **THEN** after 60 seconds the status says start-up stuck and the announcer's tick repairs are released, no second pass starts while it is outstanding, and a server restart recovers

#### Scenario: Repair fails after the pending daily check began
- **WHEN** the start-up pass waits on a pending daily check, that check replies having asked CCP, and the repair the pass then sends answers that the worker could not open its store
- **THEN** the pass is retried 30 seconds later and does not end on that repair

#### Scenario: Daily check never replies
- **WHEN** start-up has ended, a daily check request never replies, and the next day's 12:00 UTC run arrives while it is still unanswered
- **THEN** after 30 minutes the status says worker stuck, and the next day's run sends no request and logs that the previous check is still pending

#### Scenario: Pending check replies with no stored record
- **WHEN** the last stored check is from yesterday, a pending daily check replies after 12:00 UTC and its record write failed, and the pass decides from that reply
- **THEN** a reply whose lookup began at 12:00:05 UTC counts for today and no catch-up check is sent, and a reply whose lookup began at 11:59:55 UTC does not count and the pass sends a catch-up check

#### Scenario: Restart after today's check
- **WHEN** a check started today at 12:00 UTC and the server restarts at 15:00 UTC
- **THEN** no check runs at start, and exactly one daily check stays scheduled

#### Scenario: Test run mode or migration step
- **WHEN** the server starts in the test run mode or as the maintenance migration step
- **THEN** no check is scheduled and no request goes to CCP

#### Scenario: New build found with auto-update off
- **WHEN** auto-update is off, the daily check runs, build N is active and CCP's latest build is N+1
- **THEN** build N+1 is imported and staged, no report is stored, build N stays active, and the check is recorded with outcome `staged`

### Requirement: The previous build can be rolled back to
A rollback SHALL swap the active and previous builds in one atomic step, without a restart. It SHALL be started through a development task or an admin's roll back call, and SHALL wait for no import, failing at once when one runs.

#### Scenario: Rollback
- **WHEN** build N+1 is active and build N is previous, and a rollback runs
- **THEN** build N is active and not held, build N+1 is previous and held, both keep their rows, and the rollback is recorded

#### Scenario: No previous build
- **WHEN** a rollback runs while no build is previous
- **THEN** it fails with reason "no previous build" and the active build stays active

#### Scenario: Import running
- **WHEN** a rollback runs while an import holds the static-data lock
- **THEN** it fails with reason "import running" and no build changes state

#### Scenario: Rollback from the app
- **WHEN** an admin's roll back call runs while build N+1 is active and build N is previous
- **THEN** the outcome and the records are the same as the development task's rollback

### Requirement: A rolled-back build is held
A rollback SHALL hold the build it rolled back from. The daily and start-up checks SHALL NOT switch to a held build again. The server SHALL lift the hold when it switches to a build newer than the held one, or when an admin's update now switches to the held build; before that swap it SHALL compare the pair again when their report is missing or failed, and a failed comparison SHALL NOT stop the swap.

#### Scenario: Daily check after a rollback
- **WHEN** build N+1 was rolled back from and CCP's latest build is still N+1
- **THEN** the check switches nothing and records outcome `held` naming build N+1

#### Scenario: Newer build after a rollback
- **WHEN** auto-update is on, build N+1 is held and the daily check's import of build N+2 succeeds
- **THEN** the server switches to build N+2, the hold on build N+1 is lifted, and build N becomes previous

#### Scenario: Update now on the held build
- **WHEN** build N is active, build N+1 is previous and held, CCP's latest is N+1, and an admin's update now runs
- **THEN** build N+1 is active and not held, build N is previous, and the check is recorded with outcome `switched`

#### Scenario: Update now on the held build with no report
- **WHEN** build N is active, build N+1 is previous and held, no report is stored for them, and an admin's update now switches to build N+1
- **THEN** the pair is compared again before the swap; if the comparison fails the swap still happens, and a `failed` report row is stored as far as storing it succeeds

#### Scenario: Held build's bundle bytes corrupt
- **WHEN** an update now restores held build N+1 whose bundle metadata is current but whose stored bytes do not match its SHA-256
- **THEN** the bundle is rebuilt under the lock before the swap; when the rebuild succeeds the swap happens, and when it fails the job ends "update failed" with the bundle's public reason and the pair, the hold and the revision are unchanged

#### Scenario: Recompare failure not stored on the held build
- **WHEN** the recompare before that swap fails and storing its `failed` row fails too
- **THEN** the swap still happens, the change report answers "report missing" when no row of the pair survives, and the next update now on that held pair compares it again

### Requirement: Every check, switch and rollback is recorded
Each check SHALL leave a record with its time, CCP's latest build when known, and its outcome: `up to date`, `switched`, `held`, `older`, `staged` (not switched) or `failed` with its reason. An update now refused before the lock SHALL leave none. A check record that cannot be stored MAY be missing; switch records and job outcomes stay authoritative. Switch and rollback records SHALL follow their outcome, as required below. Records SHALL hold no credentials.

#### Scenario: Failure after CCP answered
- **WHEN** a check learns that CCP's latest build is N+1 and then fails reading the stored builds
- **THEN** its `failed` record carries build N+1, and the status shows CCP's latest as N+1 from that check

#### Scenario: Held build below the active one
- **WHEN** two rollbacks leave build N+1 active and build N held as previous, and an admin's update now finds CCP's latest is build N
- **THEN** the check is recorded `older`, nothing switches, and the active, previous and held builds and the revision are unchanged

#### Scenario: Restore statement fails
- **WHEN** an update now restores held build N, its bundle is ready, and a statement of the swap fails on a connection that still holds the lock
- **THEN** the job ends "update failed" with that statement's public reason, build N stays previous and held, the revision is unchanged, and a failed switch record is stored when its own write succeeds

#### Scenario: CCP names an older build
- **WHEN** a check runs, build N is active and CCP's latest build is N-1
- **THEN** nothing is imported and the check is recorded with outcome `older` naming build N-1

#### Scenario: Check while an import runs
- **WHEN** a daily or start-up check starts while another import holds the static-data lock
- **THEN** the check imports nothing and is recorded with outcome `failed` and reason "import already running"

#### Scenario: Update now refused before start
- **WHEN** an admin's update now finds the static-data lock held
- **THEN** the number of check records is unchanged by it

#### Scenario: Worker stops after a switch commits
- **WHEN** an update now's switch to build N+1 commits and the compute worker stops before the check record is written
- **THEN** no check record is written for it, and the succeeded switch record and the admin job's `switched` outcome remain

#### Scenario: First activation acknowledgement lost
- **WHEN** the import transaction that makes build N active commits, the job's connection is lost before it learns so, and Postgres stays reachable
- **THEN** the import is recorded succeeded, and the check `switched` naming build N, never `failed`

#### Scenario: Staged import acknowledgement lost
- **WHEN** auto-update is off, build N is active, the import transaction that stores build N+1 as staged commits, and the job's connection is lost before it learns so
- **THEN** the import is recorded succeeded, the check `staged` naming build N+1, never `failed`, build N stays active and build N+1 is staged

#### Scenario: Check record not stored after a commit
- **WHEN** a daily check's switch to build N+1 commits, the worker stays up, and storing the check record fails
- **THEN** no check record is written for it, build N+1 stays active, the succeeded switch record remains, and the failure is logged

#### Scenario: Staged build promoted before reconciliation
- **WHEN** update now X's import of build N+1 commits as staged, its connection and lock are lost before it learns so, and another job switches to build N+1 before X reads the import record
- **THEN** X ends "update failed" with the reason "connection lost", never `switched`, and the other job's switch keeps its own records

#### Scenario: Held build without a current bundle
- **WHEN** an admin's update now restores held build N+1, whose bundle is missing or in an old format
- **THEN** the job builds N+1's bundle under the lock before the swap, and if that fails ends "update failed" and swaps nothing

#### Scenario: Daily switch with its connection lost
- **WHEN** a daily check's switch to build N+1 throws because its connection was lost, and another job may since have changed the builds
- **THEN** the check is recorded `failed` with reason "switch outcome unknown", no failed switch record is written, and the next refresh announces the bundle it selects (the active build's, else the previous one's), if that differs from the one already announced and its bytes load

#### Scenario: First activation aborted and swept
- **WHEN** the import transaction that makes build N active aborts, the job's connection is lost, and a sweep marks its import record failed before the job reads it
- **THEN** the check is recorded `failed`, never `switched`, and no build is active

#### Scenario: First activation cannot be confirmed
- **WHEN** the import transaction that makes build N active fails, it did not commit, and the job cannot then read whether it did
- **THEN** the check is recorded `failed` with reason "import outcome unknown" as far as storing it succeeds, and the import record stays running until a sweep marks it failed
