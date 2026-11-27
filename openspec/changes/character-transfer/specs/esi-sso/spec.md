## MODIFIED Requirements

### Requirement: Connected sign-in verifies the consenting browser

The server SHALL bind connected authorization to the approving browser and initiating app. A separate browser SHALL give the user a single-use completion code for that app. The server SHALL verify both proofs before identity, session or vault changes. A valid completion SHALL consume the proof once and keep its existing browser-attempt slot until the handler settles, even if the proof expires during completion.

#### Scenario: Web and native connected completion

- **WHEN** the initiating web browser presents its matching browser binding, or a native app presents the completion code the user obtained in the callback browser, together with the matching attempt proof
- **THEN** the server can complete that attempt once; it does not put a session credential in the redirect URL or callback page

#### Scenario: A forwarded authorization link cannot yield a session

- **WHEN** a user approves a forwarded CCP authorization link in another browser and the initiating app lacks the matched browser binding or the code issued to the consenting browser
- **THEN** the initiating app cannot redeem a session or activate a grant for the user, even if it can prove that it started the attempt

#### Scenario: One client cannot fill the global attempt capacity

- **WHEN** one client reaches its limit for live or completing connected attempts and tries again
- **THEN** it receives a fixed busy result while a second client can still start a sign-in if a global slot is free

#### Scenario: Held completions retain their attempt slots

- **WHEN** valid completions are held at the existing attempt limit and those attempts pass their expiry
- **THEN** another begin at that limit gets busy, and replaying a consumed proof starts no second write
- **AND** as soon as a completion settles, its slot can admit a new attempt

### Requirement: Accept only validated CCP character identity

Both modes SHALL accept only a correctly signed CCP access JWT verified against CCP's JWKS. They SHALL check the allowed signing algorithm, issuer, EVE Online audience, exact registration client ID, expiry and character subject. The server SHALL resolve the Kaname account from the verified character and owner. Each session SHALL identify that account and remain bound to its signing character. A CCP access token SHALL NOT serve as a Kaname session credential.

#### Scenario: Valid identity signs in again

- **WHEN** separate valid authorizations identify the same character and owner in the connected flow and the character is still linked to the same account
- **THEN** they resolve to the same Kaname user account and signing character, and privileges come only from server policy

#### Scenario: Invalid signature, key or claims

- **WHEN** a token has an invalid signature, an unsupported algorithm, an unknown key after a bounded JWKS update, an invalid issuer, wrong or missing audience, expired validity, malformed subject or missing owner identity
- **THEN** neither mode establishes identity, activates a credential or sends ESI work using it

#### Scenario: Connected proof expires before committing a mutation

- **WHEN** a sign-in or scope attempt, or the CCP identity it proved, expires before admission to commit
- **THEN** the server refuses it and leaves the session, account, membership, exclusion, grant and holder assignment unchanged

#### Scenario: Fresh scoped authorization commits the grant and holder together

- **WHEN** a valid scoped attempt matches the live signer and policy, and its proof is still fresh at commit admission
- **THEN** the encrypted grant and matching holder assignment commit together, or neither changes

#### Scenario: Owner conflict proof expires before the identity can be blocked

- **WHEN** a verified owner conflict from sign-in, linking, scope authorization or refresh expires after transfer work starts but before admission to commit
- **THEN** the owner, membership, main, connected sessions, opt-ins and holder assignment remain unchanged, and a browser proof also leaves the vault unchanged
- **AND** a definitively rejected refresh grant still follows the existing vault retirement rules; the refresh never accepts its replacement bearer

#### Scenario: CCP rotates its signing key

- **WHEN** a valid token uses a new key that CCP publishes in its JWKS
- **THEN** verification can accept the token after refreshing known keys without accepting an unverified token

#### Scenario: Known character presents another owner

- **WHEN** a fresh verified authorization for a known character proves a different owner hash and the transfer commits
- **THEN** the authorization cannot claim the previous account, reuse its grant, clear a device assignment or expose its private call history

#### Scenario: Definitive refresh verification rejection

- **WHEN** CCP returns a refreshed grant that definitively fails verification for the current authorization
- **THEN** the old authorization cannot supply a bearer or refresh again and requires re-login, even if the server cannot commit a transfer
- **AND** an unverifiable grant is not proof of another owner and cannot transfer the character

### Requirement: Connected operations recheck the signing session at admission

Connected admissions SHALL require a live signing session. Expired, revoked, blocked or detached sessions SHALL NOT start ESI work, change holders or authorize static-data writes. Work already admitted SHALL follow its existing rules. At or after expiry by database UTC, the admission read SHALL deny access. The server SHALL delete the exact session and commit before confirming expiry. That deletion SHALL stay final. On commit failure the server SHALL NOT admit work or confirm expiry.

#### Scenario: Expiry recorded at admission survives a backward clock step

- **WHEN** a protected admission read reaches the exact session's expiry and commits its deletion, then the database clock steps back and the server restarts
- **THEN** the former bearer cannot admit work, even if the caller never received the expiry reply
- **AND** other sessions that have not expired can still admit work

#### Scenario: The database clock steps back before expiry is recorded

- **WHEN** the database clock crosses a session's expiry and steps back before any expiry deletion commits
- **THEN** the next admission uses the current database time. It does not treat the unrecorded crossing as a terminal expiry

#### Scenario: An expiry deletion does not commit

- **WHEN** a protected admission read finds the session expired but cannot commit deletion
- **THEN** the request starts no protected work, and the explicit viewer check reports unavailability rather than confirmed expiry

#### Scenario: Work already admitted can finish after unlink

- **WHEN** unlink commits after the signing session passed the protected admission check for an ESI call
- **THEN** the call follows its existing completion rules, and the revoked session cannot admit another call

#### Scenario: Unlink wins before holder admission

- **WHEN** a holder request reaches its admission check after its signing session was revoked by unlink
- **THEN** it neither changes the assignment nor confirms a holder transition using that former session

#### Scenario: Unlink wins before static-data mutation admission

- **WHEN** a static-data mutation reaches its admission check after unlink revoked its allowlisted signing session
- **THEN** the mutation is denied, without acquiring durable job ownership or writing the setting

#### Scenario: A competing static-data mutation reserves while authority is checked

- **WHEN** one valid admin request is checking its live session and a distinct request reserves the job slot
- **THEN** the first request uses the existing busy or running response, without another reservation or an invariant failure

#### Scenario: An admitted refresh observes a signed owner conflict after unlink

- **WHEN** a refresh begun before unlink later returns verified claims for a different owner, its pinned ownership and vault grant generations are still current, and the proof is fresh at transfer admission to commit
- **THEN** the server rejects the grant and applies the transfer without restoring membership or changing the holder assignment

### Requirement: Handoff parks the source before activating the destination

Kaname SHALL require explicit handoff and confirmed source parking before the destination can activate. Take SHALL require fresh CCP authorization for the same character and ownership generation. After transfer, ordinary Return of a completed reservation can record parking without proving the former owner still owns the character. To activate server ESI, the current owner SHALL separately authorize a fresh grant. Handoff SHALL NOT transfer CCP credentials or bypass a known assignment.

#### Scenario: Take a server-held character solo

- **WHEN** the signed-in character takes the token holder from the server to a desktop device and completes native PKCE for that character and owner
- **THEN** the server stops dispatching and parks its credential before the device can dispatch; later connected requests do not use a server bearer for that character

#### Scenario: Return a device-held character to the server

- **WHEN** the selected desktop device parks its credential and completes ordinary Return with the matching proof and generation, and the current owner completes fresh confidential scoped authorization for the same character
- **THEN** only the server can dispatch once activated and the device cannot continue as a solo holder

#### Scenario: Mismatch, replay or competing destination

- **WHEN** a stale handoff, another device, a different character or an owner outside the required context attempts activation
- **THEN** that attempt cannot activate and cannot consume another destination's authorization

#### Scenario: Interruption at handoff

- **WHEN** parking cannot be confirmed, or the app restarts or the network fails after source parking and before destination activation is confirmed
- **THEN** the destination does not dispatch without confirmed authority, the source does not reactivate on timeout, and resuming cannot create two active holders

#### Scenario: Original device cannot prove it parked

- **WHEN** the server still has a device assignment and the original device or its durable release proof is lost
- **THEN** no login or admin action can reclaim the holder before M7, and the connected app reports that the original device must park before the server can take over

#### Scenario: A standalone device joins the server

- **WHEN** a desktop holds a character solo, the server has no holder assignment for it, the device records its join intent and parks its credential, and the same character and owner complete confidential authorization
- **THEN** the server activates only after that sequence, and refuses this path for a character with any existing assignment

### Requirement: The desktop restores local state after a definitively refused take

The desktop SHALL restore prior state only after a definitive refusal. During recovery it SHALL also require saved prior state and proof that the exact intent was never accepted and can no longer be accepted. When the outcome is uncertain, including after an ownership change, it SHALL keep the pending Take and original proof. A refusal SHALL NOT authorize a desktop holder. A pre-transfer Take cannot reopen an old reservation for the new owner.

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

- **WHEN** reconciliation of an exact intent and a delayed take for that intent reach the source in either order under an unchanged ownership generation
- **THEN** if reconciliation confirms non-acceptance first, the delayed take cannot park or reserve the holder
- **AND** if the take committed first, the source does not confirm non-acceptance and the original proof can resume parking or recover its matching reservation

#### Scenario: An uncertain take keeps the original proof

- **WHEN** the original outcome is unconfirmed, including after a lost or malformed reply, timeout, generic refusal, later authentication rejection, wrong source, or a source that cannot prove what happened to that intent
- **THEN** the desktop keeps the pending take and original proof across restart, and does not activate a desktop grant
- **AND** any resume uses the same proof; only the ownership generation that began the Take can recover a committed reservation through replay

#### Scenario: A pending recovery explains what a retry may not settle

- **WHEN** the desktop retries an epoch-bound take through Take or Return and receives the source's pending reply
- **THEN** Settings explains that the take remains unconfirmed and another retry may not settle it
- **AND** it offers no reset and retains the journal and original proof

#### Scenario: A pre-upgrade take cannot fabricate prior state

- **WHEN** the desktop opens a pre-upgrade journal without a saved prior state for a pending take
- **THEN** it retains the original row and proof and does not fabricate a previous character or selection
- **AND** under an unchanged ownership generation it can recover a matching reservation as before

### Requirement: The source bounds closures of unused desktop take epochs

Unused Take epochs SHALL close at most once per 60 seconds per character. Measure at the holder row lock just before writing; lock wait does not count, and time before commit acknowledgment may count. The limit SHALL survive restart. It SHALL NOT apply to prepare, an eligible start or a reply from committed evidence. Closure and proof of non-acceptance SHALL require the intent's ownership generation. Otherwise the source SHALL NOT confirm non-acceptance.

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

#### Scenario: A lost closure reply can be retried during the cooldown

- **WHEN** a proven closure's reply is lost and the same intent retries while the committed epoch still proves its non-acceptance under the current ownership generation
- **THEN** the source confirms the exact non-acceptance without another closure write

#### Scenario: The cooldown does not block an eligible start

- **WHEN** an eligible start arrives for the current epoch while further closure writes are limited
- **THEN** the source does not prevent the start from parking the source and reserving its holder under the existing rules
- **AND** a later reconcile does not close or cancel the accepted take

#### Scenario: Only committed evidence confirms non-acceptance

- **WHEN** a reconcile or start arrives for an epoch-bound take intent
- **THEN** the source first answers from matching committed evidence for that intent and current ownership, before it checks the cooldown or writes a closure
- **AND** a cooldown, ownership change or guarded write that matches no row leaves the outcome unproven, so the source reports pending and does not confirm non-acceptance
- **AND** a database error also never confirms non-acceptance; the route answers it as unavailable, and the desktop keeps the take and its original proof

## ADDED Requirements

### Requirement: Verified transfer removes prior server ESI authorization

Kaname SHALL require fresh CCP proof and the proofs for the connected operation that supplied it. In the same commit as the owner, membership and session changes, Kaname SHALL delete the character's server opt-ins and erase its server vault credentials and refresh lease. It SHALL retain a credential-free vault record if one exists and ensure former grants cannot match a later authorization. It SHALL NOT install a grant during transfer.

#### Scenario: Transfer clears existing ESI authority

- **WHEN** a verified transfer commits for a character with server opt-ins and a vault credential
- **THEN** those opt-ins and the encrypted credential and lease are absent, the old grant cannot produce an access token, and the new session requires fresh scoped authorization and any applicable opt-in before server ESI

#### Scenario: Failure rolls the transfer back

- **WHEN** a transfer fails before commit after attempting to write the changed owner, membership or authorization
- **THEN** no partial transfer commits, no new session is returned, and no replacement token from the failing proof becomes usable
- **AND** a refresh whose returned grant was definitively rejected still follows the existing vault retirement rules

#### Scenario: Transfer orders with an old opt-in or scoped grant write

- **WHEN** a write from the prior signing session races with a transfer
- **THEN** if the write commits first, transfer removes the saved opt-in or grant
- **AND** if transfer commits first, the former session cannot save either, even if it passed an earlier check

#### Scenario: A legacy blocked identity needs a new mismatching proof

- **WHEN** the upgrade finds an identity that was already blocked for an owner conflict
- **THEN** the upgrade does not transfer or unblock it, and a proof matching its stored owner cannot sign in
- **AND** a fresh verified proof for a different owner can transfer it through the normal path

### Requirement: Delayed proof cannot reverse a committed transfer

Kaname SHALL order connected browser attempts by their start and refuse a proof that predates the latest transfer fence for that character. A refresh SHALL remain bound to the ownership generation it observed before the exchange. A refused old proof SHALL NOT update the owner, issue a session or remove new authority. An unrelated character's attempts SHALL NOT be invalidated.

#### Scenario: Two connected browser attempts complete out of order

- **WHEN** a browser attempt for the former owner starts before another attempt completes a transfer and then submits its still-valid proof
- **THEN** the former attempt cannot change the owner, detach the character again, sign into the old or new account, or remove the new owner's authority
- **AND** a separate character's pending attempt can complete

#### Scenario: An old refresh completes after transfer

- **WHEN** a refresh from an old generation completes after a transfer, whether it reports the old or the new owner hash
- **THEN** that refresh cannot change either owner's Kaname identity or publish or erase a grant for the new generation

#### Scenario: A later CCP sign-in can verify another transfer

- **WHEN** a new ordinary sign-in starts after a transfer and CCP freshly proves a different owner, including a previously observed hash
- **THEN** Kaname can apply another transfer without reusing either earlier account or ownership generation

### Requirement: Transfer preserves a known device holder

Transfer SHALL NOT change the holder assignment, generation or proof. The server SHALL keep ESI blocked while a device assignment remains or a move to that device is unresolved. A Take SHALL authorize only the ownership generation that initiated it. A completed reservation can be returned only through ordinary Return with a live character session and the original device's proof that it parked. There SHALL be no verified reclaim in this change.

#### Scenario: A transferred character signs in while the original device holds it

- **WHEN** the new owner signs in and a device assignment still exists
- **THEN** sign-in succeeds without a server grant, and scoped authorization or a different device cannot take or reset that assignment

#### Scenario: The original device completes ordinary Return after transfer

- **WHEN** the original desktop saved its completed reservation before transfer, parks its credential, and uses the saved proof and generation with a live connected session for the character
- **THEN** ordinary Return can release the assignment, and only a fresh scoped authorization may enable server ESI afterward

#### Scenario: An old Take is retried after transfer

- **WHEN** a pre-transfer Take intent or reservation is replayed with a new owner's session
- **THEN** it cannot park a newly installed server grant or authorize a device for the new owner
- **AND** Kaname reports pending rather than non-acceptance where it cannot establish whether the old Take committed

#### Scenario: The original device cannot complete ordinary Return

- **WHEN** the original device or proof cannot complete Return for a remaining device assignment or unfinished transfer to the device
- **THEN** Kaname leaves the assignment in place and server ESI remains blocked

#### Scenario: Transfer wins before the final Take reservation write

- **WHEN** a Take has entered parking, but transfer commits before the server can record the device reservation
- **THEN** the former Take obtains no completed reservation or owner fingerprint; the holder remains unresolved, and ordinary Return cannot release it

#### Scenario: The device reserve commits first but its reply is lost

- **WHEN** the server commits the reservation but the reply is lost before the original desktop saves it, and that desktop reopens its `taking` journal after transfer
- **THEN** transfer leaves the committed assignment intact and the desktop's Take replay stays pending without a new owner fingerprint
- **AND** the desktop keeps its original proof and sends no release on Return. Server ESI stays blocked.
