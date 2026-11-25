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
- **THEN** the desktop restores the previous row or removes only the temporary row, restores the previous selection if the intent still owns it and the prior selection is still valid, and reports the blocked notice
- **AND** it removes only the refused intent's proof after the local transaction commits; a failed transaction leaves the intent and proof available for recovery

#### Scenario: Reconciliation and a delayed take cannot both win

- **WHEN** reconciliation of an exact intent and a delayed take for that intent reach the source in either order
- **THEN** if reconciliation confirms non-acceptance first, the delayed take cannot park or reserve the holder
- **AND** if the take committed first, the source does not confirm non-acceptance and the original proof can resume parking or recover its matching reservation

#### Scenario: An uncertain take keeps the original proof

- **WHEN** the original outcome is unconfirmed, including after a lost or malformed reply, timeout, generic refusal, later authentication rejection, wrong source, or a source that cannot prove what happened to that intent
- **THEN** the desktop keeps the pending take and original proof across restart, and does not activate a desktop grant
- **AND** when it resumes that take it uses the same proof, so a reservation that already committed can still be recovered

#### Scenario: A pre-upgrade take cannot fabricate prior state

- **WHEN** the desktop opens a pre-upgrade journal without a saved prior state for a pending take
- **THEN** it retains the original row and proof, can recover a matching reservation as before, and does not fabricate a previous character or selection
