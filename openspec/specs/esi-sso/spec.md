# esi-sso Specification

## Purpose
Connect an EVE character to Kaname through CCP sign-in. Use one active ESI holder and limit access to the scopes allowed for that character and mode.

## Requirements

### Requirement: Each mode signs in through its own CCP registration

The server SHALL use a confidential authorization code exchange and keep its client secret server-side. Native desktop solo SHALL use authorization code with S256 PKCE and an owner-provided client ID, without a client secret or server connection for standalone sign-in. Each callback SHALL match the registered redirect and a live, unconsumed attempt bound to the initiator.

#### Scenario: Confidential browser sign-in

- **WHEN** CCP returns a valid code and state to the self-host's registered HTTPS callback
- **THEN** only the server exchanges the code using its registration and secret, and only the initiating app can complete the Kaname sign-in

#### Scenario: Native desktop sign-in

- **WHEN** CCP sends a valid code and state to `http://localhost:48175/auth/esi/callback` for a solo attempt
- **THEN** the app exchanges the code with its own client ID and verifier, sends no client secret, and does not need a Kaname server

#### Scenario: Replayed, misrouted or abandoned callback

- **WHEN** a callback has missing, duplicated, invalid, expired or spent state, a different destination, or no matching live attempt
- **THEN** it creates no identity or authorization, and it does not exchange a code

#### Scenario: User cancels or callback cannot listen

- **WHEN** the user cancels at CCP or the native loopback listener cannot bind
- **THEN** the app shows a fixed cancellation or callback failure and does not activate a new holder

### Requirement: Connected sign-in verifies the consenting browser

The server SHALL bind a connected authorization to the browser that approved it and to its initiating app. A consenting browser that is separate from the app SHALL receive a single-use completion code that the user must provide to that app. The server SHALL NOT commit identity, session or vault changes until it verifies both proofs.

#### Scenario: Web and native connected completion

- **WHEN** the initiating web browser presents its matching browser binding, or a native app presents the completion code the user obtained in the callback browser, together with the matching attempt proof
- **THEN** the server can complete that attempt once; it does not put a session credential in the redirect URL or callback page

#### Scenario: A forwarded authorization link cannot yield a session

- **WHEN** a user approves a forwarded CCP authorization link in another browser and the initiating app lacks the matched browser binding or the code issued to the consenting browser
- **THEN** the initiating app cannot redeem a session or activate a grant for the user, even if it can prove that it started the attempt

#### Scenario: One client cannot fill the global attempt capacity

- **WHEN** one client reaches its limit for live connected sign-in attempts and tries again
- **THEN** it receives a fixed busy result while a second client can still start a sign-in

### Requirement: Accept only validated CCP character identity

Both modes SHALL accept only a correctly signed CCP access JWT verified against CCP's JWKS. They SHALL check the allowed signing algorithm, issuer, EVE Online audience, exact registration client ID, expiry and character subject. The server SHALL map validated character and ownership identity to a stable Serverpod user; it SHALL NOT use a CCP access token as a Kaname session credential.

#### Scenario: Valid identity signs in again

- **WHEN** separate valid authorizations identify the same character and owner in the connected flow
- **THEN** they resolve to the same Serverpod user, and privileges come only from server policy

#### Scenario: Invalid signature, key or claims

- **WHEN** a token has an invalid signature, an unsupported algorithm, an unknown key after a bounded JWKS update, an invalid issuer, wrong or missing audience, expired validity, malformed subject or missing owner identity
- **THEN** neither mode establishes identity, activates a credential or sends ESI work using it

#### Scenario: CCP rotates its signing key

- **WHEN** a valid token uses a new key that CCP publishes in its JWKS
- **THEN** verification can accept the token after refreshing known keys without accepting an unverified token

#### Scenario: Known character presents another owner

- **WHEN** a validated token identifies a stored character with a different owner hash
- **THEN** the sign-in cannot claim the existing user, vault holder or private call history

#### Scenario: Definitive refresh verification rejection

- **WHEN** CCP returns a refreshed grant that definitively fails verification for the current authorization
- **THEN** the old authorization cannot supply a bearer or refresh again, re-login is required, and a signed owner conflict blocks the mismatched identity

### Requirement: Configured scope policy fails closed

Each authorization SHALL request only scopes declared by enabled modules and permitted by the configured policy for the character and mode. Optional classes SHALL require an applicable recorded opt-in. Missing policy or opt-in SHALL grant no scope for that class. A callback or refresh SHALL NOT extend the allowed grant, and a policy or opt-in change SHALL require reauthorization before affected access resumes.

#### Scenario: Enabled module and permitted classes

- **WHEN** an enabled module declares scopes for a required class and for an optional class with a recorded opt-in for the same character and policy revision
- **THEN** the request contains those scopes exactly once and excludes disabled-module and never-requested scopes

#### Scenario: Missing policy or optional opt-in

- **WHEN** policy has no rule for a declared class, or marks it optional without a matching recorded opt-in
- **THEN** neither mode requests or exercises its scope

#### Scenario: Unconfigured solo signs in without skills access

- **WHEN** a desktop user signs in before enabling local skills access, then explicitly enables it for their validated character and authorizes again
- **THEN** the first request contains no skills scope, and only the second request after recording the local policy and opt-in may ask for `esi-skills.read_skills.v1`

#### Scenario: Grant differs from the permitted request

- **WHEN** a signed access token contains an unrequested scope, or a granted scope becomes forbidden before use
- **THEN** the server or native runtime refuses to use that authorization and does not dispatch the scoped call

### Requirement: An active holder can read character skills

The connected and desktop solo modes SHALL allow a signed-in viewer to request their own skills using the generated `GET /characters/{character_id}/skills` operation through the existing scheduler and the active vault credential. The operation SHALL use only the viewer's validated character and the applicable skills scope. A connected app SHALL NOT attempt ESI itself, even if the server is unavailable.

#### Scenario: Scoped read in both modes

- **WHEN** a viewer asks to read skills in connected mode or desktop solo mode and that mode holds a current grant for `esi-skills.read_skills.v1`
- **THEN** the appropriate scheduler admits the generated request for that character and the app can show the typed result

#### Scenario: No authority or no scope

- **WHEN** the requester is signed out, scope is missing, the grant is stale, the other mode holds the character, or the connected server cannot be reached
- **THEN** no ESI request leaves the wrong mode and the app shows a fixed reason without secrets

#### Scenario: The scheduler refuses a skills read

- **WHEN** the connected or solo scheduler refuses to send a skills request
- **THEN** the app explains the refusal using its stable reason and shows the retry time when one is known
- **AND** if the deadline is unknown, the app does not invent one or retry automatically

### Requirement: Handoff parks the source before activating the destination

Kaname SHALL identify the active holder and require an explicit handoff for a character moving between the server and a desktop device. Only the matching destination SHALL activate after confirmed source parking and fresh CCP authorization of the same character and owner. Handoff SHALL NOT transfer CCP credentials or allow ordinary sign-in to bypass a known holder assignment.

#### Scenario: Take a server-held character solo

- **WHEN** the signed-in character takes the token holder from the server to a desktop device and completes native PKCE on that character
- **THEN** the server stops dispatching and parks its credential before the device can dispatch; later connected requests do not use a server bearer for that character

#### Scenario: Return a device-held character to the server

- **WHEN** the selected desktop device parks its credential and the same character completes confidential sign-in to take the holder back
- **THEN** only the server can dispatch once activated and the device cannot continue as a solo holder

#### Scenario: Mismatch, replay or competing destination

- **WHEN** a stale handoff, another device, a different character or a different owner attempts activation
- **THEN** that attempt cannot activate and cannot consume another destination's authorization

#### Scenario: Interruption at handoff

- **WHEN** parking cannot be confirmed, or the app restarts or the network fails after source parking and before destination activation is confirmed
- **THEN** the destination does not dispatch without confirmed authority, the source does not reactivate on timeout, and resuming cannot create two active holders

#### Scenario: Original device cannot prove it parked

- **WHEN** the server still has a device assignment and the original device or its durable release proof is lost
- **THEN** no login or admin action can reclaim the holder in M2, and the connected app reports that the original device must park before the server can take over

#### Scenario: A standalone device joins the server

- **WHEN** a desktop holds a character solo, the server has no holder assignment for it, the device records its join intent and parks its credential, and the same character and owner complete confidential authorization
- **THEN** the server activates only after that sequence, and refuses this path for a character with any existing assignment

### Requirement: Sign-in and handoff keep credentials out of diagnostics

Kaname SHALL keep bearer and refresh tokens, session credentials, authorization codes, PKCE verifiers, client secrets and vault keys out of logs and error responses. Persisted credentials SHALL be encrypted or stored only as non-reversible verifiers. Public responses SHALL use fixed failure classes; the only credential returned to the app SHALL be its own Kaname session credential over the sign-in completion channel.

#### Scenario: Successful login and later refresh

- **WHEN** the app completes sign-in, rotates a refresh token and performs a scoped call
- **THEN** inspecting persisted records and logs reveals no plaintext credential or key, and the connected app receives no CCP token

#### Scenario: Secret-bearing upstream or malformed input

- **WHEN** a malformed callback or upstream failure contains a secret sentinel in a URL, body, error or header
- **THEN** no sentinel appears in a stored record, log line or public error response

### Requirement: The desktop restores local state after a definitively refused take

When the source confirms it made no reservation for a new desktop take, the desktop SHALL restore the prior local character state and selection. After interruption it SHALL restore only if it saved the prior state and the source confirms that the exact intent was never accepted and can no longer be accepted. When the outcome is uncertain or the source may already have committed, it SHALL keep the pending take and its original proof. A refusal SHALL NOT authorize a desktop holder.

#### Scenario: A definitive refusal restores the desktop state

- **WHEN** the server definitively refuses a new take before reserving the holder for that device proof
- **THEN** the desktop restores the character state and selection from before the take, and reports the existing blocked notice
- **AND** Return sends no take for the refused intent, and while the same connected session reports a server holder for that character, native skills authorization is blocked

#### Scenario: Recovery restores a refused take after interruption

- **WHEN** the desktop saved a recoverable take and reopens after losing the refusal or exiting before committing its rollback
- **AND** the source confirms that the exact intent was never accepted and a delayed copy cannot be accepted
- **THEN** the desktop restores the previous row or removes only the temporary row, restores the previous selection if the intent still owns it and the prior selection is still valid, and explains in Settings that the take did not go through and a new Take can start under the existing holder rules
- **AND** proof cleanup starts only after the local transaction commits. If the delete cannot be confirmed, the unused proof stays tracked for cleanup without changing the new-Take notice. A failed transaction leaves the intent and proof available and does not show that notice.

#### Scenario: Reconciliation and a delayed take cannot both win

- **WHEN** reconciliation of an exact intent and a delayed take for that intent reach the source in either order
- **THEN** if reconciliation confirms non-acceptance first, the delayed take cannot park or reserve the holder
- **AND** if the take committed first, the source does not confirm non-acceptance and the original proof can resume parking or recover its matching reservation

#### Scenario: An uncertain take keeps the original proof

- **WHEN** the original outcome is unconfirmed, including after a lost or malformed reply, timeout, generic refusal, later authentication rejection, wrong source, or a source that cannot prove what happened to that intent
- **THEN** the desktop keeps the pending take and original proof across restart, and does not activate a desktop grant
- **AND** when it resumes that take it uses the same proof, so a reservation that already committed can still be recovered

#### Scenario: A pending recovery explains what a retry may not settle

- **WHEN** the desktop retries an epoch-bound take through Take or Return and receives the source's pending reply
- **THEN** Settings explains that the take remains unconfirmed and another retry may not settle it
- **AND** it offers no reset and retains the journal and original proof

#### Scenario: A pre-upgrade take cannot fabricate prior state

- **WHEN** the desktop opens a pre-upgrade journal without a saved prior state for a pending take
- **THEN** it retains the original row and proof, can recover a matching reservation as before, and does not fabricate a previous character or selection

### Requirement: An inconclusive viewer refresh preserves the last known holder

When a connected viewer refresh cannot establish the holder state, the app SHALL keep the last verified viewer for the same session and apply the existing desktop holder check to it. An inconclusive reply SHALL neither sign the viewer out nor grant desktop authorization. The viewer route SHALL report a temporary session lookup error as unavailable, not as sign-in required, and SHALL NOT expose the error or a credential.

#### Scenario: The holder check survives a failed refresh

- **GIVEN** the last verified viewer has a holder for the selected desktop character and the desktop has no matching reservation
- **WHEN** a viewer refresh after Take or Return fails or the reply cannot establish the viewer's holder state
- **THEN** the connected viewer and last known holder stay available, and the desktop does not start native skills authorization for that character

#### Scenario: A confirmed viewer update replaces the holder view

- **WHEN** a viewer refresh verifies a new holder state for the current session, including a viewer with no holder assignment
- **THEN** the desktop applies its holder check to the new state instead of the previous one

#### Scenario: A confirmed invalid session ends the connected view

- **WHEN** the viewer route confirms that the current session is no longer valid
- **THEN** the app signs the connected viewer out and no longer uses that session's holder information

#### Scenario: A temporary lookup error is not session invalidation

- **WHEN** the viewer route cannot complete the session lookup because of a temporary error
- **THEN** the route reports unavailability without reporting that sign-in is required or exposing the lookup error or a credential

#### Scenario: Sign-out wins over an in-flight refresh

- **WHEN** the user signs out before a viewer refresh completes
- **THEN** the app clears the connected viewer and the late reply cannot restore it or its holder information

### Requirement: The desktop removes unreferenced handoff proofs safely

The desktop SHALL track handoff proofs still referenced at upgrade or created afterward. It SHALL remove tracked proofs only after no committed character journal or take rollback snapshot references them, and retry on reopen if cleanup did not finish. Cleanup SHALL NOT change holder state, delete untracked legacy entries, or disclose proofs or keyring errors. This guarantee covers the journal and exact-key requests, not interruption inside the secure-storage backend.

#### Scenario: A finished transition leaves an unused proof

- **WHEN** a committed take rollback or reservation leaves a tracked proof unreferenced
- **THEN** the proof is absent from the keyring by the next successful credential-store reopen with working secure storage
- **AND** the committed character, selection and holder outcome do not change during cleanup

#### Scenario: Cleanup is interrupted or the keyring refuses deletion

- **WHEN** the app exits after SQLite drops the last reference but before cleanup finishes, or the keyring refuses deletion
- **THEN** the committed journal outcome stands and, once keyring calls return, cleanup failures do not prevent reopening an otherwise usable credential store
- **AND** when secure storage permits deletion on a later open, the desktop removes the unused proof or confirms it is already absent, without exposing the proof or raw keyring error

#### Scenario: A live or pending journal still needs its proof

- **WHEN** cleanup encounters a proof referenced by a character journal or take rollback snapshot, including a pre-upgrade pending journal without a snapshot
- **THEN** the desktop keeps the proof, journal and snapshot unchanged
- **AND** a later resume or confirmed rollback can use the same proof as before cleanup

#### Scenario: A legacy key has no known journal reference

- **WHEN** the desktop upgrades a journal that shares secure storage with a proof that was already orphaned before upgrade
- **THEN** cleanup leaves that key and all non-proof keys untouched while tracking proofs the journal still references

#### Scenario: An unverified store deletes nothing

- **WHEN** the install key does not verify, the journal schema is unsupported, or migration fails
- **THEN** the store does not open and cleanup neither writes nor deletes any secure-storage entry

#### Scenario: A proof that was never committed is removed later

- **WHEN** a new proof is tracked but the handoff journal never commits a reference to it, whether or not the keyring write finished
- **THEN** on the next open with working secure storage, the desktop removes the proof or confirms it is already absent, and stops tracking it
- **AND** if the keyring cannot establish absence, the desktop keeps tracking it without blocking access to an otherwise usable journal once the call returns

### Requirement: Windows secure-storage mutations preserve committed credentials

On a local Windows store under the installation lock, a process exit during an exact-key write or deletion SHALL leave the complete old or new credential set, with unrelated entries intact. The desktop SHALL read existing data without migration. Unreadable, undecryptable, or undecodable data SHALL cause failure without deletion, overwrite, or secret disclosure. This excludes power loss, restored backups, and writers that bypass the lock.

#### Scenario: A Windows mutation publishes a complete credential set

- **GIVEN** a Windows desktop has an existing encrypted credential set with an install key and handoff proofs
- **WHEN** the app successfully writes or deletes one entry and reopens secure storage
- **THEN** it reads the complete new set, including each unrelated entry unchanged

#### Scenario: Windows exits during a credential mutation

- **GIVEN** a Windows desktop holds a committed set of credentials
- **WHEN** its process exits during an exact-key write or deletion, before or after publishing the new set
- **THEN** on reopen the desktop reads the complete old set before publication or the complete new set after publication
- **AND** it reads credentials only from the committed file. A staged file, complete or not, is never read or promoted to the committed file, even when no committed file exists

#### Scenario: An unreadable Windows credential file stays intact

- **WHEN** the committed Windows credential file cannot be read, decrypted, or decoded
- **THEN** the operation fails without deleting or overwriting that file, treating it as empty, or exposing a credential in the result or diagnostics

### Requirement: The source bounds closures of unused desktop take epochs

Successive unused take epoch closures for one character SHALL be at least 60 seconds apart, measured at the holder row lock just before each guarded write. Lock wait does not count; time after the write before commit acknowledgement can count. The limit SHALL survive restart and SHALL NOT apply to prepare, an eligible start, or a reply from committed evidence. If the limit or another refusal prevents the source from establishing non-acceptance, it SHALL NOT confirm non-acceptance.

#### Scenario: A new closure can commit at the cooldown boundary

- **GIVEN** an authenticated viewer's character remains server-held after a previous epoch closure
- **WHEN** the viewer's eligible reconciliation obtains the holder row lock at or after 60 seconds from the previous closure's guarded write time
- **THEN** the source can close that epoch without changing holder generation, phase or proof and can confirm its non-acceptance

#### Scenario: Repeated closures cannot advance the current epoch during the cooldown

- **WHEN** one or more requests would close a new unused epoch for the same character before the cooldown ends, including after a server restart
- **THEN** the source does not write a closure or advance the epoch and reports pending for that intent
- **AND** another character can still close its own eligible epoch

#### Scenario: Waiting for the holder row does not consume the cooldown

- **WHEN** a closure waits for the holder row lock before making its guarded write
- **THEN** the next closure cannot write until 60 seconds after the first operation obtained the lock, even if its request began earlier
- **AND** the source can answer an exact replay from the first committed outcome without another write

#### Scenario: A lost closure reply can be retried during the cooldown

- **WHEN** a proven closure's reply is lost and the same intent retries while the committed epoch still proves its non-acceptance
- **THEN** the source confirms the exact non-acceptance without another closure write

#### Scenario: The cooldown does not block an eligible start

- **WHEN** an eligible start arrives for the current epoch while further closure writes are limited
- **THEN** the cooldown does not prevent the start from parking the source and reserving its holder under the existing rules
- **AND** a later reconcile does not close or cancel the accepted take

#### Scenario: Only committed evidence confirms non-acceptance

- **WHEN** a reconcile or start arrives for an epoch-bound take intent
- **THEN** the source first answers from committed evidence for that intent, such as an accepted take or an epoch that is already closed, before it checks the cooldown or writes a closure
- **AND** a cooldown or a guarded write that matches no row leaves the outcome unproven, so the source reports pending and does not confirm non-acceptance
- **AND** a database error also never confirms non-acceptance; the route answers it as unavailable, and the desktop keeps the take and its original proof
