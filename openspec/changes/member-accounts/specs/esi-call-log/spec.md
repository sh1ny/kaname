# ESI call log delta

## MODIFIED Requirements

### Requirement: Privacy-scoped call-log reads

Own reads, even for admins, SHALL show only the live account's receipts for linked, unblocked characters. Remote reads require a genuine viewer, never a shared key. Admin aggregates show route and error counts only, without period or subgroup filters or refusals as errors. Private routes need five eligible accounts, configurable upward. Five full UTC days become eligible one minute after UTC midnight by database time; the server SHALL wait for the committed seal before publishing.

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
- **WHEN** an unblocked linked character has a retained receipt for the viewer's account within the requested page, and the viewer signs in through a different linked character
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

### Requirement: Receipt ownership and aggregate eligibility follow recorded activity

Each receipt SHALL keep the account, signing character and exclusion status from one live admission snapshot. Link and unlink SHALL NOT reattribute receipts. For a fixed release window, the server SHALL exclude from private threshold qualification every account sharing a recorded character with another account in the window. Once a route qualifies, its totals SHALL count its attributed receipts.

#### Scenario: Independent accounts qualify the route despite other overlapping accounts
- **WHEN** five accounts with no shared recorded character and two accounts with a shared recorded character contribute attributed receipts to one private route in the release window
- **THEN** the private route qualifies and its row includes all its attributed calls

#### Scenario: One character recorded under several accounts cannot meet the threshold
- **WHEN** the only activity on a private route comes from the same character under five account IDs in one release window
- **THEN** the route is suppressed under the threshold of five

#### Scenario: Sharing observed on another route affects private qualification
- **WHEN** five apparently separate accounts contribute to a private route in one release window, and receipts on a different route show that two of the accounts shared a character in that window
- **THEN** the first route is suppressed because only three of its contributors qualify

#### Scenario: A delayed receipt keeps its admission snapshot
- **WHEN** an admitted request is held while membership changes, and another request is admitted afterward
- **THEN** the held request's receipt keeps its original account, signing character and exclusion stamp
- **AND** the later receipt uses its own live admission snapshot

### Requirement: Known membership splits do not qualify as independent accounts

Unlinking SHALL retain detachment evidence. Accounts a detached character starts or joins SHALL have durable exclusion evidence that survives retirement. New receipts SHALL stamp exclusion at admission. A window SHALL apply an exclusion only when its durable time predates the fixed cutoff. A receipt stamp SHALL NOT override the cutoff. M2 receipts SHALL keep their attribution without a detachment stamp.

#### Scenario: Alts split before any receipt for the original account
- **WHEN** five distinct alts leave one account, each starts a new account, and only those new accounts contribute to a private route
- **THEN** the route is suppressed even when the window has no receipt linking those characters to the original account

#### Scenario: A detached character joins an existing account
- **WHEN** a detached character joins another account and then leaves it again
- **THEN** that account's subsequent receipts still carry the exclusion even when a different character signs in
- **AND** an independent route that qualifies can still count those attributed receipts in its totals

#### Scenario: A join before first release excludes earlier receipts from qualification
- **WHEN** a detached character joins an existing account before the fixed release cutoff, after that account made its last call in the window
- **THEN** the account does not qualify in that window even though none of its receipts carries the exclusion
- **AND** recomputing the window after account retirement reaches the same result

#### Scenario: A pre-cutoff exclusion commits during the release read
- **WHEN** a membership transaction records an exclusion before cutoff, then commits after a release read reaches the barrier
- **THEN** a successful read excludes the account from threshold qualification

#### Scenario: A pre-cutoff exclusion rolls back during the release read
- **WHEN** a pending pre-cutoff exclusion rolls back while a release read waits at the barrier
- **THEN** the rolled-back exclusion does not change eligibility

#### Scenario: An unsettled exclusion prevents release at the lock deadline
- **WHEN** the release lock deadline expires with a pre-cutoff exclusion still uncommitted
- **THEN** the read returns unavailable and returns no aggregate rows

#### Scenario: A join at cutoff does not alter the previous window
- **WHEN** the first exclusion of an account takes effect exactly at the fixed cutoff for a window
- **THEN** that exclusion does not affect that window, even if the first aggregate read runs after the join

#### Scenario: A join after cutoff leaves a released window unchanged
- **WHEN** the first exclusion of an account takes effect after the fixed cutoff for a window and the account later retires
- **THEN** an empty-cache recomputation leaves the previous window unchanged while its receipts remain retained

#### Scenario: A stamped receipt lands in an older window after a clock step
- **WHEN** an account is first excluded at or after cutoff before the window seals, and a backward clock step puts a later stamped receipt inside that window
- **THEN** the first release does not disqualify the account for that exclusion, and later windows whose cutoff is after the recorded exclusion time still apply it

#### Scenario: Recorded eligibility does not depend on live accounts
- **WHEN** an account becomes excluded after it contributed eligible receipts, including M2 receipts, and the receipts in a previously released window do not record that exclusion
- **THEN** recalculating that window gives the same qualification and counts as before, even if the account no longer exists

### Requirement: Released aggregate windows cannot go backward

Until first seal, use database time. No append or exclusion SHALL alter a sealed window. The server SHALL recheck the durable seal before any aggregate response, including cache hits, and SHALL NOT return superseded or partial rows. A prune touching the latest sealed inputs SHALL advance the seal under the exclusive release lock in the same transaction, with one database UTC sample for eligibility and retention. If it cannot advance the seal, the batch SHALL roll back.

#### Scenario: Recomputing after a backward database-clock step
- **WHEN** a window has been released and the database clock steps backward, a new exclusion and receipt for the sealed range are attempted, and the server restarts
- **THEN** the receipt is refused, the exclusion cannot affect the sealed window, and a new read returns the same counts for that retained window

#### Scenario: The clock steps backward before the window is ever sealed
- **WHEN** the database clock passes a cutoff without sealing that window, moves back, and records an exclusion before the cutoff
- **THEN** the first seal uses the recorded database time and applies that exclusion

#### Scenario: A newer seal supersedes a pending aggregate response
- **WHEN** an aggregate calculation or cache hit selects a window and a newer seal commits before response admission
- **THEN** the request returns unavailable and contains no aggregate rows from the older window

#### Scenario: A seal cannot be confirmed
- **WHEN** the server cannot confirm a new seal before computing or returning its result
- **THEN** it returns unavailable without publishing a partial window
- **AND** a later read can use any seal that has committed but cannot move it backward

#### Scenario: Pruning advances beyond the previously sealed input
- **WHEN** a prune would remove receipts from the latest sealed window but its seal advance fails before commit
- **THEN** both the previous seal and its inputs remain intact
- **AND** when a later prune commits its seal advance and deletions, neither a backward clock step nor restart can make the server publish the superseded window

### Requirement: Account changes invalidate affected call-log access

The server SHALL recheck live admin scope before aggregate admission, including cache hits. The app SHALL clear own history and reject pending replies before sending unlink and again on any completion. An ambiguous unlink SHALL keep history unavailable until session recovery. A confirmed link SHALL also invalidate own history even if the acting session stays the same.

#### Scenario: The remaining member reads history again after unlink
- **WHEN** a member unlinks an alt and requests a new own page on the same signing session
- **THEN** the new page contains only receipts for the characters still linked and unblocked

#### Scenario: A late response cannot restore a locally removed character's history
- **WHEN** a pre-unlink own-history reply arrives after the same app has confirmed an unlink
- **THEN** the app clears its previous history view and does not display the late reply

#### Scenario: The app loses an unlink reply
- **WHEN** the same app sends unlink for an alt outside the first roster page and loses the reply while the write is still unsettled or after it commits
- **THEN** old and pending history remains hidden, and the old session cannot read a recovery page
- **AND** after confirmed old-session revocation and a fresh sign-in, the next history read starts at page one and reflects the settled membership

#### Scenario: A revoked admin cannot read cached totals
- **WHEN** an allowlisted alt's session is revoked before aggregate admission and the requested window is already cached
- **THEN** the response is denied and contains no route totals
