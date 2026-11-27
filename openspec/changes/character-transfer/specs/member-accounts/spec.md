## MODIFIED Requirements

### Requirement: Linking requires fresh CCP proof and a live source session

Kaname SHALL start a link only for a live connected session. Completion SHALL require the same live session, the app and browser proofs, and fresh verified CCP authorization for the alt. A matching owner hash alone SHALL NOT link a character. A successful link SHALL keep the source session and character and request no ESI scopes. Linking SHALL NOT first claim a transferred character, issue a bearer, install an ESI grant, or change holder authorization.

#### Scenario: A signed-in member links an unlinked alt

- **WHEN** a signed-in member starts a link and completes fresh CCP sign-in with an unlinked alt using the initiating session and required proofs, and the alt is not awaiting its first sign-in after a transfer
- **THEN** the new character appears on the source account, its next connected sign-in reaches that account, and the linking session keeps its original bearer, signing character and main

#### Scenario: A canceled, stale or mismatched attempt makes no link

- **WHEN** the callback is canceled, spent, expired, misbound, or the original session has expired, signed out or been revoked before completion
- **THEN** the attempt cannot change membership, sign in as the alt or activate a grant

#### Scenario: A link proof expires while the membership transaction waits for the release lock

- **WHEN** the attempt or verified proof expires before the transaction acquires the shared release lock it needs to record a first exclusion
- **THEN** the transaction writes neither membership nor exclusion evidence

#### Scenario: An authorization for a link cannot be used for another purpose

- **WHEN** a sign-in or scope authorization proof is submitted as a link, a link proof is submitted for sign-in or scope authorization, or a link attempt arrives with another session or unrequested scopes
- **THEN** Kaname refuses the mismatched operation without giving the caller a session, membership change or ESI grant

#### Scenario: A link start or completion is refused for the current viewer

- **WHEN** the link route denies authorization to start or complete a link
- **THEN** the app rechecks the same connected session and clears its roster and own history only if the viewer check confirms the session ended
- **AND** a live or temporarily unavailable viewer check leaves the connected session in place

### Requirement: The member selects and can replace a main

A live connected session SHALL be able to choose a non-blocked character linked to its own account as main. An account with any linked characters SHALL have one designated main from that roster. An account SHALL have no main only when no characters remain after transfer. Changing the main SHALL NOT switch the signing character, grant admin access or alter ESI authorization or holder state.

#### Scenario: Choosing an alt as main

- **WHEN** a signed-in member makes a linked alt their main
- **THEN** both sign-in paths show the new main, and each session's signing character and existing authority stay unchanged

#### Scenario: A main change targets a character that cannot be selected

- **WHEN** a main change names an unlinked, blocked or other account's character, including a character detached by a concurrent request
- **THEN** Kaname refuses the invalid selection without leaving the account with a main outside its membership

## ADDED Requirements

### Requirement: Verified transfer ends the old account membership

Kaname SHALL detach the character and revoke all sessions that signed in through it in the same operation. It SHALL keep the old account and its data and leave other signers' sessions valid. If its main transfers, Kaname SHALL designate the remaining unblocked character with the lowest CCP ID, or the remaining blocked character with the lowest ID if none are unblocked. An empty account SHALL keep its ID and lose its main and sign-in path.

#### Scenario: A transferred alt leaves its account

- **WHEN** Kaname accepts a verified owner change for a linked alt
- **THEN** the alt leaves its old roster, none of its old sessions authorize new work, and the account keeps its main and sessions signed in through other characters

#### Scenario: A main transfers while other characters remain

- **WHEN** the main transfers and the old account still has other characters
- **THEN** the next roster read identifies the unblocked remaining character with the lowest CCP ID as main, without changing the account ID, signing characters or authority of remaining sessions
- **AND** if all remaining characters are blocked, the one with the lowest ID becomes main without becoming eligible to sign in

#### Scenario: The only character transfers

- **WHEN** the last character leaves an account through transfer
- **THEN** the account retains its ID and records with no main, and no sign-in through the transferred character can open that account

#### Scenario: Main selection overlaps transfer

- **WHEN** an account's main selection and a transfer for one of its characters overlap
- **THEN** the resulting main belongs to the account if it still has characters, and no successful selection after the transfer can set the detached character as main

### Requirement: Only ordinary connected sign-in first claims a transferred character

A transferred character SHALL have no new membership until ordinary connected sign-in completes for its verified owner. That sign-in SHALL start a fresh account with the character as main, including when it also detects the transfer. Kaname SHALL NOT reuse or redirect the old account. Normal linking SHALL be available after this sign-in.

#### Scenario: Connected sign-in detects the transfer and claims the character

- **WHEN** an ordinary connected sign-in completes with the required proofs and verifies a fresh owner change
- **THEN** it returns a session on a fresh account with the transferred character as its main, and the old account remains separate

#### Scenario: Link detects transfer but cannot claim the character

- **WHEN** a signed-in link is the first operation to verify the owner change, or a later link attempts to claim that character before it completes ordinary sign-in
- **THEN** the character has no attached account, the link does not issue a session or reveal the old account, and a subsequent ordinary sign-in can start a fresh account

#### Scenario: Refresh or scoped authorization detects transfer

- **WHEN** a connected scoped authorization or a server refresh is the first operation to verify a fresh owner change
- **THEN** no new account or grant is created until the new owner completes ordinary connected sign-in, and they need a separate scoped authorization to enable server ESI under the existing policy and holder rules
