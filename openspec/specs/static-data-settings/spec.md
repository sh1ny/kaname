# static-data-settings Specification

## Purpose

Defines the app's Static data section in Settings and its change-report page: this app's own bundle state, the server's build status, and the admin controls an install admin reaches with the install admin key.

## Requirements

### Requirement: The section shows this app's bundle
The section SHALL show the build of the bundle in use or none, and the build the server announced, none, or no server configured. It SHALL show two lines. Connection: waiting for the server, connected, unreachable with the next reconnect time, or reconnecting. Download: waiting for the first bundle, up to date, downloading, waiting to retry with the next try and the last failure ("network error", "server error", "bundle refused"), or stopped ("server has no bundle yet", "app update needed").

#### Scenario: Up to date
- **WHEN** the app uses build N's bundle, the stream is connected and the server announces build N
- **THEN** the section shows build N in use, build N announced, connected and up to date

#### Scenario: Waiting after a failed download
- **WHEN** the app uses build N's bundle, build N+1 is announced and its download failed with a network error 20 seconds ago
- **THEN** the section shows build N in use, build N+1 announced and waiting to retry, with the time of the next try and the reason "network error"

#### Scenario: Format too new
- **WHEN** the server announces a bundle format this app cannot read
- **THEN** the section shows the reason "app update needed" and the build still in use

#### Scenario: Before the first announcement
- **WHEN** the app holds build N's bundle and has not yet received an announcement
- **THEN** the section shows build N in use, "Waiting for the server" and "Waiting for the first bundle", not up to date and not "server has no bundle yet"

#### Scenario: Stream down
- **WHEN** the announcement stream has dropped and the next reconnect is due at 12:00:30
- **THEN** the section shows "Server unreachable, retrying at 12:00:30"

#### Scenario: Reconnect in flight
- **WHEN** the stream is down, its reconnect time arrives and the app subscribes again, and no announcement or failure has arrived yet, while a download waits to retry
- **THEN** the section shows "Server unreachable, reconnecting" with no passed time, still shows the download's next try and "Download now", and shows connected once an announcement arrives

#### Scenario: Stream down while a download waits
- **WHEN** a download failed and waits to retry, and then the announcement stream drops
- **THEN** the section shows both the reconnect time and the download's next try, and still offers "Download now"

#### Scenario: Only the retry time changes
- **WHEN** the section shows waiting to retry and the next try moves later while the bundle in use stays the same
- **THEN** the section shows the new time of the next try

#### Scenario: No server configured
- **WHEN** a desktop build has no server address and holds build N's bundle
- **THEN** the section shows build N in use and "No server configured" in place of the announced build and the server status

### Requirement: The section keeps the last download result
The section SHALL show the last download result of this app's run: none yet, the build stored and when, the build in use while saving or not saved on this device, or the build that failed, when and why. A save result SHALL finalize only its own attempt's saving result. A change or withdrawal of the announced build SHALL keep that result and SHALL drop only the cancelled retry and its "Download now".

#### Scenario: Target withdrawn after a failure
- **WHEN** build N+1's download failed with a server error, and the server then announces no bundle
- **THEN** the section shows "server has no bundle yet", no retry and no "Download now", and still shows that build N+1's download failed with "server error" and when

#### Scenario: Save refused
- **WHEN** build N+1's bundle downloads and verifies but this device refuses to save it
- **THEN** the section shows build N+1 in use, the last download as "in use, not saved on this device", not stored and not waiting to retry

#### Scenario: Late save after a newer attempt
- **WHEN** build N+1 is swapped in and its save is still pending, build N+2 is announced and its download fails with a network error, and then N+1's save is refused
- **THEN** the last download stays N+2's failure with "network error", and N+1 was shown "in use, saving" until N+2's attempt ended

#### Scenario: Target withdrawn while saving
- **WHEN** build N+1 is in use with its save pending, build N+2 is announced and then withdrawn before its download ends, and N+1's save then succeeds
- **THEN** the last download shows build N+1 stored, not "in use, saving"

#### Scenario: Save throws
- **WHEN** build N+1 is in use with its save pending and the device's store throws instead of answering
- **THEN** the last download shows build N+1 "in use, not saved on this device", the error only in the log, and nothing is retried

#### Scenario: Download stored
- **WHEN** build N+1's bundle is downloaded and stored at 12:01
- **THEN** the section shows the last download as build N+1 stored at 12:01

### Requirement: The user can ask to download the bundle now
The section SHALL offer "Download now" while the app waits to retry a download, and SHALL NOT offer it otherwise. Pressing it SHALL start the download at once, as the client-static-data capability defines.

#### Scenario: Download now pressed
- **WHEN** the section shows waiting to retry and the user presses "Download now"
- **THEN** the state changes to downloading, and "Download now" is no longer offered

#### Scenario: Nothing to download
- **WHEN** the app uses the announced bundle
- **THEN** "Download now" is not offered

### Requirement: The section shows the server's build status
With a server address, the section SHALL show the server's status: the active, previous, staged and held builds, CCP's latest build with the time of the check that learned it, the newest check with its time, outcome and reason, the last import with its outcome, reason and file counts, the last switch or rollback, auto-update on or off, and whether static-data work is running. Each outcome SHALL be shown in text, not by colour alone.

#### Scenario: Status shown
- **WHEN** the status names build N+1 active, build N previous, CCP's latest N+1 and the newest check `switched`
- **THEN** the section shows those builds, CCP's latest build, the check's time and "switched" in text

#### Scenario: Newer build waiting
- **WHEN** the status names build N active and build N+1 staged, with auto-update off
- **THEN** the section shows build N+1 as waiting to be switched to, and auto-update off

#### Scenario: Status unavailable
- **WHEN** the first status read after Settings is shown fails or the server is unreachable
- **THEN** the section shows that the server status is unavailable with a "Refresh" control, shows no exception text, host name or port, and still shows this app's bundle

#### Scenario: Worker stuck
- **WHEN** the status says the worker is stuck
- **THEN** the section shows "Worker stuck, restart the server"

#### Scenario: Recovery stuck
- **WHEN** the status says recovery is stuck
- **THEN** the section shows "Recovery stuck, restart the server"

#### Scenario: Start-up stuck
- **WHEN** the status says start-up is stuck
- **THEN** the section shows "Start-up stuck, restart the server"

#### Scenario: Settlement stuck
- **WHEN** the status says settlement is stuck
- **THEN** the section shows "Settlement stuck, restart the server"

### Requirement: The server status stays current
While the app is in the foreground and its location's path is exactly `/settings`, whatever its query, the section SHALL read the status when shown, on each build-change announcement and on "Refresh", one read at a time; a trigger during a read SHALL queue one more read. It SHALL read every 5 seconds while the last read said busy, and every 30 seconds otherwise. Three failed reads in a row SHALL stop polling until "Refresh". Child pages of Settings SHALL NOT poll.

#### Scenario: Import finishes while watched
- **WHEN** Settings is shown, the status says busy, and the server switches to build N+1 40 seconds later
- **THEN** the first status answer whose server-side read began after the switch shows build N+1 active, an earlier answer joined or reused from a read that began before it may still show build N, and after its first answer that says not busy the section reads every 30 seconds

#### Scenario: Another destination shown
- **WHEN** the status says busy and the user switches to another destination
- **THEN** no further status read is made until Settings is shown again, and then one read is made at once

#### Scenario: Work starts between reads
- **WHEN** Settings is shown, a read at time T said not busy, a check starts at T+2 s and its `staged` record commits at T+10 s, with no announcement
- **THEN** the read made at T+30 s shows the `staged` check

#### Scenario: Quick search open on Settings
- **WHEN** Settings is shown and the quick search opens, so the location becomes `/settings?search`
- **THEN** the section keeps reading the status as at `/settings`

#### Scenario: Report page open
- **WHEN** the status says busy, the section follows a job, and the user opens the change-report page from the section
- **THEN** no status or operation read is made while the report is shown, and both resume when Back returns to `/settings`

#### Scenario: Announcement during a read
- **WHEN** a status read is in flight and a build-change announcement arrives
- **THEN** one more read starts after the first ends, and no two reads are in flight

#### Scenario: Reads fail while busy
- **WHEN** the status said busy and the next three reads fail
- **THEN** polling stops and the section shows that the server status is unavailable with "Refresh"

### Requirement: The section follows the admin's own job
From an update now or roll back press, before its call is sent, the section SHALL hold that job, and once the call leaves it open or has no answer SHALL follow its operation id with one operation call at a time, every 5 seconds while Settings is shown, until the job has ended or 10 minutes pass, and SHALL show its outcome in text. Only the job's end, a final answer, or the 10 minutes SHALL release it; no other press SHALL replace it.

#### Scenario: Late start after an early answer
- **WHEN** update now X answered "no answer yet" and its check starts 20 seconds later and ends `up to date`
- **THEN** the section keeps following X and shows "Up to date" for it, without an announcement

#### Scenario: Unrelated work ends first
- **WHEN** update now X answered "no answer yet", and a bundle repair holds the lock and ends before X starts
- **THEN** the section keeps following X until it ends

#### Scenario: Another admin acts
- **WHEN** update now X ended `switched`, and before the section's next read another admin's rollback Y starts and ends
- **THEN** the section shows X's own outcome, `switched`

#### Scenario: Second press while following
- **WHEN** the section follows update now X
- **THEN** "Update now" and "Roll back" are not offered, and the section shows "Waiting for the last action"

#### Scenario: Second press before the answer
- **WHEN** the admin pressed "Update now" and its call has not answered
- **THEN** "Update now" and "Roll back" are not offered

#### Scenario: Slow operation read
- **WHEN** an operation read takes 8 seconds
- **THEN** no second operation read starts until it ends

#### Scenario: Back with a read still out
- **WHEN** the section follows X, an operation read is still out, and the user opens another destination and returns
- **THEN** no second operation read starts until that read ends, and its answer is shown, being for X, under the 10-minute rule

#### Scenario: Outstanding read says running
- **WHEN** the user returns within 10 minutes of the press while an operation read for X is out, and it answers running before the 10 minutes have passed
- **THEN** the section keeps following X, and the next read starts 5 seconds after that answer, unless that is 10 minutes or more after the press

#### Scenario: Running just before the limit
- **WHEN** an operation read for X answers running 3 seconds before 10 minutes have passed since the press
- **THEN** no further operation read starts, and at 10 minutes following stops and the section shows "Outcome unknown, check the builds"

#### Scenario: Outstanding read answers after the limit
- **WHEN** an operation read for X that is out answers after 10 minutes have passed since the press
- **THEN** the section shows X's outcome if it answered ended, and otherwise stops following and shows "Outcome unknown, check the builds"

#### Scenario: Reply lost
- **WHEN** a roll back call with id X gets no answer before the app's timeout
- **THEN** the section shows "No answer yet, watching the server" and follows X

#### Scenario: Server has no record yet
- **WHEN** the section follows X and the operation call answers "unknown operation" for 30 seconds
- **THEN** the section shows "The server has no record of this action yet" with "Try again", which sends the same call with id X and starts no second job

#### Scenario: Job never ends
- **WHEN** the section follows X and X has not ended after 10 minutes
- **THEN** following stops and the section shows "Outcome unknown, check the builds"

### Requirement: The admin key is entered for the session only
When the server says admin actions are configured, and its address is https or http to this machine (127.0.0.1, ::1, localhost), the section SHALL offer to enter the admin key; over other http it SHALL say "Admin actions need a secure connection". The app SHALL keep the key in memory only, never in storage, a log or on screen, and forget it on close or reload.

#### Scenario: Key entered
- **WHEN** the user enters the admin key and the server's check-key call answers "accepted"
- **THEN** the admin controls are shown, and the key field shows no characters of the key

#### Scenario: Key rejected
- **WHEN** a check-key or other admin call answers "admin key rejected"
- **THEN** the app forgets the key, hides the admin controls and shows "Admin key rejected"

#### Scenario: Late refusal for a replaced key
- **WHEN** an update now and an auto-update write were sent with key A, a refusal of one prompts the admin to enter key B, key B is accepted, and then the other call answers "admin key rejected"
- **THEN** the app keeps key B and its admin controls, and the late answer only settles its own job or write

#### Scenario: Too many attempts
- **WHEN** an admin call answers "too many attempts"
- **THEN** the app keeps the key and shows "Too many attempts, try again in a minute", with no admin control

#### Scenario: Check again after a pause
- **WHEN** the section shows "Too many attempts" and a minute has passed
- **THEN** it offers "Check again", which sends a check-key call with the key it holds and, on "accepted", shows the admin controls

#### Scenario: Restart
- **WHEN** the user entered the key, closes the app and starts it again
- **THEN** no key is held and the admin controls are hidden until it is entered again

#### Scenario: Not configured
- **WHEN** the status says admin actions are not configured
- **THEN** the section shows "Admin actions are not configured on this server" and no key field

#### Scenario: Key dropped from the server
- **WHEN** the app holds a key and its last status said admin actions are configured, the server restarts without the key, and the next check-key or admin call answers "admin actions not configured"
- **THEN** the app forgets the key, hides the admin controls and shows "Admin actions are not configured on this server", and a followed job is still followed

#### Scenario: Plain http to another host
- **WHEN** the server address is `http://sde.example.org/` and admin actions are configured
- **THEN** the section shows "Admin actions need a secure connection", offers no key field, and still shows the server status

#### Scenario: Local development
- **WHEN** the server address is `http://localhost:8080/` and admin actions are configured
- **THEN** the section offers the key field

### Requirement: An admin can act from the section
With the key entered, the section SHALL offer "Update now", "Roll back" when a previous build exists, and the auto-update switch. "Roll back" SHALL ask for confirmation naming both builds and SHALL send the revision shown. Update now and roll back SHALL each carry a new operation id. Each action SHALL show while it runs and its answer in text. "Update now" and "Roll back" SHALL NOT be offered while busy or following a job.

#### Scenario: Update now
- **WHEN** the admin presses "Update now" and the server answers "started"
- **THEN** the section shows static-data work running, offers neither "Update now" nor "Roll back", and follows the job until it ends

#### Scenario: Resent action answers ended
- **WHEN** a resent "Roll back" with id X answers "ended" with the stored outcome "rolled back"
- **THEN** the section shows "Rolled back" as the final answer, releases the job and follows nothing

#### Scenario: No answer yet
- **WHEN** "Update now" answers "no answer yet"
- **THEN** the section shows "No answer yet, watching the server" and follows the job

#### Scenario: Roll back confirmed
- **WHEN** build N+1 is active, build N is previous, and the admin presses "Roll back" and confirms
- **THEN** the call carries the revision shown with builds N+1 and N, the server rolls back, and the section shows build N active and build N+1 held

#### Scenario: Builds changed
- **WHEN** a confirmed rollback answers "builds changed"
- **THEN** the section shows "The builds changed, check them and try again" and reads the status at once

#### Scenario: Rollback outcome unknown
- **WHEN** a confirmed rollback X answers "outcome unknown"
- **THEN** the section shows "Outcome unknown, watching the server" and follows job X until it ends or 10 minutes pass

#### Scenario: Rollback failed
- **WHEN** a confirmed rollback answers "rollback failed" with a reason
- **THEN** the section shows "Rollback failed" and the reason in text, and the builds shown are unchanged

#### Scenario: Roll back cancelled
- **WHEN** the admin presses "Roll back" and cancels the confirmation
- **THEN** no admin call is made

#### Scenario: Action refused
- **WHEN** "Update now" answers "import running", "worker not running" or "update failed" with a reason
- **THEN** the section shows that answer and reason in text, the builds shown are unchanged, and the actions are offered again when the status is not busy

#### Scenario: Toggle not saved
- **WHEN** the admin turns auto-update off and the server answers "setting not saved"
- **THEN** the switch shows auto-update on again and the section shows "Setting not saved"

#### Scenario: Stale status after a toggle
- **WHEN** the admin turns auto-update off and gets "off", and a status read that began before that answer arrives afterwards saying on
- **THEN** the switch stays off until a status read that began after the answer arrives

#### Scenario: Status read in flight across a toggle
- **WHEN** a server status read took its snapshot with auto-update on, the admin's "off" then commits and answers, and the section then starts a new status read
- **THEN** the new read never joins the old one or gets its answer: the server returns a cached answer of the new generation, else joins a new-generation read in flight when a waiter place is free, else starts one when a waiter place and a work token are free; either way it shows auto-update off, and when neither is possible it shows "status unavailable", never the old snapshot

#### Scenario: Admin busy
- **WHEN** "Update now" answers "admin busy"
- **THEN** the section shows "The server is busy, try again", releases the press and follows nothing

#### Scenario: Late toggle answer after a new toggle
- **WHEN** the admin's "off" W1 is not confirmed and its Retry is out, a status read above W1's revision settles W1, the admin turns auto-update on as W2, and W1's Retry then answers confirmed or "admin busy"
- **THEN** W2's pending value, "Not confirmed" state, Retry and message are unchanged, and only W1's revision may raise the kept revision

#### Scenario: Key check unanswered
- **WHEN** the admin enters a key, or presses "Check again" after a pause, and the key check times out
- **THEN** the section shows "Could not check the key" with "Try again" and "Forget key", keeps admin controls hidden, and does not show the key as rejected

#### Scenario: Late resend answer after a new press
- **WHEN** a resend of X is still out, X is shown ended by the operation read, the admin presses update now Y, and the resend of X then answers "ended" or "no answer yet"
- **THEN** that answer is dropped: Y stays reserved and followed, and the section's controls and shown answer are Y's

#### Scenario: Toggle Retry refused
- **WHEN** the admin turns auto-update off, the write commits but its answer is lost, and the Retry answers "admin busy"
- **THEN** the section keeps "Not confirmed" with "Retry", shows the refusal beside it, and does not show auto-update as on; a later Retry answers off as confirmed

#### Scenario: Status read at the old revision
- **WHEN** auto-update is on at revision R, the admin's "off" times out, its Retry answers "admin busy", and a later status read shows on at revision R
- **THEN** the section shows on as the stored value but keeps "Not confirmed" with "Retry", and clears it only on a confirmed answer, "setting changed", or a status read above revision R

#### Scenario: Setting changed elsewhere
- **WHEN** the admin turns auto-update off from a status showing it on, and the server answers "setting changed" with on
- **THEN** the switch shows auto-update on and the section shows "The setting was changed elsewhere"

#### Scenario: Toggle refused as busy
- **WHEN** the admin turns auto-update off and the server answers "admin busy"
- **THEN** the switch shows auto-update on again and the section shows "The server is busy, try again"

#### Scenario: Resend refused while following
- **WHEN** the section follows X after "unknown operation", the admin presses "Try again", and the resend answers "admin busy"
- **THEN** the section keeps following X, shows the refusal beside "Waiting for the last action", and offers no new press until X has ended or 10 minutes have passed

#### Scenario: Toggle answer lost
- **WHEN** the admin turns auto-update off, the server stores it, and the answer is lost or is "setting not confirmed"
- **THEN** the section shows "Not confirmed" with "Retry", which sends "off" again with the same write id and revision, and does not show auto-update as on until a status read above the write's revision says so

### Requirement: The change report has its own page
The section SHALL open a change-report page showing the server's report between its active and previous builds: both builds, and per file its added, removed and changed counts, its changed fields with their counts, new or removed files, and its keys, marking each key list and field list that was cut off. When there is no report, the page SHALL show the server's reason. Its back control SHALL return to Settings, also when the page was opened directly by its address.

#### Scenario: Report shown
- **WHEN** the report for build N+1 against build N shows the types file with 2 added, 1 removed and 3 changed, field `volume` in 3 records
- **THEN** the page shows builds N and N+1, the types file with those counts and field `volume` with 3, and its keys

#### Scenario: Keys cut off
- **WHEN** the server's answer holds 1,000 keys of a file's changed list marked cut off, with a count of 5,000
- **THEN** the page shows those 1,000 keys and says the list was cut off, with the count 5,000

#### Scenario: No report
- **WHEN** the server answers with no report and the reason "no previous build", "comparison failed", "report missing" or "report too large"
- **THEN** the page shows "No previous build to compare", "The comparison failed" with its reason, "No report was stored", or "The report is too large to show"

#### Scenario: Server unreachable
- **WHEN** the report request fails, answers 503 or "report busy", returns a body the app cannot decode, or the server cannot be reached
- **THEN** the page shows "The report is unavailable" with a "Try again" control, distinct from "No report was stored", and no exception text, host name or port

#### Scenario: Narrow window
- **WHEN** the report page is shown at 390 pixels wide with a 120-character file name and a 120-character field name
- **THEN** it shows in one column with no horizontal scrolling and no overflow

#### Scenario: Long key lists
- **WHEN** the report holds 20,000 keys
- **THEN** the page builds only the key rows on screen, and each file's counts stay visible above its keys

#### Scenario: Report request stalls
- **WHEN** the report request gets no headers, or its body stops arriving, for 30 seconds
- **THEN** the app aborts it and the page shows "The report is unavailable" with "Try again", and "Try again" sends a new request that shows the report when the server answers

#### Scenario: Back from the report
- **WHEN** the user opened the report page from the section and leaves it with the back control or the browser's back button
- **THEN** the Settings screen is shown again

#### Scenario: Opened by its address
- **WHEN** the report page was opened directly at `/settings/static-data/report` and the user presses its back control
- **THEN** the Settings screen is shown, and the browser's back button still behaves as the browser does
