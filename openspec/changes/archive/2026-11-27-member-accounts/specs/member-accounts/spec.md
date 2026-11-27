# Member accounts

## Purpose

Give an install's connected members one Kaname account they can reach through any of their linked EVE characters. Keep account membership separate from CCP ownership and ESI holder authority.

## ADDED Requirements

### Requirement: Any linked character signs in to the same account

A connected sign-in with verified CCP character and owner claims SHALL resolve the account linked to that character. A character without an account SHALL start a new account with itself as main after successful sign-in. A character SHALL belong to at most one account. Kaname SHALL NOT infer linkage from a matching owner hash or let a blocked character sign in.

#### Scenario: First sign-in makes the signing character main

- **WHEN** a previously unknown character completes connected sign-in
- **THEN** the session reaches a new account with that character as its only member and main

#### Scenario: Main and alt resolve one account

- **WHEN** a main and an alt linked to the same account complete separate connected sign-ins
- **THEN** both sessions identify the same Kaname account and each identifies its own signing character

#### Scenario: Matching owner hash does not link another character

- **WHEN** a different character with the same verified owner hash signs in without a link attempt
- **THEN** it does not gain access to the existing account and receives its own account if it has none

#### Scenario: Concurrent first sign-ins converge

- **WHEN** two valid attempts complete sign-in for the same previously unknown character
- **THEN** every successful result reaches the same account and there is only one membership for that character

### Requirement: An upgrade preserves M2 character identities and live sessions

The M2 upgrade SHALL seed one account per M2 identity with that character as main. It SHALL preserve valid sessions with their original signing characters. It SHALL leave the verified owner, blocked status, character-specific opt-ins and holder assignments in place. An interrupted migration SHALL NOT leave a partially migrated set of accounts.

#### Scenario: Upgrading multiple M2 characters

- **WHEN** an M2 database contains separate character identities, live sessions, grants and holder assignments, including characters with the same owner hash
- **THEN** every identity has a different account, its valid sessions retain their original signing character and expiry, and the character-specific authorization and holder data still apply to the same characters

#### Scenario: Preserving blocked and expired authority during upgrade

- **WHEN** an M2 identity is blocked or an M2 session has expired at upgrade
- **THEN** the upgrade does not let the blocked character sign in, revive an expired bearer or give either access to another account

#### Scenario: An invalid legacy bearer points to a missing identity

- **WHEN** the M2 database contains a session whose signing identity is missing
- **THEN** the upgraded database rejects that bearer and still preserves live sessions with valid identities

#### Scenario: The upgrade stops partway through

- **WHEN** the upgrade fails before committing the account backfill
- **THEN** the database retains the M2 state with no partial membership or session remapping, and a successful later upgrade creates one account per identity

### Requirement: Linking requires fresh CCP proof and a live source session

Kaname SHALL start a link only for a live connected session. It SHALL require the same live session, the app and browser proofs, and fresh verified CCP authorization for the alt at completion. A matching owner hash alone SHALL NOT link a character. Linking SHALL keep the source session and character and request no ESI scopes. It SHALL NOT issue a bearer, install an ESI grant, or change holder authorization.

#### Scenario: A signed-in member links an unlinked alt

- **WHEN** a signed-in member starts a link and completes fresh CCP sign-in with an unlinked alt using the initiating session and required proofs
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

### Requirement: Only an eligible standalone account can supply an already linked alt

Fresh link proof for a character already on the source account SHALL leave membership unchanged. A character on another account SHALL move only if it is the sole linked character and the account has no durable account-owned product data, including data added by later features. Diagnostic receipts SHALL stay with their original account and SHALL NOT prevent linking. The move SHALL end the old account's sessions atomically. Refusal SHALL NOT expose information about the other account.

#### Scenario: A previously signed-in alt joins from its standalone account

- **WHEN** a member completes a fresh signed-in link for a verified character on an eligible standalone account
- **THEN** the character joins the source account as an alt, its old sessions can no longer authorize requests, and a later sign-in through the alt reaches the source account

#### Scenario: An alt cannot be taken from another multi-character account

- **WHEN** the member completes CCP proof for a character on another account with a second character attached
- **THEN** the link is refused without moving characters, changing either main or disclosing the other account

#### Scenario: A singleton account with product data cannot be absorbed

- **WHEN** the member completes fresh CCP proof for the only character on another account that still owns durable product data
- **THEN** the link is refused, and that account retains its main, sessions and product data

#### Scenario: Competing accounts try to link the same character

- **WHEN** two accounts complete fresh link attempts for the same alt concurrently
- **THEN** at most one account gains the alt, and the losing attempt neither moves an already linked character into its account nor revokes sessions belonging to the winner

### Requirement: The member selects and can replace a main

A live connected session SHALL be able to choose a non-blocked character linked to its own account as main. The account SHALL have one designated main. Changing the main SHALL NOT switch the signing character, grant admin access or alter ESI authorization or holder state.

#### Scenario: Choosing an alt as main

- **WHEN** a signed-in member makes a linked alt their main
- **THEN** both sign-in paths show the new main, and each session's signing character and existing authority stay unchanged

#### Scenario: A main change targets a character that cannot be selected

- **WHEN** a main change names an unlinked, blocked or other account's character, including a character unlinked by a concurrent request
- **THEN** Kaname refuses the invalid selection without leaving the account with a main outside its membership

### Requirement: Unlinking ends the removed character's account access

A live connected session SHALL be able to unlink a non-main character from its own account. The server SHALL revoke sessions that signed in through that character in the same committed operation. Kaname SHALL refuse to unlink the main until another main is selected. A later sign-in through the detached character SHALL NOT regain access to the old account without a fresh link. Unlinking SHALL NOT change its holder assignment, grant or opt-ins.

#### Scenario: Unlinking an alt

- **WHEN** a member unlinks an alt with live sessions
- **THEN** the alt leaves the roster, its existing sessions no longer authorize requests, other sessions remain valid, and a new sign-in through the alt starts a different account

#### Scenario: The member unlinks the alt they signed in with

- **WHEN** a signed-in alt unlinks itself while a different linked character is main
- **THEN** the app signs that session out and does not restore the old account from a late reply

#### Scenario: Unlinking leaves existing ESI authorization with the character

- **WHEN** the account unlinks a character with a server grant, an opt-in or a device holder assignment
- **THEN** those records stay bound to that character and owner, former sessions can no longer use the server grant, and a device assignment still blocks server ESI

#### Scenario: The member tries to unlink the main

- **WHEN** an unlink request names the current main, including when it is the last character or an earlier main change has lost the race
- **THEN** membership and sessions stay unchanged and the app explains that the member must select another main first

#### Scenario: The acting bearer expires before the locked unlink check

- **WHEN** an unlink's acting bearer passed initial authentication but reaches expiry before the protected check under its session lock
- **THEN** the unlink changes no membership or holder state, and the transaction commits deletion of the expired acting session
- **AND** other sessions remain valid, and the expired bearer cannot access the roster or own history after a backward database-clock step

### Requirement: Connected Settings shows the account and its characters

Connected ESI settings on web and native SHALL show the main, signing character and up to 50 linked characters per page. The server SHALL recheck the live session on every page request. Paging SHALL NOT use a cross-session roster revision token. Restarting paging after a local change SHALL fence older replies. Invalidation or server change SHALL clear the roster, and late replies SHALL NOT restore it. Kaname SHALL NOT push roster changes to other sessions or show this roster in solo mode.

#### Scenario: A linked alt opens Settings

- **WHEN** an alt signs in to an account with a different main and opens connected ESI account settings
- **THEN** the app identifies the main and signing character separately and provides the available link, main and unlink actions

#### Scenario: The roster spans more than one page

- **WHEN** a signed-in member has more than 50 linked characters and requests the next roster page
- **THEN** each page shows at most 50 characters for that account, the next page resumes after the previous cursor, and the main and signing character remain identified even if neither is on that page

#### Scenario: A late account reply crosses sign-out or server change

- **WHEN** a roster or mutation reply arrives after sign-out, session invalidation or a change of server
- **THEN** the app does not show that reply's character roster or restore its session

#### Scenario: An old page reply arrives after unlink on the same session

- **WHEN** a page-two roster response containing an alt arrives after a non-self unlink has committed and the same session has restarted at page one
- **THEN** the app discards the old page and cursor and does not restore the removed alt

### Requirement: An ambiguous unlink requires session recovery

As in **Connected Settings shows the account and its characters**, local changes SHALL fence old roster replies and cursors. After ambiguous unlink, clear and withhold roster and own history. Use the old bearer only for exact revocation at its original server. Resume after confirmed committed deletion or absence and fresh sign-in. Auth, database and transport failures do not confirm revocation. Permit retry after lost revocation acknowledgment. Do not retry unlink automatically.

#### Scenario: An old page arrives during ambiguous unlink recovery

- **WHEN** unlink has an ambiguous reply and a prior page-two reply arrives before recovery, during recovery, or after fresh sign-in
- **THEN** the app discards that reply and cursor. The first view of the fresh session reflects the settled membership

#### Scenario: Revocation orders with an unsettled unlink

- **WHEN** an unlink request is still pending when the same app asks to revoke the session
- **THEN** revocation confirms only after an already-admitted unlink settles or prevents a later unlink from using that session
- **AND** an inconclusive revocation reply leaves the roster and own history uncertain

#### Scenario: Revocation commits but its acknowledgment is lost

- **WHEN** the original server deletes the acting session but its acknowledgment is lost
- **THEN** the views remain uncertain. Retrying with the same bearer confirms that the exact session is absent, and another live session stays valid
- **AND** the app resumes those views only after fresh sign-in

### Requirement: Roster reads do not queue

The server SHALL admit at most four roster requests before bearer database authentication, and at most one in-flight roster page per authenticated account. A request outside those bounds SHALL receive typed busy without waiting or partial data. Ingress overflow SHALL start no bearer DB authentication; account overflow SHALL start no roster page work.

#### Scenario: A remaining slot admits a roster page

- **WHEN** a live session's account has no roster read running and a server slot is free
- **THEN** it can read its next bounded page

#### Scenario: The global ingress limit refuses before bearer authentication

- **WHEN** four roster requests are admitted and their bearer database lookups are held, then a fifth roster request arrives
- **THEN** it receives busy and starts neither a bearer database lookup nor a roster page

#### Scenario: The same account cannot occupy multiple page slots

- **WHEN** an account's page is held and another live session from that account asks for a page while an ingress slot remains
- **THEN** the second session receives busy and starts no page work
- **AND** a different account can use a free slot and the first account can read again once its held page settles
