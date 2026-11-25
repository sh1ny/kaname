# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| esi-sso → The desktop restores local state after a definitively refused take | A definitive refusal restores the desktop state | `app/test/esi_sso/native_sso_test.dart` | `A definitive refusal restores the desktop state`; `A definitive refusal removes only the temporary character`; `A refused take leaves the connected holder gate in place` | green |
| esi-sso → The desktop restores local state after a definitively refused take | Recovery restores a refused take after interruption | `app/test/esi_sso/native_sso_test.dart` | `Recovery restores a refused take after a lost reply`; `Recovery retries a failed rollback without dropping the proof`; `Recovery preserves a newer selection` | red |
| esi-sso → The desktop restores local state after a definitively refused take | Reconciliation and a delayed take cannot both win | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | `Reconciliation prevents a delayed start from taking the holder`; `An accepted start reconciles to the same reservation` | red |
| esi-sso → The desktop restores local state after a definitively refused take | An uncertain take keeps the original proof | `app/test/esi_sso/native_sso_test.dart` | `Uncertain reconciliation keeps the original proof` | red |
| esi-sso → The desktop restores local state after a definitively refused take | A pre-upgrade take cannot fabricate prior state | `app/test/esi_sso/native_sso_test.dart` | `A pre-upgrade take cannot fabricate prior state` | red |

## 1. Settle the exact intent at the source

- [ ] 1.1 Write the HTTP regressions against the existing connected SSO test pod and real Postgres holder table before editing server code. Show that the new route does not yet reconcile. Use controlled order for each winner. Verify that a closed epoch leaves holder generation, phase, digest and vault authority unchanged, that an accepted take retains its matching reservation, and that another proof cannot claim it. Exercise a lost closure reply, generic authentication failure, an epoch past the history window, and retry of a release and a standalone join with a closure between confidential sign-in and retry. Assert both former retries still return `released`. Use awaited events, never timing.
- [ ] 1.2 Implement and document the source protocol. Add the nullable server-only `takeClosures` field and its additive migration. Generate the protocol and migration with the pinned package-local Serverpod CLI; do not hand-edit generated copies. Compare nullable offsets with `COALESCE` so existing rows match the CAS. Document C2 and C5 at their destinations and leave release, join and sign-in predicates unchanged. Run the targeted connected SSO and holder handoff tests, verify the migration on scratch Postgres and turn the server test-map row green.

## 2. Restore the desktop journal after confirmed refusal

- [ ] 2.1 Write failing native regressions first using the connected HTTP adapter, an offline keyring and a temporary SQLite store that is closed and reopened. Show that the old implementation does not restore a refused take after either a lost reply or a failed rollback transaction. Check exact row and selection restoration, selection changes that happened later, proof retention on an incomplete, timed-out, malformed, wrong-epoch or unauthenticated reply, and no fallback from a fenced intent to legacy take. Exercise an actual v1 journal without a companion, including a later successful reservation using its original proof. Compare proof identity without printing proofs or tokens.
- [ ] 2.2 Add the desktop migration, transactional snapshot and restore, typed replies and existing Take and Return reconciliation. On reservation retain the proof; after confirmed rollback commit delete only the rejected proof. Preserve legacy reservation resume and #39's first-send refusal behavior. Carry C1 in the delta spec and document C3 and C4 at their destinations. Run `app/test/esi_sso/native_sso_test.dart` and `app/test/esi_sso/skills_refusal_test.dart`, check the touched Dart files with scoped analysis and mark the desktop test-map rows green.

## Workflow follow-up

- Run Claude pre-ship review, open a PR with `Fixes #40`, and watch CI and review feedback.
- Archive on the PR branch and sync the specification before reporting readiness. The owner merges.
