# static-data-admin Specification

## Purpose

Defines public static-data status and how a signed-in user with server admin scope starts updates, rolls back builds, and changes auto-update.

## Requirements

### Requirement: Anyone can read the static-data status
The server SHALL answer a static-data status call without sign-in. It SHALL return the active, previous, staged and held builds, the build-state revision, CCP's latest build from the newest check that learned it, the newest check, import (with its build when known) and switch or rollback (each with time, outcome and public reason), file counts of at most 200 files of the last import, the auto-update setting, a busy flag and whether admin actions are configured.

#### Scenario: Server with two builds
- **WHEN** build N+1 is active, build N is previous, the newest check was `switched` at 12:00 UTC naming build N+1, and auto-update is on
- **THEN** the status names build N+1 active, build N previous, no staged or held build, CCP's latest as N+1, that check with its time and outcome, the import of N+1 with its file counts, the switch from N to N+1, auto-update on and not busy

#### Scenario: Fresh install
- **WHEN** no build is stored and no check has run
- **THEN** the status names no active, previous, staged or held build, revision 0, no CCP latest build and no check, import or switch, and the call succeeds

#### Scenario: Last check could not reach CCP
- **WHEN** the newest check failed because CCP was unreachable, and an earlier check named build N+1
- **THEN** the status shows the newest check as `failed` with the reason "CCP unreachable", and CCP's latest as N+1 from the earlier check with that check's time

#### Scenario: Many imported files
- **WHEN** the last import counted records in 260 files
- **THEN** the status holds the counts of 200 files, marked cut off, and the number of files

#### Scenario: Busy
- **WHEN** an import, check, rollback, bundle repair or the start-up sweep holds the static-data lock when a new status read takes its sample
- **THEN** that read's status says busy, and calls answered from it, joined or within 1 second after it, say busy too

#### Scenario: Postgres unreachable
- **WHEN** the status call runs while Postgres cannot be reached
- **THEN** the call fails with the error "status unavailable" and its answer holds no host name, port or exception text

#### Scenario: Busy held in another database
- **WHEN** another database on the same Postgres server holds an advisory lock with the static-data lock key and no static-data work runs here
- **THEN** the status says not busy

### Requirement: The status carries the setting revision and stuck indicators
The status SHALL carry the setting revision, `NoWrites` before the first committed setting write and otherwise the newest committed write's revision, apart from the build-state revision. It SHALL carry the worker-stuck, settlement-stuck, recovery-stuck and start-up-stuck indicators. Busy SHALL be sampled for the whole install; worker stuck SHALL be set while any watched worker request is stalled and cleared only per request, so both MAY be set at once.

#### Scenario: Setting revision on a fresh database
- **WHEN** no build and no setting write is stored
- **THEN** the status carries build-state revision 0 and the setting revision `NoWrites` as separate values, with auto-update on

#### Scenario: Setting revision after a write
- **WHEN** an admin's first auto-update write commits and the call answers
- **THEN** a successful status answer to a call arriving after that answer carries that write's revision or a newer one, and the build-state revision is unchanged

#### Scenario: Write acknowledgement delayed
- **WHEN** an auto-update write commits, its database acknowledgement is delayed 3 seconds, and a status call arrives during that delay
- **THEN** that call may carry the previous setting revision, and a successful status call arriving after the write's answer carries the new one or a newer one

#### Scenario: Setting commit in flight when the write answers
- **WHEN** an auto-update write's connection fails after its `COMMIT` was sent, the call answers "setting not confirmed", and the commit lands 2 seconds later
- **THEN** a status call arriving after the answer never joins or reuses the invalidated read: it gets a valid cached answer of the current generation at once, else joins a current-generation read in flight when a waiter place is free, else on a miss starts a read only when a waiter place and a status work token are both free, else fails at once with "status unavailable", and a successful answer may carry the previous revision until a read taken after the commit

#### Scenario: Long bundle build after the first activation
- **WHEN** update now X's first activation commits, ending X `switched`, and its job holds the lock for 6 minutes while it builds the bundle
- **THEN** the status says busy and not worker stuck, and the operation call for X answers ended `switched`

#### Scenario: Ended job released the lock without a reply
- **WHEN** admin job X's row has ended, its job backend holds no static-data lock, and no reply arrives for 5 minutes
- **THEN** the status says worker stuck

#### Scenario: Busy and worker stuck together
- **WHEN** admin job X's row has been `running` for 5 minutes while its own backend holds no static-data lock, and a daily check holds the lock
- **THEN** the status says busy and worker stuck

### Requirement: Status reads are shared and time-limited
The server SHALL share one status read per cache generation: a call SHALL join it, or reuse its answer for 1 second, only in the current generation, which each auto-update write SHALL renew. A call SHALL answer at the earlier of 5 seconds and the shared answer. The database SHALL end each data query at 1 second; a read SHALL dispatch no query 12 seconds after its start. At most 2 status reads SHALL be awaited at once; else a read SHALL fail at once with "status unavailable".

#### Scenario: First caller times out
- **WHEN** the first caller of a shared status read times out after 5 seconds, a second call joins the read at 6 seconds, and the read completes at 8 seconds
- **THEN** the second call gets the shared answer, which the read's own session produced, though the first call's RPC has ended

#### Scenario: Many callers
- **WHEN** 2,000 status calls arrive within one second and every read succeeds
- **THEN** the server reads the database for them at most twice, one read at a time, and any call arriving while 256 already wait on a read fails at once with "status unavailable"

#### Scenario: Many callers during an outage
- **WHEN** Postgres cannot be reached and 2,000 status calls arrive within one second
- **THEN** every call fails with "status unavailable", and the server tries the database at most twice

#### Scenario: Reply lost
- **WHEN** Postgres finishes a status statement and its reply never reaches the server
- **THEN** each caller fails with "status unavailable" 5 seconds after its own arrival or at the shared failure 12 seconds after the read started, whichever is first, the read sends no further statement, and a call arriving after the reused failure's second starts a new read only if a status work token is free, else fails at once with "status unavailable"

#### Scenario: Statement runs long
- **WHEN** a status data query would run on the database for 20 seconds
- **THEN** the database ends it after 1 second and the read's callers fail with "status unavailable"

#### Scenario: Session setup fails fast
- **WHEN** getting the status read's database session fails 3 seconds after the read started
- **THEN** every call joined to that read fails with "status unavailable" at 3 seconds

#### Scenario: Session setup hangs
- **WHEN** getting the status read's database session gets no answer for 20 seconds
- **THEN** each caller fails with "status unavailable" 5 seconds after its own arrival or at the shared failure 12 seconds after the read started, whichever is first; the reader dispatches none of its own queries after 12 seconds, and the read keeps its work token until Serverpod's session future completes

#### Scenario: Repeated lost replies
- **WHEN** two status reads in a row lose their replies and neither database session has yet completed
- **THEN** while both still hold their work tokens a third read is not started, calls fail at once with "status unavailable", and an unrelated database call of the server still completes

### Requirement: Status waiters are capped server-wide
The server SHALL let at most 256 status calls wait at once, across the current read and any invalidated read still answering its callers. A call SHALL take a place to join or start a read and release it when it answers or times out. A call arriving with every place taken, and no cached answer applying, SHALL fail at once with "status unavailable".

#### Scenario: Waiting calls during a stall
- **WHEN** Postgres stalls during a shared status read and 2,000 status calls arrive within one second
- **THEN** at most 256 calls wait on that read, the rest fail at once with "status unavailable", the waiting ones fail at their 5-second deadline, and an unrelated endpoint still answers

#### Scenario: Join while both tokens are held
- **WHEN** an invalidated read holds one status work token, a current-generation read in flight holds the other, and a call arrives with a waiter place free
- **THEN** the call joins the current read and gets its answer

#### Scenario: Cache hit with every waiter place taken
- **WHEN** 256 calls wait on reads and a call arrives within 1 second of a current-generation read's answer
- **THEN** the call gets that cached answer at once

#### Scenario: Waiting calls across an invalidation
- **WHEN** 255 status calls wait on a stalled read, an auto-update write invalidates it, one new call takes the last place and starts a new read, and another call arrives
- **THEN** that call fails at once with "status unavailable", and a call arriving after one of the 256 waiting calls answered or timed out is admitted

### Requirement: The status reads one consistent state
All rows one status, change-report or operation call returns SHALL come from one committed database snapshot. Builds, revision and report pair SHALL agree with each other; the newest check, import and switch are each the newest in that snapshot, and need not name the same build. The busy flag is a sampled reading taken at the start of the snapshot: work that starts after it is not shown.

#### Scenario: Switch commits during a status read
- **WHEN** a switch from build N to build N+1 commits while a status call is reading
- **THEN** the status names build N active with the revision before the switch, or build N+1 active with the revision after it, never a mix

#### Scenario: Switch commits during a report read
- **WHEN** the reports of N+1 against N and of N+2 against N+1 are both stored and under 8 MB, and a switch from build N+1 to build N+2 commits while a change-report call is reading
- **THEN** the call returns either the report of N+1 against N or the report of N+2 against N+1, never "no previous build"

#### Scenario: Import committed before its switch
- **WHEN** build N+1's import has committed and its switch has not, and the status is read
- **THEN** the status may name build N active beside the import of N+1, and the call succeeds

### Requirement: Public answers carry only public reasons
No status, change-report or admin answer SHALL hold a credential, a password, a file path, a URL, a host name, a port, a connection string or exception text. Every failure reason SHALL be one of a fixed public set. A stored reason outside that set SHALL be shown as "failed, see the server log", and its text SHALL stay in the database and the server log.

#### Scenario: Stored reason with a URL
- **WHEN** the newest check's stored reason contains a CCP URL and a socket address
- **THEN** the status shows the check's reason as "CCP unreachable" or "failed, see the server log", and no part of the answer contains the URL or the address

#### Scenario: Failed import with a path in its error
- **WHEN** the last import failed while reading a file under the server's scratch directory
- **THEN** the status shows the import as `failed` with a public reason, and no part of the answer contains the scratch directory's path

#### Scenario: Admin key set
- **WHEN** the old admin key variable remains set after upgrade and the configured server's public status is read
- **THEN** the answer's admin capability reflects the sign-in and admin configuration alone, without revealing the unused key, any credentials or the admin allowlist

### Requirement: Anyone can read the change report of the stored builds
The server SHALL answer a change-report request on `GET /static-data/report` without sign-in with the stored report between the active and the previous build, whichever was switched to: per file, the added, removed and changed counts, its keys with a cut-off mark, each changed field with its record count, and new or removed files. When none is stored it SHALL say why: no previous build, comparison failed with its public reason, report missing, or report too large.

#### Scenario: Report after a switch
- **WHEN** the server switched from build N to build N+1 and stored their report, which holds 300 keys and 20 changed fields in total
- **THEN** the call returns that report naming builds N and N+1, with the same counts, keys and fields the stored report holds

#### Scenario: First build only
- **WHEN** build N is active and no build is previous
- **THEN** the call returns no report, with the reason "no previous build"

#### Scenario: Comparison failed
- **WHEN** the comparison of build N+1 against build N failed, its `failed` report row was stored, and the server switched to build N+1
- **THEN** the call returns no report, with the reason "comparison failed" and that row's public reason

#### Scenario: Failed comparison not stored
- **WHEN** the comparison of build N+1 against build N failed, storing its `failed` row failed too, and no row of that pair is stored
- **THEN** the call returns no report, with the reason "report missing"

#### Scenario: Repeated failed recompares
- **WHEN** the held pair N+1 against N is recompared and fails on ten update now presses, each storing its `failed` row
- **THEN** the pair holds one row per direction, the newest, and the report call returns "comparison failed" with the newest row's public reason

#### Scenario: Upgraded pair with two rows
- **WHEN** a database from before this change holds, for the retained pair N+1 against N, an older `failed` row and a newer successful row in the same direction, and no comparison runs after the upgrade
- **THEN** after the migration the pair holds only the successful row, and the report call returns it; the deduplication and the `reportBytes` backfill run before the migration records its version, so a failure in either leaves the version unrecorded

#### Scenario: Older failed row survives
- **WHEN** the pair N+1 against N holds a `failed` row from an earlier comparison, and a later recompare failed and could not store its row
- **THEN** the call returns no report, with the reason "comparison failed" and the earlier row's public reason

#### Scenario: Report row missing
- **WHEN** build N+1 is active, build N is previous, and no report row of any outcome is stored for them
- **THEN** the call returns no report, with the reason "report missing"

#### Scenario: After a rollback
- **WHEN** a rollback made build N active again and build N+1 previous
- **THEN** the call returns the report stored for build N+1 against build N, naming it from build N to build N+1 with its added and removed lists unchanged and build N as active, and the status names the same report

#### Scenario: Import of another build
- **WHEN** build N is active and the newest import, of build N+1, failed
- **THEN** the status shows that import naming build N+1 with its outcome and reason

### Requirement: The change report answer is bounded
The server SHALL read a stored report only at a stored size of at most 8 MB, else answer "report too large". An answer SHALL hold at most 20,000 keys and 200 fields per file, mark lists cut or stored cut off, and keep counts complete. One read SHALL run and 4 wait, up to 5 s; others, or one with no free work token (of 2), SHALL fail at once: "report busy". The database SHALL end its data statement at 10 s; the slot SHALL free at the read's end or 12 s, after which no data statement is sent.

#### Scenario: Large patch
- **WHEN** the stored report holds 1,000 keys in each of three kinds for 40 files
- **THEN** the answer holds at most 20,000 keys, the cut lists are marked cut off, and each file's added, removed and changed counts equal the stored counts

#### Scenario: Small report
- **WHEN** the stored report holds 300 keys in total and none of its lists is marked cut off
- **THEN** the answer holds all 300 keys and no list is marked cut off

#### Scenario: List cut off when stored
- **WHEN** a stored list holds 1,000 keys and is marked cut off, and the whole report holds 1,500 keys
- **THEN** the answer holds those 1,000 keys and marks the list cut off

#### Scenario: Many changed fields
- **WHEN** a file's stored report names 350 changed fields
- **THEN** the answer holds 200 of them for that file, marked cut off, with the full number of changed fields

#### Scenario: Report too large
- **WHEN** the stored size of the report is larger than 8 MB
- **THEN** the call answers "report too large" with no file list, and the report's contents are not read

#### Scenario: Queue full
- **WHEN** one report read runs, 4 wait, and a sixth arrives
- **THEN** the sixth fails at once with "report busy"

#### Scenario: Wait runs out
- **WHEN** a report read runs for 6 seconds and a second one waits for it
- **THEN** the second fails with "report busy" after 5 seconds

#### Scenario: Slow database
- **WHEN** a report read's data statement has run for 10 seconds
- **THEN** the database cancels that statement, the call fails with "report busy", and the next report read starts once a report work token is free

#### Scenario: Connection lost during a read
- **WHEN** a report read's connection fails 2 seconds after its statement started
- **THEN** the call fails with "report busy", the read keeps its work token until 10 seconds after its statement was dispatched, and the next report read starts only if the other token is free

#### Scenario: Repeated connection losses
- **WHEN** two report reads in a row lose their connections 2 seconds after their statements started
- **THEN** while both still hold their work tokens a third report read is not started and fails at once with "report busy"

#### Scenario: Report reply lost
- **WHEN** a report statement's reply never reaches the server
- **THEN** the call fails with "report busy" 12 seconds after the read started, when its logical slot frees; the next report read starts only if a report work token is free, else it fails at once with "report busy"

#### Scenario: Failed row before a successful one
- **WHEN** the pair N+1 against N has a `failed` report row and a newer successful one
- **THEN** the call returns the successful report, once, and the same holds after a rollback makes build N active again

### Requirement: Report answers in flight are capped
The server SHALL serve the change report on the web route `GET /static-data/report` with at most 8 answers in flight. Each SHALL hold its place from admission, before the report read, until its body has been written, has failed or was cancelled, or 60 s after admission. A request that finds every place taken SHALL get 503 with `Retry-After: 10` and no read.

#### Scenario: Slow readers take every transfer place
- **WHEN** 8 report requests have been admitted and their clients read their bodies slowly, and a ninth request arrives
- **THEN** the ninth gets 503 with `Retry-After: 10` without a report read, and a later request is admitted once a body has been written, has failed or was cancelled, or 60 seconds after an admission

#### Scenario: Expired slow reader holds no report
- **WHEN** 8 slow readers pass their 60-second deadline without reading further, and 8 new report requests are then admitted and encoded
- **THEN** the expired transfers hold no encoded array, at most 8 encoded answers are held, and each expired body ends at its next chunk request with nothing more sent

#### Scenario: Reader stalls after the writer took a chunk
- **WHEN** a slow reader stalls after the HTTP writer has taken its first chunk, passes its deadline, and 8 replacement requests are then admitted
- **THEN** the stalled response holds at most that one 64 KB copied chunk, not its encoded answer, and at most 8 encoded answers are held

#### Scenario: Report served over the web route
- **WHEN** the deployed web app sends `GET /api/static-data/report`, or a native app configured with base `https://host/kaname/` sends `GET /kaname/static-data/report`, while a report is stored for the active and previous builds
- **THEN** the answer is 200 with `Cache-Control: no-store` and a body holding the typed report answer, and "report busy" is also a 200 body

### Requirement: Each admin job carries an operation id
Update now and roll back calls SHALL carry an operation id, an app-made UUID, else be refused as malformed. The server SHALL store each job under its id before the worker gets it, and run one at a time. A stored id SHALL start no job; once past the gate, admission and token checks it SHALL answer from its row, or be refused as malformed for another kind or revision; one whose id is being stored SHALL answer as a stored waiting job would. Ended jobs SHALL be kept 30 days, open ones always.

#### Scenario: Replay during start-up recovery
- **WHEN** the server restarts while ended job X is stored and start-up recovery has not committed, and the app resends X
- **THEN** the call answers "worker not running" and starts nothing; after recovery commits, a resend of X answers ended with X's stored outcome

#### Scenario: Another admin job running
- **WHEN** an update now or rollback started by an admin has not ended and an update now with a new operation id arrives
- **THEN** it answers "import running" without reaching the compute worker

#### Scenario: Repeat before the lock
- **WHEN** update now X has been sent to the worker but does not yet hold the static-data lock, and a call with id X arrives
- **THEN** it answers "no answer yet" and no second check runs

#### Scenario: Repeat while running
- **WHEN** update now X holds the lock and a call with id X arrives
- **THEN** it answers "started" and no second check runs

#### Scenario: Repeat of an ended job while another runs
- **WHEN** rollback X ended "rolled back", rollback Y is running, and a call with id X arrives
- **THEN** it answers "ended" with X's stored outcome "rolled back"

#### Scenario: Id reused for another action
- **WHEN** update now X is stored and a roll back call carries id X
- **THEN** the call is refused as malformed and nothing runs

#### Scenario: Two calls with one id at once
- **WHEN** two update now calls with id X arrive together, neither finds X stored, and the second arrives while the first holds the admin-job slot and stores X
- **THEN** the second call answers "no answer yet" at once and sends nothing to the worker, one check runs, and the operation call for X shows X's job

#### Scenario: Two lookups miss
- **WHEN** two rollback calls with id X and revision R both miss on lookup, and the first takes the admin-job slot before the second comes to claim it
- **THEN** the second looks up X once more: it answers from X's row when the row is there, else "outcome unknown", never "import running", and no second request reaches the worker; with revision R+1 instead it is refused as malformed

#### Scenario: Stale miss after the row moved on
- **WHEN** two update now calls with id X both miss on lookup, the first stores X and its job ends `up to date` before the second comes to claim the slot, which X still holds
- **THEN** the second looks up X once more and answers "ended" with `up to date`

#### Scenario: Rollback resent while it is being admitted
- **WHEN** rollback X with revision R is being admitted, not yet stored, and a second rollback call with id X and revision R arrives
- **THEN** the second call answers "outcome unknown" at once and no second request reaches the worker

#### Scenario: Same id with another revision while admitting
- **WHEN** rollback X with revision R is being admitted and a rollback call with id X and revision R+1 arrives
- **THEN** that call is refused as malformed and nothing runs

#### Scenario: Same id after the first job ended
- **WHEN** two update now calls with id X arrive together, neither finds X stored, and job X runs, ends and frees the admin-job slot before the second call stores X
- **THEN** one check runs, and the second call's store finds X stored and answers "ended" with X's stored outcome

#### Scenario: Replay conflict answer lost after a successful rollback
- **WHEN** two rollback calls with id X miss their lookups, the first is stored and its rollback succeeds and frees the slot, and the second call's store conflicts with X but its acknowledgement is lost
- **THEN** the second call answers "outcome unknown", not "rollback failed", X keeps its stored success, and the app following X shows the rollback succeeded

#### Scenario: Slow store
- **WHEN** storing update now X gets no answer from Postgres for 6 seconds
- **THEN** the call answers "no answer yet" 5 seconds after its arrival, no request for X reaches the worker even when the store later commits, X is ended "update failed" "Postgres unreachable" once Postgres answers, and the app following X shows that

#### Scenario: Same id while storing is slow
- **WHEN** storing update now X is slow and a second call with id X arrives
- **THEN** the second call answers "no answer yet" at once, without waiting or reaching the worker, and the operation call for X shows X's job once it is stored

#### Scenario: Store answer lost
- **WHEN** storing update now X commits, its acknowledgement is lost and Postgres then stays unreachable for 2 minutes with the server running
- **THEN** the call answers "no answer yet", no check runs for X, a settle attempt starts within 30 seconds of Postgres coming back with no orphaned settler connection outstanding, and X is ended "update failed" by the first attempt that completes, which frees the admin-job slot

#### Scenario: Malformed id
- **WHEN** an update now carries the operation id "abc"
- **THEN** the call is refused as malformed and nothing runs

#### Scenario: Resend after expiry
- **WHEN** update now X ended 31 days ago, its row is still stored, and a call arrives with X
- **THEN** the expired row is deleted in the admission transaction before the insert, the insert stores X as a new waiting job, and the call answers as a first send of X

#### Scenario: Resend after expiry whose store aborts
- **WHEN** id X names a job that ended over 30 days ago, a resend of X times out storing and that store's transaction aborts
- **THEN** the settler removes the expired row and stores X ended "update failed" "Postgres unreachable", and the operation call for X answers that, not "unknown operation" and not the old outcome

#### Scenario: Settler close stays pending
- **WHEN** a settle attempt is abandoned, its forced close does not return for 2 minutes, and Postgres is reachable again meanwhile
- **THEN** the settler token returns within 20 seconds, no attempt starts while the close is outstanding, the status shows settlement stuck after 60 seconds, and after a server restart start-up recovery ends X

#### Scenario: Replay while the commit is unknown
- **WHEN** the insert for update now X threw after it was sent, and a call with X arrives before the settler has ended X
- **THEN** the call answers "no answer yet" from memory and sends nothing to the worker

#### Scenario: Replay after the row moved on
- **WHEN** update now X was stored, its job is running, and a call with X arrives while the slot is still held by X
- **THEN** the call answers "started" from the row

#### Scenario: Replay after another job took the slot
- **WHEN** a resend of update now X misses on lookup, the original X is then stored and ends, and update now Y takes the slot before the resend claims it
- **THEN** the resend looks X up once more and answers "ended" with X's outcome, not "import running"

### Requirement: Anyone can read an admin job by its id
An operation call SHALL answer without sign-in with the job stored under that id: its kind, state (waiting, running or ended) and, once ended, its outcome, public reason and active build. An unknown id, or one ended over 30 days ago, SHALL answer "unknown operation". At most 4 SHALL run at once; others SHALL fail at once with "operation read busy". An ended job's outcome SHALL never change. A job whose build change committed SHALL read as ended with that outcome, whatever its worker did after.

#### Scenario: Job running
- **WHEN** update now X is importing a build
- **THEN** the operation call for X answers kind update now, state running

#### Scenario: Two admins
- **WHEN** update now X ended `switched`, and then another admin's rollback Y ran and ended
- **THEN** the operation call for X still answers ended `switched`

#### Scenario: Late refusal
- **WHEN** update now X answered "no answer yet", and the worker then could not take the static-data lock for it
- **THEN** the operation call for X answers ended "import running", and the number of check records is unchanged

#### Scenario: Worker exits before any commit
- **WHEN** update now X holds the lock, the compute worker exits, and no change of the active, previous or held build commits: its transaction aborts, or the settler's end of X wins the row fence
- **THEN** the operation call for X answers ended "update failed" with the reason "worker stopped", and the active, previous and held builds are unchanged

#### Scenario: Worker exits after staging
- **WHEN** update now X's import of build N+1 commits it staged, and the compute worker exits before the switch starts
- **THEN** build N+1 stays staged, the operation call for X answers ended "update failed" with the reason "worker stopped", and the active, previous and held builds and the revision are unchanged

#### Scenario: Commit still running when the worker exits
- **WHEN** update now X's switch is committing as the compute worker is killed, and the commit then succeeds
- **THEN** X is never shown ended "update failed"; once that commit has ended, the operation call for X answers ended `switched`

#### Scenario: Postgres down while settling
- **WHEN** the compute worker exits during update now X while Postgres is unreachable, and Postgres comes back 2 minutes later with the server still running
- **THEN** a settle attempt starts within 30 seconds of Postgres coming back with no orphaned settler connection outstanding, X's outcome is settled by the first attempt that completes, and only then is the admin-job slot free

#### Scenario: Worker exits after the switch commits
- **WHEN** update now X's switch to build N+1 commits and the compute worker exits before the check record is written
- **THEN** the operation call for X answers ended `switched` naming build N+1, and a refresh is requested once X is settled, which publishes build N+1 only if it selects build N+1's bundle, loads its bytes and finds it not yet announced

#### Scenario: Worker hangs after the switch commits
- **WHEN** update now X's switch to build N+1 commits and the worker's connection close then never returns, so no reply comes
- **THEN** the first eligible settler attempt that completes after the commit settles X from its row: the operation call answers `switched`, the slot is freed and a refresh is requested; a new update now answers "worker not running" while the worker has not replied, and 5 minutes after the watch first saw X ended the status shows the worker stuck

#### Scenario: Running job loses its lock and hangs
- **WHEN** update now X's job marked X running, then lost its connection and the static-data lock, and its final write and cleanup hang, so no reply comes
- **THEN** X is not ended for being old and, 5 minutes after the watch first saw X running with its own backend holding no lock, the status shows the worker stuck, also while a daily check holds the lock and the status shows busy; after a restart start-up recovery ends X "server restarted"

#### Scenario: Worker setup fails and hangs
- **WHEN** the worker's setup for update now X fails before the job runs and its connection close then never returns, so X stays `waiting` with no reply
- **THEN** X is not ended for being old, the slot stays held, new update nows answer "import running", the status shows the worker stuck 5 minutes after the request, and after a restart start-up recovery ends X "server restarted"

#### Scenario: Commit acknowledgement lost
- **WHEN** rollback X's transaction commits, and the worker loses its connection before it learns so
- **THEN** the operation call for X answers ended "rolled back", never "rollback failed"

#### Scenario: Server restarts mid-job
- **WHEN** rollback X was running when the server stopped and its transaction then aborted
- **THEN** after the restart the operation call for X answers ended "rollback failed" with the reason "server restarted"

#### Scenario: Commit in flight at the stop
- **WHEN** rollback X's commit was in flight when the server stopped and it commits, ending X first
- **THEN** after the restart the operation call for X answers ended "rolled back", and recovery's conditional end changes nothing

#### Scenario: Store still committing at a crash
- **WHEN** the server dies while storing job X is committing, and a new server process starts
- **THEN** the new process accepts no admin job until that store has committed or aborted; if it committed, X is ended "server restarted"

#### Scenario: Start-up check fails
- **WHEN** the start-up sweep or check fails after a restart that left job X open
- **THEN** X is still ended "server restarted", and admin calls are accepted afterwards

#### Scenario: Recovery close stays pending
- **WHEN** a start-up recovery attempt is abandoned and its forced close does not return for 2 minutes
- **THEN** no recovery attempt starts while the close is outstanding, admin calls answer "worker not running", the status shows recovery stuck after 60 seconds, and after a server restart recovery runs again

#### Scenario: Recovery commit lands after abandonment
- **WHEN** a start-up recovery attempt is abandoned after its `COMMIT` was sent, and that commit lands
- **THEN** admin calls still answer "worker not running" until a later attempt takes the admission lock and its own commit returns, and that attempt leaves the rows already ended "server restarted" unchanged

#### Scenario: Admin call during start-up recovery
- **WHEN** the server has started, and a transaction of the previous process that stores or ends an admin job has not yet committed or aborted, so start-up recovery is still waiting
- **THEN** an update now answers "worker not running" and starts nothing, until recovery has committed

#### Scenario: Many operation reads
- **WHEN** 4 operation reads are running and a fifth arrives
- **THEN** the fifth fails at once with "operation read busy", not "unknown operation"

#### Scenario: Unconfigured during start-up recovery
- **WHEN** confidential sign-in is not configured and an anonymous update now arrives before start-up recovery finishes
- **THEN** authentication refuses the call before it reaches job admission, and nothing starts

#### Scenario: Unknown id
- **WHEN** the operation call carries an id never stored, or one whose job ended more than 30 days ago
- **THEN** it answers "unknown operation"

#### Scenario: Old job ended recently
- **WHEN** job X was stored 40 days ago and ended 10 days ago
- **THEN** the operation call for X answers it ended, with its outcome

#### Scenario: Old settler dies waiting for the lock
- **WHEN** the old process's settler is waiting for its shared admission lock to end X, and the process dies
- **THEN** no upsert for X was sent, and the new process's recovery ends X "server restarted" if it is still open

#### Scenario: Old settler dies with its upsert in flight
- **WHEN** the old process's settler holds its shared admission lock and its upsert ending X, or its commit, is in flight as the process dies
- **THEN** recovery waits until that transaction has committed or aborted before it ends open jobs and opens admission; when a row for X survives, a resent call with id X answers from it, and when neither the admission insert nor the upsert committed, the operation call for X answers "unknown operation" and a resend with X is admitted as a new id

#### Scenario: Old open job
- **WHEN** job X was stored 40 days ago and has not ended
- **THEN** the operation call for X answers its state, and X is not removed

### Requirement: An admin can start an update now
An admin "update now" call SHALL start a build check on the compute worker against CCP's latest build and SHALL answer once the check holds the static-data lock, without waiting for it to end. It SHALL answer with one of: "started", "import running", "worker not running", "update failed" with a public reason, "no answer yet", "admin busy", or, for a stored ended job, "ended" with its stored outcome. The check's end SHALL be read through the operation call.

#### Scenario: Update now accepted
- **WHEN** build N is active, CCP's latest is N+1, nothing holds the lock and an admin presses update now with operation id X
- **THEN** the call answers "started", and the check ends `switched` to build N+1 with job X ended `switched`

#### Scenario: Lock already held
- **WHEN** the daily check is importing a build and an admin presses update now
- **THEN** the call answers "import running", no second check runs and no check record names `update now`

#### Scenario: Worker down
- **WHEN** the compute worker is not running and an admin presses update now with a new operation id
- **THEN** the call answers "worker not running" after the id lookup, nothing is stored, and no check record is written

#### Scenario: Worker exits while the job is being stored
- **WHEN** an admin presses update now or roll back with a new operation id, passes the worker check, and the compute worker exits while the job's insert is pending, so the stored job is never sent
- **THEN** the job is ended "update failed" or "rollback failed" with the reason "worker not running", the admin-job slot is freed after that end commits, and the operation call for the id answers that outcome with the public reason "worker not running", for update now and for roll back alike

#### Scenario: Replay while the worker is down
- **WHEN** update now X ended `switched`, the compute worker is not running, and a call with id X arrives
- **THEN** it answers "ended" with X's stored outcome `switched`

#### Scenario: Replay of an ended job with no change
- **WHEN** update now X ended "up to date" and a call with id X arrives
- **THEN** it answers "ended" with X's stored outcome "up to date", and no check runs

#### Scenario: Admin calls in a burst
- **WHEN** 2 admin calls are waiting on the database and a third admin call arrives
- **THEN** the third answers "admin busy" at once and touches nothing, and a pending settle and an unrelated database call still complete

#### Scenario: Lookup returns after the answer
- **WHEN** looking up a new id X answers 7 seconds after the call, after the call answered "update failed"
- **THEN** no admin-job slot is taken, no row for X is stored and no request reaches the worker

#### Scenario: Slow lookup
- **WHEN** looking up a new id gets no answer from Postgres for 6 seconds
- **THEN** the call answers "update failed" with the reason "Postgres unreachable" within 10 seconds of its arrival, and nothing reaches the compute worker

#### Scenario: Check ends before it starts
- **WHEN** the worker cannot reach Postgres for the update-now job
- **THEN** the call answers "update failed" with the reason "Postgres unreachable"

#### Scenario: No answer within 10 seconds
- **WHEN** the worker has neither started nor ended the update-now check 10 seconds after the call
- **THEN** the call answers "no answer yet", the check may still run, and its end is read through the operation call

### Requirement: An admin can roll back the builds they confirmed
An admin "roll back" call SHALL carry the build-state revision the admin confirmed, and SHALL roll back on the worker only when that is still the revision under the lock. Every change of the active, previous or held build SHALL raise the revision; pruning SHALL never lower it. It SHALL answer "rolled back", "builds changed", "no previous build", "import running", "worker not running", "rollback failed" with a public reason, "outcome unknown", "admin busy", or "ended" with a stored job's outcome.

#### Scenario: Rollback accepted
- **WHEN** build N+1 is active, build N is previous, the revision is R and an admin rolls back with revision R
- **THEN** the call answers "rolled back" naming build N, build N is active, build N+1 is previous and held, and the revision is higher than R

#### Scenario: Builds changed since confirmation
- **WHEN** an admin confirmed a rollback at revision R, and the server switched to build N+2 before the rollback held the lock
- **THEN** the call answers "builds changed" and no build changes state

#### Scenario: Retry after a lost answer
- **WHEN** rollback X committed, its answer was lost, and the same call is sent again
- **THEN** it answers "ended" with X's stored outcome "rolled back" naming build N, and swaps nothing

#### Scenario: Retry after a restore
- **WHEN** rollback X from N+1 to N committed, its answer was lost, an update now restored build N+1, and the call with id X is then sent again
- **THEN** it answers "ended" with X's stored outcome "rolled back", and build N+1 stays active

#### Scenario: Late confirmation after a restore
- **WHEN** an admin confirmed a rollback at revision R, and before it arrives another rollback and an update now restore the same builds
- **THEN** the call answers "builds changed" and no build changes state

#### Scenario: Revision after pruning
- **WHEN** an admin confirmed a rollback at revision R, then a switch happened, and then over 100 failed switch records were written and pruned
- **THEN** the revision is still higher than R and the call answers "builds changed"

#### Scenario: No previous build
- **WHEN** build N is active, no build is previous and an admin rolls back
- **THEN** the call answers "no previous build", the active build stays active, and a `failed` rollback record is attempted, so the status's last rollback is that record when it was stored

#### Scenario: Import running
- **WHEN** an import holds the static-data lock and an admin rolls back
- **THEN** the call answers "import running" and no build changes state

#### Scenario: Statement fails
- **WHEN** a statement of rollback X fails, Postgres stays reachable, the transaction did not commit, and the failure-recording transaction commits
- **THEN** the call answers "rollback failed" with that statement's public reason, no build changes state, and job X is stored ended "rollback failed" with a failed rollback record

#### Scenario: Failure cannot be recorded
- **WHEN** a statement of rollback X fails, the transaction did not commit, and the failure-recording transaction aborts too
- **THEN** no build changes state, no failed rollback record is stored, and the settler ends X "rollback failed" with the reason "outcome unknown"; the call answers that, or "outcome unknown" if it ran out of time first

#### Scenario: Rollback cannot be confirmed
- **WHEN** rollback X's transaction fails, the worker cannot then read whether it committed, and it had not committed
- **THEN** job X is ended "rollback failed" with the reason "outcome unknown", no failed rollback record is written, and the call answers "rollback failed" if X ended within 30 seconds, else "outcome unknown"

#### Scenario: No reply within 30 seconds
- **WHEN** the rollback has not replied 30 seconds after the call
- **THEN** the call answers "outcome unknown", the admin-job slot stays taken until the job ends, and a rollback that commits later requests a refresh, is announced to apps when that refresh still finds it current and loads its bytes, and is read through the operation call

### Requirement: An admin can turn auto-update on or off
An admin call SHALL set the auto-update setting on or off, carrying the setting revision it saw and a write id: it SHALL change the setting only at that revision, answer a replay of a stored write id as confirmed, and else answer "setting changed" with the stored value. The setting SHALL be stored in the database, SHALL survive a restart, and SHALL apply from the next check that starts. A check already running SHALL keep the setting it read at its start.

#### Scenario: Delayed first write after the first commit
- **WHEN** an admin's first "off", sent from a status showing no writes, is delayed, another admin's "on" is confirmed, and the delayed "off" arrives
- **THEN** it changes nothing and answers "setting changed" with on and that write's revision

#### Scenario: Status read during the first write
- **WHEN** a status read runs while the first "off" is inserted but not yet committed, and a second admin's "on" is sent from that status after the first commits
- **THEN** the status shows on with no writes, and the second call answers "setting changed" with off, since "no writes" is never current again

#### Scenario: First toggle on a fresh database
- **WHEN** no setting write has ever been stored, the status shows auto-update on with no writes, and an admin turns it off
- **THEN** the call creates the row and answers off as confirmed with its revision

#### Scenario: Turn off
- **WHEN** auto-update is on and an admin turns it off
- **THEN** the call answers with auto-update off, the status shows it off, and it is still off after the server restarts

#### Scenario: Turned off during a check
- **WHEN** a check started with auto-update on is importing build N+1, and an admin turns auto-update off
- **THEN** that check still switches to build N+1, and the next daily check that finds build N+2 stages it

#### Scenario: Setting cannot be stored
- **WHEN** an admin turns auto-update off while Postgres cannot be reached
- **THEN** the call fails with "setting not saved" and the stored setting is unchanged

#### Scenario: Delayed stale write
- **WHEN** an admin's "off" with write id W1 times out before reaching the server, its Retry commits off, the admin then sets on and gets it confirmed, and the original W1 send then reaches the server
- **THEN** that send finds W1 stored, writes nothing, and answers confirmed with the current value on and its revision, and the next check reads on

#### Scenario: Delayed write whose id was pruned
- **WHEN** an admin's "off" with write id W1 is delayed until more than 100 later writes have pruned W1, and then arrives with its old revision
- **THEN** it writes nothing and answers "setting changed" with the current value

#### Scenario: Retry finds its own write
- **WHEN** an admin's "off" with write id W1 commits, its answer is lost, and the Retry with W1 arrives
- **THEN** the call answers off as confirmed and the revision is raised once

#### Scenario: Two toggles in a row
- **WHEN** an admin turns auto-update off, gets it confirmed, and turns it on again before any status read
- **THEN** the second call carries the revision from the first answer and is confirmed on

#### Scenario: Write acknowledgement lost
- **WHEN** an admin turns auto-update off, the write commits, and the database's acknowledgement is lost before the server answers
- **THEN** the call answers "setting not confirmed", never "setting not saved", and the next check reads auto-update off

### Requirement: Static-data mutations require an authenticated admin

Update now, roll back and set auto-update SHALL require a live Kaname session with Serverpod admin scope. No key parameter, key check or shared-key configuration SHALL authorize a call. The public status SHALL report whether the server is configured to grant admin access, without identifying its admins.

#### Scenario: Scoped admin action
- **WHEN** a signed-in caller with admin scope sends a valid admin mutation
- **THEN** the server admits it subject to the existing operation, revision and worker checks

#### Scenario: Anonymous, non-admin or former key holder
- **WHEN** an anonymous caller, expired session, signed-in caller without admin scope or caller supplying only the old install key attempts any admin mutation
- **THEN** the server denies the mutation before admission and nothing changes; public status, operation status and the report remain readable
