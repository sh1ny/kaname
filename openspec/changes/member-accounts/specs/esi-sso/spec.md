# ESI SSO delta

## MODIFIED Requirements

### Requirement: Accept only validated CCP character identity

Both modes SHALL accept only a correctly signed CCP access JWT verified against CCP's JWKS. They SHALL check the allowed signing algorithm, issuer, EVE Online audience, exact registration client ID, expiry and character subject. The server SHALL resolve the Kaname account from the verified character and owner. Each session SHALL identify that account and remain bound to its signing character. A CCP access token SHALL NOT serve as a Kaname session credential.

#### Scenario: Valid identity signs in again

- **WHEN** separate valid authorizations identify the same character and owner in the connected flow and the character is still linked to the same account
- **THEN** they resolve to the same Kaname user account and signing character, and privileges come only from server policy

#### Scenario: Invalid signature, key or claims

- **WHEN** a token has an invalid signature, an unsupported algorithm, an unknown key after a bounded JWKS update, an invalid issuer, wrong or missing audience, expired validity, malformed subject or missing owner identity
- **THEN** neither mode establishes identity, activates a credential or sends ESI work using it

#### Scenario: CCP rotates its signing key

- **WHEN** a valid token uses a new key that CCP publishes in its JWKS
- **THEN** verification can accept the token after refreshing known keys without accepting an unverified token

#### Scenario: Known character presents another owner

- **WHEN** a validated token identifies a stored character with a different owner hash during sign-in or account linking
- **THEN** the authorization cannot claim the existing user, change membership, activate the vault holder or expose private call history

#### Scenario: Definitive refresh verification rejection

- **WHEN** CCP returns a refreshed grant that definitively fails verification for the current authorization
- **THEN** the old authorization cannot supply a bearer or refresh again, re-login is required, and a signed owner conflict blocks the mismatched identity

## ADDED Requirements

### Requirement: Connected authority follows the signing character

The server SHALL derive ESI grants, opt-ins, holder authority and interim admin scope from the session's own verified signing character. A link or main change SHALL NOT grant authority held by another character on the same account.

#### Scenario: The opted-in alt keeps its own policy

- **WHEN** an alt with an applicable opt-in joins an account and signs in through that alt
- **THEN** the alt retains that opt-in and its existing holder rules, and the account's other characters do not receive the alt's opt-in

#### Scenario: An unlisted alt signs in to an account with an allowlisted main

- **WHEN** a character outside the operator's allowlist signs in to an account with an allowlisted character, including when the allowlisted character is main
- **THEN** its session does not gain admin scope, and its ESI scope and holder checks still use the character that signed in

### Requirement: Connected operations recheck the signing session at admission

A connected operation SHALL require a live session at its protected admission check. A request with an expired, revoked, blocked or detached signing session SHALL NOT start ESI work, change a holder assignment or authorize a static-data mutation. Work already admitted SHALL follow its existing completion rules.

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

- **WHEN** a refresh begun before unlink later returns verified claims for a different owner
- **THEN** the identity is blocked without restoring its former membership, changing its holder assignment or giving either owner the old account
