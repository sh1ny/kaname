## ADDED Requirements

### Requirement: Static-data controls follow the current admin session

The Static data section SHALL show mutation controls for the current authenticated viewer with admin scope only over HTTPS or over HTTP to this machine (`127.0.0.1`, `::1`, `localhost`). It SHALL NOT ask for an install key. Sign-out, revocation or a different connection SHALL remove stale authority without hiding the public status. Losing authority SHALL NOT cancel an already submitted job on the same server.

#### Scenario: Signed-in admin sees controls
- **WHEN** the current server confirms admin scope on a secure connection
- **THEN** the app shows the available admin controls and no key prompt

#### Scenario: Sign-out or revoked scope
- **WHEN** the viewer signs out or the server rejects the current session's admin authority
- **THEN** the app hides mutation controls, keeps public status readable and can still follow a submitted job on that server

#### Scenario: Insecure remote connection
- **WHEN** the app is connected to a remote server over plain HTTP
- **THEN** it offers no sign-in or admin mutation there, transmits no credentials, shows "Admin actions need a secure connection", and still displays public status

#### Scenario: Delayed denial from an older session
- **WHEN** an earlier session's mutation returns unauthorized after a new session has signed in
- **THEN** the old response cannot remove the new session's admin authority

#### Scenario: Server cannot grant admin access
- **WHEN** the public status says the server is not configured to grant admin access
- **THEN** the section shows that admin actions are not configured, offers no mutation controls, and still displays the public status

#### Scenario: Local stack
- **WHEN** the server address is `http://localhost/api/` and the current session has admin scope
- **THEN** the section shows the admin controls

## MODIFIED Requirements

### Requirement: An admin can act from the section
For a signed-in viewer with static-data admin scope, the section SHALL offer "Update now", "Roll back" when a previous build exists, and the auto-update switch. "Roll back" SHALL ask for confirmation naming both builds and SHALL send the revision shown. Update now and roll back SHALL each carry a new operation id. Each action SHALL show while it runs and its answer in text. "Update now" and "Roll back" SHALL NOT be offered while busy or following a job.

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
- **WHEN** the app opens the section without an authenticated admin session on a server whose legacy key check no longer exists
- **THEN** it sends no key check, offers no key input or retry for it, hides mutation controls and still shows public status

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

## REMOVED Requirements

### Requirement: The admin key is entered for the session only
**Reason**: Static-data mutations use a signed-in identity and Serverpod admin scope.
**Migration**: Sign in with an authorized character. The app does not accept or retain the install key.
