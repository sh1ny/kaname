# esi-token-vault Specification

## Purpose

Keeps ESI credentials under one holder per character and makes refresh rotation recoverable without exposing credentials in storage or diagnostics.

## Requirements

### Requirement: One active holder per character

The vault SHALL allow at most one active holder per character in its authoritative store. A different holder SHALL NOT activate until the previous holder is parked. Credential use SHALL require the active holder and its current authorization generation. Store failure SHALL NOT trigger use of a different authority.

#### Scenario: Park before activating another holder

- **WHEN** the current holder parks its credential and a different holder activates a fresh authorization for the character
- **THEN** only the new holder's authorization can obtain an access token, and the parked credential cannot be used.

#### Scenario: Two holders contend

- **WHEN** two holders concurrently activate a credential for one previously unclaimed character
- **THEN** exactly one activation succeeds; the other cannot obtain a bearer or send a refresh for that character.

#### Scenario: A non-holder cannot use the authority

- **WHEN** a device authorization tries to resolve a credential in a store holding the character for a server, or the authoritative store cannot be read
- **THEN** the vault returns no bearer, sends no refresh, and does not consult a fallback store.

#### Scenario: Superseded authorization cannot read credentials

- **WHEN** the current holder re-authorizes and a request uses its previous authorization generation
- **THEN** the old authorization obtains no bearer and sends no refresh.

### Requirement: Credentials are encrypted and failures are secret-free

Persisted token material SHALL be authenticated ciphertext bound to its character and holder authorization. The vault's dedicated install key SHALL come from outside the store and SHALL NOT be persisted by the vault or reused as the scheduler key. Invalid or missing key material, unreadable ciphertext, and dependency failures SHALL fail closed with diagnostics that contain no key, token, upstream body or original exception.

#### Scenario: A store reader cannot read credential material

- **WHEN** a credential is installed or rotated and the persisted record is inspected directly
- **THEN** the record contains neither plaintext tokens nor the install key; a reconstructed vault with the correct separately supplied key can still use the credential.

#### Scenario: Key missing or invalid

- **WHEN** vault configuration is missing or malformed
- **THEN** initialization fails with a secret-free configuration error and no store or refresh call is made.

#### Scenario: Ciphertext fails authentication

- **WHEN** persisted ciphertext is corrupted, copied to a different character or authorization, or opened with the wrong key
- **THEN** the vault returns unavailable, sends no refresh and does not mark the authorization dead.

#### Scenario: Dependency error contains a secret

- **WHEN** a refresh or store dependency throws an error containing the fixture token or key
- **THEN** the observable failure and emitted diagnostics contain only a stable failure classification, not the secret or original error.

### Requirement: Refresh is single-flight and commits before bearer use

The vault SHALL reuse a bearer only with sufficient lifetime. One live refresh per character SHALL exclude competing refreshes with a busy result. A rotation SHALL commit before use of its bearer. A superseded attempt SHALL NOT return its bearer. If the same active authorization still holds the exact refresh token it presented, it SHALL commit a returned replacement refresh token that differs; otherwise it SHALL NOT change the credential.

#### Scenario: Concurrent callers need a new bearer

- **WHEN** two callers request a bearer for the same authorization after the previously issued bearer expires
- **THEN** the competitor gets busy without a duplicate exchange, and the new bearer is first obtainable after the new refresh credential commits.

#### Scenario: Bearer is too close to expiry to dispatch

- **WHEN** the clock advances until a committed bearer is within the dispatch safety margin
- **THEN** the vault does not return that bearer and attempts refresh even though the bearer has not yet expired.

#### Scenario: Pre-refresh leaves room for admission

- **WHEN** a committed bearer's remaining lifetime is above the read-only margin but not above the refresh-capable margin
- **THEN** a refresh-capable call refreshes instead of returning that bearer, and a read-only lookup at the same instant still returns it.

#### Scenario: An abandoned refresh lease expires

- **WHEN** an exchange stops before finishing and the clock reaches the lease deadline
- **THEN** a competitor that was busy before the deadline can acquire the lease and complete a refresh without the previous attempt finishing.

#### Scenario: Different characters refresh independently

- **WHEN** a character's upstream refresh is held open and a second character requests a refresh
- **THEN** the second character can complete without waiting for the first.

#### Scenario: Rotation save cannot be confirmed

- **WHEN** refresh yields a rotated credential but the vault cannot confirm its save
- **THEN** no bearer from that attempt is returned, and a later call consults committed state rather than an in-memory copy.

#### Scenario: Superseded success salvages an unchanged credential

- **WHEN** an attempt's lease expires, a competitor acquires a newer lease, and the older exchange returns a different refresh token while the store still holds the one it presented
- **THEN** the replacement refresh token commits, the older attempt returns no bearer, and the competitor's lease and the committed bearer are unchanged.

#### Scenario: Late success cannot overwrite a changed credential

- **WHEN** an older exchange succeeds after its lease is superseded and the stored refresh token or authorization has changed
- **THEN** its bearer is not returned and the committed credential is not replaced.

### Requirement: Resolve invalid grant from committed state

After `invalid_grant`, a still-current attempt SHALL re-read the credential under exclusivity and retry at most once with a different committed refresh token for the same active authorization. If the rejected token is still current, the vault SHALL mark it dead, return a re-login requirement, and not refresh again until a fresh authorization is installed. A superseded attempt SHALL NOT retry or mark a credential dead.

#### Scenario: Committed rotation differs from the rejected token

- **WHEN** the current attempt reports `invalid_grant` after a late rotation replaces the rejected token in the same active authorization
- **THEN** the current attempt retries once with that stored token and returns its bearer only after the result commits.

#### Scenario: Rotated token was lost before save

- **WHEN** a restarted vault presents the last committed token and the upstream rejects it as `invalid_grant`, with no different committed token under the lock
- **THEN** the vault marks the credential dead and returns re-login required; subsequent calls send no refresh until a new authorization is installed.

#### Scenario: The recovery retry also rejects the current credential

- **WHEN** the one recovery retry returns `invalid_grant` and the rejected credential is still current
- **THEN** the vault marks it dead without sending a third exchange.

#### Scenario: Superseded rejection does not refresh or kill a newer credential

- **WHEN** an attempt reports `invalid_grant` after its lease or authorization is superseded
- **THEN** it sends no retry and does not modify the current credential or mark it dead.

#### Scenario: Upstream is temporarily unavailable

- **WHEN** refresh fails without a definitive current `invalid_grant`
- **THEN** the vault does not mark the credential dead; a later call can use the current stored credential.
