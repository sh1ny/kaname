# ESI SSO spec delta

## ADDED Requirements

### Requirement: The desktop restores local state after a definitively refused take

When the source confirms it made no reservation for a new desktop take, the desktop SHALL restore the prior local character state and selection. When the outcome is uncertain or the source may already have committed, the desktop SHALL keep the pending take and its original proof. Neither outcome SHALL authorize a new desktop holder without confirmed source parking.

#### Scenario: A definitive refusal restores the desktop state

- **WHEN** the server definitively refuses a new take before reserving the holder for that device proof
- **THEN** the desktop restores the character state and selection from before the take, and reports the existing blocked notice
- **AND** Return sends no take for the refused intent, and while the same connected session reports a server holder for that character, native skills authorization is blocked

#### Scenario: An uncertain take keeps the original proof

- **WHEN** the server has not confirmed whether the original device obtained a reservation, including when a reply is lost or unreadable, when a 403 lacks the fixed refusal body, or when a resumed take for an existing pending journal is refused
- **THEN** the desktop keeps the pending take and original proof across restart, and does not activate a desktop grant
- **AND** when it resumes that take it uses the same proof, so a reservation that already committed can still be recovered
