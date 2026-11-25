# Tasks

## Test map

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| esi-sso → Each mode signs in through its own CCP registration | Confidential browser sign-in | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | Confidential browser sign-in | green |
| esi-sso → Each mode signs in through its own CCP registration | Native desktop sign-in | `app/test/esi_sso/native_sso_test.dart` | Native desktop sign-in | green |
| esi-sso → Each mode signs in through its own CCP registration | Replayed, misrouted or abandoned callback | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | Replayed, misrouted or abandoned callback | green |
| esi-sso → Each mode signs in through its own CCP registration | User cancels or callback cannot listen | `app/test/esi_sso/native_sso_test.dart` | User cancels or callback cannot listen | green |
| esi-sso → Connected sign-in verifies the consenting browser | Web and native connected completion | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | Web and native connected completion | green |
| esi-sso → Connected sign-in verifies the consenting browser | A forwarded authorization link cannot yield a session | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | A forwarded authorization link cannot yield a session | green |
| esi-sso → Connected sign-in verifies the consenting browser | One client cannot fill the global attempt capacity | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | One client cannot fill the global attempt capacity | green |
| esi-sso → Accept only validated CCP character identity | Valid identity signs in again | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | Valid identity signs in again | green |
| esi-sso → Accept only validated CCP character identity | Invalid signature, key or claims | `packages/kaname_esi_sso/test/ccp_jwt_test.dart` | Invalid signature, key or claims | green |
| esi-sso → Accept only validated CCP character identity | CCP rotates its signing key | `packages/kaname_esi_sso/test/ccp_jwt_test.dart` | CCP rotates its signing key | green |
| esi-sso → Accept only validated CCP character identity | Known character presents another owner | `server/kaname_server/test/integration/esi/connected_sso_test.dart` | Known character presents another owner | green |
| esi-sso → Accept only validated CCP character identity | Definitive refresh verification rejection | `server/kaname_server/test/integration/esi/vault_refresh_verification_test.dart` | Definitive refresh verification rejection | green |
| esi-sso → Configured scope policy fails closed | Enabled module and permitted classes | `packages/kaname_esi_sso/test/scope_policy_test.dart` | Enabled module and permitted classes | green |
| esi-sso → Configured scope policy fails closed | Missing policy or optional opt-in | `packages/kaname_esi_sso/test/scope_policy_test.dart` | Missing policy or optional opt-in | green |
| esi-sso → Configured scope policy fails closed | Unconfigured solo signs in without skills access | `app/test/esi_sso/native_sso_test.dart` | Unconfigured solo signs in without skills access | green |
| esi-sso → Configured scope policy fails closed | Grant differs from the permitted request | `packages/kaname_esi_sso/test/scope_policy_test.dart` | Grant differs from the permitted request | green |
| esi-sso → An active holder can read character skills | Scoped read in both modes | `server/kaname_server/test/integration/esi/scoped_skills_test.dart`; `app/test/esi_sso/native_sso_test.dart` | Scoped read in both modes; Unconfigured solo signs in without skills access | green |
| esi-sso → An active holder can read character skills | No authority or no scope | `server/kaname_server/test/integration/esi/scoped_skills_test.dart`; `app/test/esi_sso/native_sso_test.dart` | No authority or no scope; Unconfigured solo signs in without skills access | green |
| esi-sso → Handoff parks the source before activating the destination | Take a server-held character solo | `server/kaname_server/test/integration/esi/holder_handoff_test.dart` | Take a server-held character solo | green |
| esi-sso → Handoff parks the source before activating the destination | Return a device-held character to the server | `server/kaname_server/test/integration/esi/holder_handoff_test.dart` | Return a device-held character to the server | green |
| esi-sso → Handoff parks the source before activating the destination | Mismatch, replay or competing destination | `server/kaname_server/test/integration/esi/holder_handoff_test.dart` | Mismatch, replay or competing destination | green |
| esi-sso → Handoff parks the source before activating the destination | Interruption at handoff | `server/kaname_server/test/integration/esi/holder_handoff_test.dart`; `app/test/esi_sso/native_sso_test.dart` | Interruption at handoff; Unconfigured solo signs in without skills access | green |
| esi-sso → Handoff parks the source before activating the destination | Original device cannot prove it parked | `server/kaname_server/test/integration/esi/holder_handoff_test.dart` | Original device cannot prove it parked | green |
| esi-sso → Handoff parks the source before activating the destination | A standalone device joins the server | `server/kaname_server/test/integration/esi/holder_handoff_test.dart`; `app/test/esi_sso/native_sso_test.dart` | A standalone device joins the server; Unconfigured solo signs in without skills access | green |
| esi-sso → Sign-in and handoff keep credentials out of diagnostics | Successful login and later refresh | `server/kaname_server/test/integration/esi/vault_refresh_verification_test.dart` | Successful login and later refresh | red |
| esi-sso → Sign-in and handoff keep credentials out of diagnostics | Secret-bearing upstream or malformed input | `server/kaname_server/test/integration/esi/sso_secret_sentinel_test.dart` | Secret-bearing upstream or malformed input | red |
| esi-call-log → The connected app reads the viewer's ESI call log | A member pages through their own calls | `server/kaname_server/test/integration/esi/call_log_endpoint_test.dart` | A member pages through their own calls | green |
| esi-call-log → The connected app reads the viewer's ESI call log | An admin reads both views | `server/kaname_server/test/integration/esi/call_log_endpoint_test.dart` | An admin reads both views | green |
| esi-call-log → The connected app reads the viewer's ESI call log | An anonymous or forged viewer requests data | `server/kaname_server/test/integration/esi/call_log_endpoint_test.dart` | An anonymous or forged viewer requests data | green |
| esi-call-log → The connected app reads the viewer's ESI call log | A reply arrives after sign-out or server change | `app/test/esi_sso/call_log_notifier_test.dart` | A reply arrives after sign-out or server change | green |
| esi-call-log → The connected app reads the viewer's ESI call log | Log reads reach the server work limit | `server/kaname_server/test/integration/esi/call_log_endpoint_test.dart` | Log reads reach the server work limit | green |
| esi-call-log → The connected app reads the viewer's ESI call log | Admins read the same released window | `server/kaname_server/test/integration/esi/call_log_endpoint_test.dart` | Admins read the same released window | green |
| static-data-admin → Static-data mutations require an authenticated admin | Scoped admin action | `server/kaname_server/test/integration/static_data/admin_scope_test.dart` | Scoped admin action | green |
| static-data-admin → Static-data mutations require an authenticated admin | Anonymous, non-admin or former key holder | `server/kaname_server/test/integration/static_data/admin_scope_test.dart` | Anonymous, non-admin or former key holder | green |
| static-data-admin → Public answers carry only public reasons | Stored reason with a URL | `server/kaname_server/test/integration/static_data/static_data_status_test.dart` | a stored reason with a CCP URL and socket address is shown as a public reason with neither in the answer | green |
| static-data-admin → Public answers carry only public reasons | Failed import with a path in its error | `server/kaname_server/test/integration/static_data/static_data_status_test.dart` | a failed import with a scratch path shows a public reason and no path | green |
| static-data-admin → Public answers carry only public reasons | Admin key set | `server/kaname_server/test/integration/static_data/admin_rpc_privacy_test.dart` | admin HTTP authorizes only the bearer and does not log either credential | green |
| static-data-admin → Anyone can read an admin job by its id | Job running | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | the operation call for an importing update now answers kind update now, state running | green |
| static-data-admin → Anyone can read an admin job by its id | Two admins | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | X stays ended switched after another admin's rollback ends | green |
| static-data-admin → Anyone can read an admin job by its id | Late refusal | `server/kaname_server/test/integration/static_data/admin_endpoint_test.dart` | an unanswered worker retains its slot and the operation RPC reads its late lock refusal | green |
| static-data-admin → Anyone can read an admin job by its id | Worker exits before any commit | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | worker exit before any commit keeps builds unchanged | green |
| static-data-admin → Anyone can read an admin job by its id | Worker exits after staging | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | worker exit after staging leaves N+1 staged | green |
| static-data-admin → Anyone can read an admin job by its id | Commit still running when the worker exits | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | a worker exit during switch COMMIT waits for the row fence | green |
| static-data-admin → Anyone can read an admin job by its id | Postgres down while settling | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | a two-minute outage retries within 30 seconds and holds the slot until settlement commits | green |
| static-data-admin → Anyone can read an admin job by its id | Worker exits after the switch commits | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | a worker stop after the switch commits keeps the record and no check, and settles X switched requesting refresh | green |
| static-data-admin → Anyone can read an admin job by its id | Worker hangs after the switch commits | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | row watch settles a committed X without the reply, but keeps the worker gated and shows a stall only after its lock is gone | green |
| static-data-admin → Anyone can read an admin job by its id | Running job loses its lock and hangs | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | a running X that lost its lock shows stuck and stays open even while a different backend holds the lock | green |
| static-data-admin → Anyone can read an admin job by its id | Worker setup fails and hangs | `server/kaname_server/test/integration/static_data/admin_operation_settler_test.dart` | a waiting X with no reply holds the slot and shows stuck at 5 min | green |
| static-data-admin → Anyone can read an admin job by its id | Commit acknowledgement lost | `server/kaname_server/test/integration/static_data/commit_unknown_test.dart` | a rollback commit with a lost acknowledgement ends X rolled back | green |
| static-data-admin → Anyone can read an admin job by its id | Server restarts mid-job | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | recovery orders a rollback still committing when the server stops (commits: false) | green |
| static-data-admin → Anyone can read an admin job by its id | Commit in flight at the stop | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | recovery orders a rollback still committing when the server stops (commits: true) | green |
| static-data-admin → Anyone can read an admin job by its id | Store still committing at a crash | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | recovery waits for a committing old admission store and then ends the inserted row before opening | green |
| static-data-admin → Anyone can read an admin job by its id | Start-up check fails | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | recovery opens admission although the start-up sweep fails | green |
| static-data-admin → Anyone can read an admin job by its id | Recovery close stays pending | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | a recovery orphan blocks retries for two minutes and reports stuck | green |
| static-data-admin → Anyone can read an admin job by its id | Recovery commit lands after abandonment | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | an abandoned recovery COMMIT that lands does not open admission until a successor commits | green |
| static-data-admin → Anyone can read an admin job by its id | Admin call during start-up recovery | `server/kaname_server/test/integration/static_data/admin_endpoint_test.dart` | recovery gates both new jobs and replays but not a setting write | green |
| static-data-admin → Anyone can read an admin job by its id | Many operation reads | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | a fifth operation read with four running answers operation read busy | green |
| static-data-admin → Anyone can read an admin job by its id | Unconfigured during start-up recovery | `server/kaname_server/test/integration/static_data/admin_scope_test.dart` | Unconfigured during start-up recovery | green |
| static-data-admin → Anyone can read an admin job by its id | Unknown id | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | never-stored and expired ids answer unknown operation | green |
| static-data-admin → Anyone can read an admin job by its id | Old job ended recently | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | a job stored 40 days ago and ended 10 days ago answers ended with its outcome | green |
| static-data-admin → Anyone can read an admin job by its id | Old settler dies waiting for the lock | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | an old settler stopped while waiting for its shared admission lock sends no upsert | green |
| static-data-admin → Anyone can read an admin job by its id | Old settler dies with its upsert in flight | `server/kaname_server/test/integration/static_data/admission_recovery_test.dart` | recovery waits for the old settler upsert in flight (both commit and abort) | green |
| static-data-admin → Anyone can read an admin job by its id | Old open job | `server/kaname_server/test/integration/static_data/admin_operation_test.dart` | an open job stored 40 days ago answers its state and is kept | green |
| static-data-settings → Static-data controls follow the current admin session | Signed-in admin sees controls | `app/test/static_data/static_data_section_test.dart` | Signed-in admin sees controls without a credential field | green |
| static-data-settings → Static-data controls follow the current admin session | Sign-out or revoked scope | `app/test/static_data/static_data_section_test.dart` | Sign-out or revoked scope hides actions without dropping a followed job | green |
| static-data-settings → Static-data controls follow the current admin session | Insecure remote connection | `app/test/static_data/static_data_section_test.dart` | Insecure remote connection still shows the status but not actions | green |
| static-data-settings → Static-data controls follow the current admin session | Delayed denial from an older session | `app/test/static_data/admin_session_notifier_test.dart` | Delayed denial from an older session leaves the new admin authorized | green |
| static-data-settings → Static-data controls follow the current admin session | Server cannot grant admin access | `app/test/static_data/static_data_section_test.dart` | Server cannot grant admin access | green |
| static-data-settings → Static-data controls follow the current admin session | Local stack | `app/test/static_data/static_data_section_test.dart` | Local stack shows actions after admin sign-in | green |
| static-data-settings → An admin can act from the section | Update now | `app/test/static_data/static_data_section_test.dart` | Update now answered started shows work running, hides the actions and follows | green |
| static-data-settings → An admin can act from the section | Resent action answers ended | `app/test/static_data/admin_session_notifier_test.dart` | a resend answered ended rolled back is final and releases the job | green |
| static-data-settings → An admin can act from the section | No answer yet | `app/test/static_data/static_data_section_test.dart` | no answer yet shows watching the server and follows the job | green |
| static-data-settings → An admin can act from the section | Roll back confirmed | `app/test/static_data/static_data_section_test.dart` | a confirmed rollback sends the shown revision and shows N active and N+1 held | green |
| static-data-settings → An admin can act from the section | Builds changed | `app/test/static_data/admin_session_notifier_test.dart` | builds changed shows its message and reads the status at once | green |
| static-data-settings → An admin can act from the section | Rollback outcome unknown | `app/test/static_data/admin_session_notifier_test.dart` | rollback outcome unknown follows X until it ends or 10 min pass | green |
| static-data-settings → An admin can act from the section | Rollback failed | `app/test/static_data/static_data_section_test.dart` | rollback failed shows the reason in text and the builds unchanged | green |
| static-data-settings → An admin can act from the section | Roll back cancelled | `app/test/static_data/static_data_section_test.dart` | cancelling the rollback confirmation makes no call | green |
| static-data-settings → An admin can act from the section | Action refused | `app/test/static_data/static_data_section_test.dart` | import running, worker not running and update failed show in text and the actions return when idle | green |
| static-data-settings → An admin can act from the section | Toggle not saved | `app/test/static_data/admin_session_notifier_test.dart` | setting not saved restores the switch and shows Setting not saved | green |
| static-data-settings → An admin can act from the section | Stale status after a toggle | `app/test/static_data/admin_session_notifier_test.dart` | a status read begun before the toggle answer leaves the switch off | green |
| static-data-settings → An admin can act from the section | Status read in flight across a toggle | `server/kaname_server/test/integration/static_data/auto_update_setting_test.dart` | a status read in flight across a toggle can finish late but cannot refill the status cache | green |
| static-data-settings → An admin can act from the section | Admin busy | `app/test/static_data/admin_session_notifier_test.dart` | admin busy on a first press releases it and follows nothing | green |
| static-data-settings → An admin can act from the section | Late toggle answer after a new toggle | `app/test/static_data/admin_session_notifier_test.dart` | a late W1 answer after W2 started only offers its revision | green |
| static-data-settings → An admin can act from the section | Key check unanswered | `app/test/static_data/static_data_section_test.dart` | Key check unanswered: no legacy input or retry | green |
| static-data-settings → An admin can act from the section | Late resend answer after a new press | `app/test/static_data/admin_session_notifier_test.dart` | a late resend answer ended for X after Y was pressed is dropped; a late resend answer noAnswerYet for X after Y was pressed is dropped | green |
| static-data-settings → An admin can act from the section | Toggle Retry refused | `app/test/static_data/admin_session_notifier_test.dart` | a refused Retry keeps Not confirmed with the refusal beside it | green |
| static-data-settings → An admin can act from the section | Status read at the old revision | `app/test/static_data/admin_session_notifier_test.dart` | a status read at revision R shows the stored value and keeps Not confirmed | green |
| static-data-settings → An admin can act from the section | Setting changed elsewhere | `app/test/static_data/admin_session_notifier_test.dart` | setting changed shows the stored value and its message | green |
| static-data-settings → An admin can act from the section | Toggle refused as busy | `app/test/static_data/admin_session_notifier_test.dart` | admin busy on a first toggle restores the switch | green |
| static-data-settings → An admin can act from the section | Resend refused while following | `app/test/static_data/admin_session_notifier_test.dart` | a refused resend shows the refusal beside waiting and does not release X | green |
| static-data-settings → An admin can act from the section | Toggle answer lost | `app/test/static_data/admin_session_notifier_test.dart` | a lost or not-confirmed toggle shows Not confirmed with Retry resending the same write | green |
| self-host-stack → Caddy routes the confidential SSO callback to Kaname | Browser returns to a configured self-host | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Browser returns to a configured self-host | red |
| self-host-stack → Caddy routes the confidential SSO callback to Kaname | Callback cannot be processed | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Callback cannot be processed | red |
| self-host-stack → Caddy routes the confidential SSO callback to Kaname | Owner uses the loopback stack without TLS | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Owner uses the loopback stack without TLS | red |
| self-host-stack → Caddy routes the confidential SSO callback to Kaname | Plain HTTP is configured for a non-local host | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Plain HTTP is configured for a non-local host | red |
| self-host-stack → Confidential SSO credentials reach only the running server | Fully configured opt-in | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Fully configured opt-in | red |
| self-host-stack → Confidential SSO credentials reach only the running server | Missing registration or vault key | `server/kaname_server/test/integration/esi/self_host_sso_test.dart` | Missing registration or vault key | red |

## 1. Architecture and prerequisites

- [x] 1.1 Write ADRs 0017 and 0018 and update the architecture index. Carry C3, C4, C7, C10 and C12; verify the index lists 0018 as superseding 0015 and the M7 reclaim decision remains visible.
- [x] 1.2 Verify A1 against CCP documentation and the local stack origin. Record the exact redirect check for both registrations in the owner check; do not use real credentials in automated tests.
- [x] 1.3 Verify A2 against CCP's documented owner claim; include equality across the two registrations in the owner check and rejection in the handoff fixtures. If the owner check disproves it, stop before archive and report design drift.
- [x] 1.4 Verify A3 against the pinned desktop toolchain, SQLite 3.9.1 and the OS secure-storage adapter. Exercise opening and reconstructing the credential store; do not treat a build alone as secure-store read-back.

## 2. Shared CCP verification and scope policy

- [x] 2.1 Add and run failing JWT and scope-policy tests using synthetic signed grants and an injected clock. Verify the failures from the corresponding test-map rows.
- [x] 2.2 Implement the shared CCP transport, signature and claim checks, JWKS cache and typed policy. Carry C6. Run the shared package tests and the workspace purity check; update the package configuration and dependency notices.

## 3. Connected identity and credential handling

- [x] 3.1 Add and run failing connected SSO, vault refresh and secret-sentinel tests. Cover consent in a different browser, cookie and native code proof, rate caps, callback replay, identity mapping and rotated grant rejection. Verify each fails on the expected missing behavior.
- [x] 3.2 Implement confidential exchange, callback and redemption, identity and scoped Kaname sessions, opt-in records, vault refresh verification and secret-free boundaries. Carry C8, C9 and C11. Generate protocol and migrations; run the mapped HTTP and vault tests against faked CCP with no live credentials. Document the configuration and public failures.

## 4. Native sign-in, holder handoff and scoped skills

- [x] 4.1 Add and run failing native sign-in, scoped skills and handoff tests. Use event barriers for dispatch and park, an injected clock, and reconstructed stores to cover restart, cancellation, non-holder dispatch, wrong destination, standalone join and lost-device refusal.
- [x] 4.2 Implement desktop PKCE, the credential-only store and Settings account controls. Wire both holder gates and the generated skills operation through the existing scheduler and vault. Carry C1 and C2. Run the native and combined handoff/call tests, including the browser and desktop launch paths using fakes. Document return, device loss and safe backup restore in deploy/README.md.

## 5. Call-log reads and static-data admin cutover

- [x] 5.1 Add and run failing connected-call-log RPC, app log state, scoped admin and Settings tests. Cover stale responses, bounded reads and fixed aggregates, revoked/no admin scope, legacy key rejection, local and remote connection rules.
- [x] 5.2 Implement scoped projections and app display through the existing call-log store; carry C5. Replace every static-data key caller and remove the old gate, protocol fields, UI strings and config. Re-run the new tests and the carried static-data rows; update operator and upgrade guidance.

## 6. Deployment and acceptance

- [ ] 6.1 Add and run failing stack tests for callback routing, local opt-in, disabled remote HTTP and server-only credential injection. Verify the tests exercise the real Compose/proxy routing and named failures.
- [ ] 6.2 Wire Caddy and the deployment settings, including the scope policy in the server container only; verify the stack tests and strict OpenSpec validation. Publish the local setup guide with both exact redirects and the skills-read steps, using only example values.
- [ ] 6.3 Run the repository's required CI-equivalent checks or verify the same checks run on the PR head. Verify generated Serverpod artefacts, locale output, notices and all enabled platform targets. Before any heavy local run, check the owner's gaming guard.
- [ ] 6.4 [user] Register the stack at `http://localhost/auth/esi/callback` and native solo at `http://localhost:48175/auth/esi/callback`. Follow the local acceptance guide: sign in on the loopback stack, read skills and see the own call-log entry; take the same character to the native device and read skills through PKCE. Confirm matching identity and that connected mode cannot dispatch while the device holds the character. Enter secrets only on the test machine.

## Workflow follow-up

- Run Claude pre-ship review and Specwright PR watch. After the owner ticks 6.4 and the PR is eligible, sync the deltas and update the two stale static-data purpose lines, archive on the PR branch, push, and recheck the archive head. The owner merges.
