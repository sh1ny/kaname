## MODIFIED Requirements

### Requirement: Privacy-scoped call-log reads

Own reads, even for admins, SHALL require a live viewer, the receipt's account, a linked and unblocked character, and its current ownership generation. Admin aggregates show only route and error counts, without period or subgroup filters or refusals counted as errors. Private routes need five eligible accounts, configurable upward. Five full UTC days become eligible one minute after UTC midnight by database time. The server SHALL wait for the committed seal before publishing.

#### Scenario: Own rows only
- **WHEN** a viewer reads a log containing own, other and unattributed rows
- **THEN** only the viewer's own rows are returned, even when the viewer is an admin

#### Scenario: No trusted viewer or admin grant
- **WHEN** a read lacks a trusted viewer, or a non-admin requests route aggregates
- **THEN** access is denied without returning call-log data

#### Scenario: Sufficient and insufficient contributors
- **WHEN** an admin requests route totals and one route meets the contributor threshold while another falls below it
- **THEN** only the qualifying route is returned with its total and error count, with no per-character fields, period or subgroup filters, and no refusal counted as an error

#### Scenario: Character ownership changes
- **WHEN** a new member acquires a character for which a previous member has call-log rows
- **THEN** the previous member's rows do not appear in the new member's history

#### Scenario: An account can see its linked characters' receipts
- **WHEN** an unblocked linked character has a retained receipt for the viewer's account and that character's current ownership generation within the requested page, and the viewer signs in through a different linked character
- **THEN** the viewer's own history includes that receipt

#### Scenario: Linking and unlinking do not move earlier receipts
- **WHEN** a character with receipts for one account is linked to another account
- **THEN** the new account cannot read the old account's receipts for that character, and the old account cannot read receipts for that character while it is unlinked from it
- **AND** aggregate counts retain the account recorded on each receipt regardless of later roster changes

#### Scenario: Several alts of one member
- **WHEN** five characters from the same member account are the only contributors to a private route
- **THEN** the route is suppressed under a threshold of five members

#### Scenario: Stable closed periods
- **WHEN** a pre-midnight insert completes during the one-minute grace, and an admin reads before and after the next window's seal commits
- **THEN** the counts stay unchanged through the grace, and the new five-day UTC window first appears after sealing and includes the insert

#### Scenario: Public probe
- **WHEN** the only observation for a public route is a status probe in a closed day
- **THEN** the route counts include the observation without applying the private contributor threshold

#### Scenario: Unattributed authenticated call
- **WHEN** an authenticated call is recorded without a trusted member association
- **THEN** it is excluded from individual reads and from private route counts and threshold qualification

#### Scenario: Write misses its deadline
- **WHEN** a receipt stamped before midnight reaches the database after its ten-second deadline
- **THEN** no row is stored, a fixed diagnostic is reported, and the released counts do not change

#### Scenario: Slow commit spans release
- **WHEN** a pre-midnight append passed its deadline check but remains uncommitted when an admin reads counts after release
- **THEN** the read includes that row or fails unavailable, and later reads do not vary totals for that window

## ADDED Requirements

### Requirement: A transfer keeps past owners' individual receipts private

Kaname SHALL advance ownership generation on transfer and stamp every attributed receipt at ESI admission. Own reads SHALL also match the character's current generation. Existing identities and receipts SHALL start at zero. Transfer SHALL NOT rewrite, reattribute or prune receipts or change aggregate qualification or sealed windows. The existing first-exclusion rule SHALL apply to accounts the detached character starts or joins.

#### Scenario: New ownership records a readable receipt without carrying history over
- **WHEN** the transferred character completes ordinary sign-in, gets a new scoped grant and makes an ESI call
- **THEN** its new account can read the new receipt, and it cannot read individual receipts from the previous owner

#### Scenario: A transferred character rejoins a former account
- **WHEN** the character is eligible to link after transfer and rejoins a Kaname account that previously recorded receipts for it
- **THEN** the next own-history read returns only eligible receipts of the current ownership generation
- **AND** changing the hash back in a later verified transfer does not make an older generation visible again

#### Scenario: A call admitted before transfer records its receipt late
- **WHEN** a call admitted for the previous owner settles and records its receipt after transfer
- **THEN** the receipt keeps the old account, signing character, exclusion stamp and ownership generation from admission, and no new owner can read it

#### Scenario: Transfer retains the existing aggregate exclusion rule
- **WHEN** a transferred character starts or joins an account before a release cutoff
- **THEN** the first exclusion follows the same rule as other detachment, and the earlier receipts keep their original attribution and retention
- **AND** a sealed window retains the same count after restart

#### Scenario: An upgrade keeps own receipts of unchanged characters visible
- **WHEN** an existing live account reads its own eligible receipts after the upgrade with no transfer for those characters
- **THEN** the page still includes those receipts
