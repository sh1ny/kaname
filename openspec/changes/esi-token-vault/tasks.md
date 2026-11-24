# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| One active holder per character | Park before activating another holder | `packages/kaname_esi_vault/test/vault_test.dart` | `park invalidates the old holder before another activates` | red |
| One active holder per character | Two holders contend | `server/kaname_server/test/integration/esi/postgres_vault_test.dart` | `first activations contend across Postgres sessions` | red |
| One active holder per character | A non-holder cannot use the authority | `packages/kaname_esi_vault/test/vault_test.dart` | `non-holder and missing authority never exchange` | red |
| One active holder per character | Superseded authorization cannot read credentials | `packages/kaname_esi_vault/test/vault_test.dart` | `reauthorization fences old handles` | red |
| Credentials are encrypted and failures are secret-free | A store reader cannot read credential material | `server/kaname_server/test/integration/esi/postgres_vault_test.dart` | `Postgres holds only ciphertext through install and rotation` | red |
| Credentials are encrypted and failures are secret-free | Key missing or invalid | `packages/kaname_esi_vault/test/vault_test.dart` | `bad key fails closed before reading the store` | red |
| Credentials are encrypted and failures are secret-free | Ciphertext fails authentication | `packages/kaname_esi_vault/test/vault_test.dart` | `wrong key tampering and cross-authorization copies are unavailable` | red |
| Credentials are encrypted and failures are secret-free | Dependency error contains a secret | `packages/kaname_esi_vault/test/vault_test.dart` | `dependency failures keep secrets out of results and diagnostics` | red |
| Refresh is single-flight and commits before bearer use | Concurrent callers need a new bearer | `packages/kaname_esi_vault/test/vault_test.dart` | `same character waits for a committed rotation without duplicate exchange` | red |
| Refresh is single-flight and commits before bearer use | Bearer is too close to expiry to dispatch | `packages/kaname_esi_vault/test/vault_test.dart` | `dispatch threshold refuses and refreshes near expiry` | red |
| Refresh is single-flight and commits before bearer use | Pre-refresh leaves room for admission | `packages/kaname_esi_vault/test/vault_test.dart` | `pre-refresh has more expiry headroom than read-only dispatch` | red |
| Refresh is single-flight and commits before bearer use | An abandoned refresh lease expires | `packages/kaname_esi_vault/test/vault_test.dart` | `lease expires exactly at its deadline` | red |
| Refresh is single-flight and commits before bearer use | Different characters refresh independently | `packages/kaname_esi_vault/test/vault_test.dart` | `independent characters complete out of order` | red |
| Refresh is single-flight and commits before bearer use | Rotation save cannot be confirmed | `packages/kaname_esi_vault/test/vault_test.dart` | `lost commit acknowledgement never releases an unconfirmed bearer` | red |
| Refresh is single-flight and commits before bearer use | Superseded success salvages an unchanged credential | `packages/kaname_esi_vault/test/vault_test.dart` | `superseded success preserves rotation without publishing bearer or replacing lease` | red |
| Refresh is single-flight and commits before bearer use | Late success cannot overwrite a changed credential | `packages/kaname_esi_vault/test/vault_test.dart` | `late success cannot overwrite a new refresh token or authorization` | red |
| Resolve invalid grant from committed state | Committed rotation differs from the rejected token | `packages/kaname_esi_vault/test/vault_test.dart` | `current invalid grant retries an actual salvaged rotation once` | red |
| Resolve invalid grant from committed state | Rotated token was lost before save | `packages/kaname_esi_vault/test/vault_test.dart` | `lost rotation requires new login and is never retried` | red |
| Resolve invalid grant from committed state | The recovery retry also rejects the current credential | `packages/kaname_esi_vault/test/vault_test.dart` | `second invalid grant marks the current token dead` | red |
| Resolve invalid grant from committed state | Superseded rejection does not refresh or kill a newer credential | `packages/kaname_esi_vault/test/vault_test.dart` | `a superseded invalid grant cannot retry or kill the current grant` | red |
| Resolve invalid grant from committed state | Upstream is temporarily unavailable | `packages/kaname_esi_vault/test/vault_test.dart` | `temporary exchange failure keeps the grant usable` | red |

## 1. Implement shared encrypted vault

- [ ] 1.1 Add `kaname_esi_vault` to the pub workspace and `mise run test` fan-out so Windows/macOS/Linux CI runs it; update the exact workspace listing test. Resolve dependencies, regenerate notices, and verify workspace, licence and notices checks.
- [ ] 1.2 Write the shared package's test-map cases first. Use a hand-written atomic store, an injected clock, event barriers and a generous hang guard, never sleep or assert elapsed time. Exercise salvage by returning a synthetic exchange result through the vault, not by writing the desired token directly. Record the targeted test command and its pre-implementation failure.
- [ ] 1.3 Implement D1–D3 in pure Dart. Document the caller and refresh-exchange contracts (C1, C3, C6, C8) and verify the delta carries C2, C4 and C5. Run the package tests and scoped analysis; flip the shared test-map rows green.

## 2. Persist the server vault in Postgres

- [ ] 2.1 Verify A1 and A2 before relying on either in the adapter. Add real Postgres probes for quiet session failure (enable log capture; inject synthetic diagnostic text and assert it is not printed or persisted) and concurrent two-key/single-key advisory locks, including both forms with identical numeric bits and the existing static-data key. Use `RollbackDatabase.disabled`, distinct connections and event barriers. Run the probe file in the Linux `server` job locally when not gaming, or in that job on CI.
- [ ] 2.2 Write the Postgres test-map cases before the adapter. Exercise independent store sessions, use synthetic env-equivalent key input, inspect raw rows for absence of plaintext and key, and verify reuse and rotation with a newly constructed vault. Also verify live-lease contention across two Postgres-backed vault instances and fail-closed behavior on an injected database operation failure. Record the targeted pre-implementation failure.
- [ ] 2.3 Generate the server-only model and migration for D1, then implement the committed-snapshot store, try-lock/bounded completion seam, and opt-in server factory. Write the lock and key comments (C7, C9, C10) and the separate key backup/restore warning in `deploy/README.md`. Run targeted Postgres tests and codegen/analysis checks, verify the generated client excludes the model, and flip the remaining test-map rows green.

## Workflow follow-up

- Claude pre-ship review before the first push. Ship and watch with KintsugiBot, request Codex review as `sh1ny`, and address findings and CI on the current head.
- Archive on the PR branch, sync the capability spec, and watch the archive head's CI before handing off to the owner for merge.
