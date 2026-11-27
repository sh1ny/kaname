# Review

## Metadata

- **Round:** 8
- **Prior round:** Round 7 approved option A with two required edits. Both passed recheck. This round also reviews the ESI SSO admission paragraph shortened after strict OpenSpec rejected its length.
- **Reviewer:** Codex
- **Reviewed:** Proposal, design, round 7 review, tasks, all three delta specs, the M3 roadmap, architecture, ADRs 0003, 0005, 0006, 0007, 0010, 0017, 0018 and 0019, applicable main specs, the Riverpod guide, the listed project skills, and current admission callers.
- **Checks:** Verified tracking and checked path components for symlinks before opening all 57 cited ranges across 18 files at `e177950`. Inspected current callers separately and measured the shortened normative paragraph at 488 characters. Strict OpenSpec validation, builds, and tests were not run. No files were written, and no network, agents, or secrets were used.

## Findings

### Critical (blocking)

None.

### Moderate

None.

- **The shortened admission requirement preserves C23.** The paragraph still requires live signing authority, denies admission at or after expiry by database UTC, and requires the exact session deletion to commit before the server confirms expiry. The scenarios preserve the pre-observation limit, the restart and lost-reply guarantee, and the explicit viewer’s unavailable result when deletion cannot commit. Work already admitted keeps its existing completion rules. [ESI SSO delta](openspec/changes/member-accounts/specs/esi-sso/spec.md#requirement-connected-operations-recheck-the-signing-session-at-admission) · [D10 and D20](openspec/changes/member-accounts/design.md#d20-end-a-session-permanently-when-expiry-is-recorded)
- **The transaction boundaries support the required ordering.** Link, make-main, and unlink check the exact acting session after acquiring its lock. The locked expiry branch can return refusal and commit only the acting session deletion. The explicit viewer, roster, own history, and handoff preparation each read authority before protected data in their respective snapshots. Roster already returns a refusal value through its transaction. Own history currently throws inside its transaction, so D20 correctly requires moving denial translation after commit. The independent lookups used by dispatch, grants, holder operations, admin paths, and ordinary authentication can use a separate bounded delete keyed to the observed row without sampling time again. Roster ingress authentication has its own transaction and follows the transactional rule. [Membership mutation](server/kaname_server/lib/src/esi/member_accounts.dart#L125) · [Session lookup](server/kaname_server/lib/src/esi/sso_sessions.dart#L106) · [Viewer](server/kaname_server/lib/src/esi/sso_route.dart#L412) · [Roster](server/kaname_server/lib/src/esi/member_roster_endpoint.dart#L34) · [Own history](server/kaname_server/lib/src/esi/esi_call_log_store.dart#L142) · [Handoff preparation](server/kaname_server/lib/src/esi/sso_handoff.dart#L74)
- **The failure outcomes and planned assertions agree.** A rollback leaves the row present. An unresolved commit or a concurrent delete that aborts an older repeatable-read transaction prevents admission and makes the explicit viewer check unavailable. A fresh snapshot can establish absence. A lost reply after commit leaves the bearer absent across restart and a backward clock step. The plan covers each roster and history snapshot separately, the post-lock sample, the survival of another live bearer, and a live lookup that completes while another transaction holds the row lock and the test database rejects session writes. These are observable outcomes with barriers and controlled time. [Verification plan](openspec/changes/member-accounts/design.md#flow--state-gaps-full) · [Test map](openspec/changes/member-accounts/tasks.md#test-map)
- **The bounds and ownership fit the chosen mechanism.** Postgres owns the durable expiry record. D20 adds at most one exact-row delete per expiry observation under short lock and statement deadlines. Ordinary live reads stay write-free and take no session row lock. The eight-live-session cap applies at issuance, and pruning remains bounded. A process-local set would lose its record on restart. A shared watermark would add write contention to live authentication. The mechanism ledger accounts for the chosen deletion and its cost. [Resource bounds](openspec/changes/member-accounts/design.md#resource-bounds-full) · [Mechanism ledger](openspec/changes/member-accounts/design.md#mechanism-ledger-full)

### Suggestions

- Name roster ingress authentication and handoff take preparation explicitly in the D20 implementation checklist. Each owns a transaction separate from the page and mutation paths, and D20 already covers both. [Roster authentication](server/kaname_server/lib/src/esi/sso_sessions.dart#L106) · [Handoff preparation](server/kaname_server/lib/src/esi/sso_handoff.dart#L74)

### Outside the approved threat model

- Restoring a database backup taken before the expiry commit can restore the session row. The normal restart guarantee uses the committed database state. [Threat model](openspec/changes/member-accounts/design.md#threat-model)

## Verdict

VERDICT: APPROVE

The shortened requirement preserves the approved expiry contract and both round 7 edits. The planned implementation and verification remain under task group 7. [Task group 7](openspec/changes/member-accounts/tasks.md#7-session-expiry-and-admission-fixes)

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals

- **Clock crossing before durable observation.** The owner accepted in item 96 that the next admission uses current database time until an expiry deletion commits. A fresh admission after commit cannot use the deleted bearer. [Threat model](openspec/changes/member-accounts/design.md#threat-model) · [C23](openspec/changes/member-accounts/design.md#carried-constraints)
- **Carried constraints.** The call-log delta still requires atomic seal advancement and pruning. Ambiguous unlink still requires confirmed exact-session deletion or absence and fresh sign-in. Session expiry leaves account identity, signing-character authority, and holder ownership governed by the existing ADRs. Flutter keeps viewer and page state in the existing notifiers, with the connected adapter distinguishing confirmed invalidity from unavailability. [Call-log delta](openspec/changes/member-accounts/specs/esi-call-log/spec.md#requirement-released-aggregate-windows-cannot-go-backward) · [Member-accounts delta](openspec/changes/member-accounts/specs/member-accounts/spec.md#requirement-an-ambiguous-unlink-requires-session-recovery) · [ADR 0019](docs/adr/0019-member-account-and-signing-identity.md) · [Riverpod guide](docs/guides/riverpod.md)