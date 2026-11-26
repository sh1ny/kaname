## ADDED Requirements

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
