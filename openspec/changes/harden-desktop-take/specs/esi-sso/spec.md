# Spec delta

## ADDED Requirements

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
- **AND** it does not read an incomplete staged write as committed data

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

## MODIFIED Requirements

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
