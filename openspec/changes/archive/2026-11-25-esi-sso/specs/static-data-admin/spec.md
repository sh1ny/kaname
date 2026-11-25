## ADDED Requirements

### Requirement: Static-data mutations require an authenticated admin

Update now, roll back and set auto-update SHALL require a live Kaname session with Serverpod admin scope. No key parameter, key check or shared-key configuration SHALL authorize a call. The public status SHALL report whether the server is configured to grant admin access, without identifying its admins.

#### Scenario: Scoped admin action
- **WHEN** a signed-in caller with admin scope sends a valid admin mutation
- **THEN** the server admits it subject to the existing operation, revision and worker checks

#### Scenario: Anonymous, non-admin or former key holder
- **WHEN** an anonymous caller, expired session, signed-in caller without admin scope or caller supplying only the old install key attempts any admin mutation
- **THEN** the server denies the mutation before admission and nothing changes; public status, operation status and the report remain readable

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Admin calls need the install admin key
**Reason**: A shared key cannot identify or scope a viewer, and ADR 0015 was interim.
**Migration**: Remove the old key and sign in as a character that the server grants admin scope.

### Requirement: The admin key is never logged
**Reason**: There is no static-data admin key after the cutover.
**Migration**: The ESI SSO credential-handling requirement covers credentials used by authenticated admin clients.

### Requirement: An admin can check the key
**Reason**: Only a live, scoped session authorizes mutations.
**Migration**: Use the signed-in viewer's admin grant to offer the controls. Call mutations through the authenticated generated client.

### Requirement: Repeated wrong keys pause admin calls
**Reason**: No key comparison or rejected-key pause remains.
**Migration**: A rejected sign-in or unauthorized admin request does not pause authenticated admins.
