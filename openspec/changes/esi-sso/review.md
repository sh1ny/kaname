# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 returned REVISE with two Critical findings (C1 consent was not bound to the initiator, C2 policy and module inputs had no source), five Moderate (M1–M5) and seven Suggestions (S1–S7).
- **Reviewer:** cross-model CLI (isolated Claude CLI, Opus 5.5 `claude-opus-5-5`)
- **Reviewed:** `openspec/changes/esi-sso/proposal.md` (including owner decision S5), `design.md`, `specs/esi-sso/spec.md`, `specs/esi-call-log/spec.md`, `specs/self-host-stack/spec.md`, `specs/static-data-settings/spec.md`, `specs/static-data-admin/spec.md`, round-1 `review.md`; `openspec/roadmap.md`; `openspec/architecture.md`; `openspec/schemas/specwright/templates/review.md`; `docs/adr/0005-run-modes-and-one-token-holder.md`; `docs/adr/0007-esi-access-platform.md:47`; `docs/adr/0015-interim-install-admin-key.md:16-18`; `openspec/specs/static-data-settings/spec.md:196-255`; `packages/kaname_esi_vault/lib/src/contract.dart`; `server/kaname_server/lib/server.dart`; `server/kaname_server/lib/src/esi/esi_call_log_store.dart`; `server/kaname_server/lib/src/network/client_identity.dart`; `app/lib/shell/logic/slot_registry.dart`; `app/lib/main.dart`; `app/lib/server/data/server_address.dart`; `deploy/compose.yaml`; `deploy/Caddyfile`; `mise.toml` (stack tasks); `pubspec.lock:1118-1157`.
- **Narrow recheck:** This pass re-checked only Required Changes 1–3 against the current `design.md`, `specs/static-data-settings/spec.md` and `specs/esi-sso/spec.md`. It is not a fresh full review. No files were written and no commands were run.

I checked the new Context citations against their ranges, and each one matches:
- `slot_registry.dart:14-34` (navigation metadata only);
- `client_identity.dart:23-39` (IPv6 grouped by /64);
- `compose.yaml:110-120` (Caddy published only on `127.0.0.1:80`);
- `pubspec.lock:1125-1132` (`sqlite3` 3.9.1, transitive).

ADR compatibility holds:
- ADR 0005:22-26 (one holder, no connected fallback, park on handoff) is preserved by D4.
- ADR 0007:47 is now realised as the custom-handler seam in D2.
- ADR 0015:18 (one `authenticationHandler` per pod) agrees with D2's construction-time install. `server.dart:24,34` shows that tests pass their own pod to `serve`, so the D2 requirement that tests construct it is the right constraint.

The scenario title kept inside the MODIFIED static-data requirements is a tooling constraint, not a finding.

**Prior findings**

- **C1: fixed, accepted.**
  - D1 binds the web flow with a `__Host-` attempt cookie, and native connected completion uses a one-time code issued to the consenting browser together with the app secret (`design.md:31-32`).
  - Nothing commits until both proofs verify (`design.md:32,233`).
  - New requirement and scenarios: `specs/esi-sso/spec.md:31-43`. Failure row: `design.md:205`. Carried as C11: `design.md:122`.
- **C2: fixed, accepted.**
  - Typed `personalSkills` → `characterSkills` declaration in the pure-Dart package, plus a typed `KANAME_ESI_SCOPE_POLICY` that fails closed (`design.md:51`).
  - The desktop personal policy and opt-in are written only by an explicit Settings control (`design.md:52`).
  - The absence of a source today is stated (`design.md:24`), and there is a scenario for an unconfigured solo install (`specs/esi-sso/spec.md:95-98`).
- **M1: fixed, accepted.** The refresh interface receives the authorization handle, and a definitive mismatch marks the authorization dead with no retry and records an owner conflict (`design.md:53`). Failure row: `design.md:209`. Scenario: `specs/esi-sso/spec.md:75-78`. The new reply variant extends the sealed `VaultRefreshReply` (`contract.dart:92-118`), so exhaustive switches will flag every consumer.
- **M2: fixed, accepted.** 4 live attempts per client key and 128 per install, keyed by the existing trusted client key (`design.md:224`). Scenario: `specs/esi-sso/spec.md:45-48`.
- **M3: fixed, accepted.**
  - Per-viewer and server admission plus a single-flight cache per released window (`design.md:54,229`; `specs/esi-call-log/spec.md:27-35`).
  - Caching is sound. Appends are fenced to about 10 s of wall time (`esi_call_log_store.dart:95-96`), and the release barrier precedes the scan (`:189-198`). The 5-day window ending at the release boundary (`:185-187`) lies inside the 7-day prune cutoff (`:261`), so a released window cannot change after it is cached.
- **M4: resolved by owner decision S5, accepted.** The assignment stays blocked in M2 (`proposal.md:71-77`). Failure row: `design.md:215`. Scenario: `specs/esi-sso/spec.md:144-147`. Carried as C12: `design.md:123`. Risk: `design.md:255`.
- **M5: fixed, accepted.** C10 (`design.md:121`), carried into `deploy/README.md` (`design.md:270`).
- **S1–S6: addressed.** S1–S3 in D2 (`design.md:42`), S4 in D1 (`design.md:33`), S5 in D4 (`design.md:65`), S6 in A3 (`design.md:108`).
- **S7: addressed in part, accepted.** The title stays for the OpenSpec reason given. The unconfigured display now has its own scenario (`specs/static-data-settings/spec.md:23-25`).

## Findings

### Critical (blocking)

None.

### Moderate

**M6. The owner-acceptance scope policy, as written, is malformed JSON under Compose's `.env` rules, so the S1 owner check cannot authorize skills.**
- Where: `design.md:262` sets `KANAME_ESI_SCOPE_POLICY='{\"revision\":1,…}'`. `mise.toml:328` runs `docker compose --file deploy/compose.yaml`, which reads `deploy/.env`. Compose takes single-quoted values literally, so the backslashes stay in the value.
- Trace:
  1. The server receives `{\"revision\":1,...}`, which is not valid JSON.
  2. D3 (`design.md:51`) says malformed config grants nothing and turns off new ESI authorizations.
  3. At "authorize skills" (`design.md:264`), the owner gets a fixed failure and cannot complete either half of S1 (`proposal.md:41`, `roadmap.md:18`).
- Related gap: the `server` service environment (`compose.yaml:89-95`) passes neither the new non-secret settings nor drops `SERVERPOD_PASSWORD_adminKey` (`compose.yaml:91`). `design.md:262` says only that Compose passes "the two secrets".
- Fix: see Required Change 1.

**M7. The static-data delta drops the existing rule for loopback HTTP, so whether the owner's `http://localhost/` stack or `server:dev` at `http://localhost:8080/` shows admin controls is undefined.**
- Where:
  - The new requirement says "only on a secure connection" without defining it (`specs/static-data-settings/spec.md:5`). Its only scenario covers a *remote* plain-HTTP server (`:15-17`).
  - The definition ("https or http to this machine (127.0.0.1, ::1, localhost)") and the "Local development" scenario for `http://localhost:8080/` lived in the REMOVED requirement (`openspec/specs/static-data-settings/spec.md:204,242-244`). With it went the "Admin actions need a secure connection" text (`:238-240`).
  - Meanwhile D1/D2 allow local HTTP sign-in only on exactly `http://localhost/`, with no arbitrary port (`design.md:34,43`).
- Consequence: an implementer must guess whether loopback counts as secure.
  - If it does not count, admin controls are unreachable on the owner's local stack, even though D2 allows the session there.
  - If it counts for any loopback port, the app offers sign-in against `server:dev`, where the fixed callback on port 80 can never complete.
  - Either way, the previously specified "Local development" behaviour changes with no scenario. The app-side rule for which plain-HTTP targets may carry a session is also unstated, but the owner check depends on it (`design.md:264`).
- Fix: see Required Change 2.

**M8. D4's standalone-device join path has no spec scenario, and "unclaimed server identity" is undefined.**
- Where: `design.md:64` ("A previously standalone device uses the same explicit join ordering against an unclaimed server identity … A known different assignment never takes this path"). The Handoff requirement's scenarios (`specs/esi-sso/spec.md:124-147`) cover server→device, *return* of a character that came from the server, mismatch, interruption and a lost device. None covers a device that never had a server assignment.
- Why it matters: S3 rejects "a second independent login for an already held character" (`proposal.md:58`). This path is therefore the only way a solo-held character reaches the server without overlapping holders.
- Consequence: this durable cross-install transition, with high reversal cost and close to M7's Solo to join (`roadmap.md:39`, `docs/adr/0005-run-modes-and-one-token-holder.md:27-30`), has no assertable outcome. The boundary between "unclaimed" and "known assignment" is left to apply. For example, it is unclear whether an identity row with no assignment, or a `ServerReserved` row, qualifies.
- Fix: see Required Change 3.

### Suggestions

- **S8.** D2 derives `Scope.admin` from "a non-secret operator allowlist" (`design.md:42`) but does not name its variable, format or malformed-input behaviour. The self-host-stack delta does not mention it either (`specs/self-host-stack/spec.md:23-33`). Name it in D2, for example a list of positive character IDs. Treat malformed input as no admins, with the public `adminConfigured` false. Wire it into the `server` service only.
- **S9.** T2 (`design.md:142-155`) mixes device-only states (`DeviceHeld`, `Returning`) with server states. It also lacks the server edge `DeviceReserved → ServerReserved` that D4's cancellation before native activation needs (`design.md:66`). Add that edge, or split the diagram into server and device views, so restart tests can name each server phase.
- **S10.** "Require the configured origin for begin, callback and redemption" (`design.md:34`) could be read as requiring an `Origin` header. Native `dart:io` clients send none, so a literal reading would break native connected sign-in in the owner check. Say that the effective scheme and host come from the request through the trusted proxy (`compose.yaml:92-95`), and that a browser `Origin` header, when present, must match.
- **S11.** For server→device handoff, D3 says the desktop opt-in is recorded "for the validated character" (`design.md:52`). D4 validates the native JWT only after the reservation (`design.md:63`). State which validation the opt-in binds to before the scoped native request, and so whether the owner sees one or two CCP prompts at "local permissions and PKCE prompts" (`design.md:265`).

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. In `design.md:262`:
   - Replace the policy assignment with `KANAME_ESI_SCOPE_POLICY='{"revision":1,"enabledModules":["personalSkills"],"classes":{"characterSkills":"required"}}'` (no backslashes).
   - Replace "Compose passes the two secrets only to the running server." with: "Compose passes the two secrets, `KANAME_ESI_SSO_CLIENT_ID`, `KANAME_ESI_SSO_REDIRECT_URI`, `KANAME_ESI_SSO_ALLOW_LOCAL_HTTP` and `KANAME_ESI_SCOPE_POLICY` only to the `server` service, and no longer passes `SERVERPOD_PASSWORD_adminKey` (`deploy/compose.yaml:91`)."
2. In `specs/static-data-settings/spec.md:5`:
   - Replace "only on a secure connection" with "only over https, or over http to this machine (127.0.0.1, ::1, localhost)".
   - Extend the "Insecure remote connection" THEN (`:17`) with: "and shows \"Admin actions need a secure connection\"".
   - Add the scenario "Local stack": **WHEN** the server address is `http://localhost/api/` and the current session has admin scope, **THEN** the section shows the admin controls.
   - Add one sentence to `design.md` Risks (`:254-256`): "`server:dev` at `http://localhost:8080/` cannot complete confidential sign-in, because the registered callback is on port 80; admin mutations need the stack or HTTPS."
3. In `specs/esi-sso/spec.md`, under "Handoff parks the source before activating the destination", add:
   - Scenario "A standalone device joins the server": **WHEN** a desktop that holds a character solo, for which the server has no holder assignment, records its join intent, parks its credential, and the same character and owner then complete confidential authorization, **THEN** the server activates only after that sequence, and a character with any existing assignment is refused this path.
   - In `design.md:64`, replace "an unclaimed server identity" with "a character with no holder assignment row on the server".

CHANGES_APPLIED: yes

## Rebuttals

Narrow recheck of Required Changes 1–3 against the current files. All three are satisfied.

**Required Change 1: satisfied (M6).**
- **Policy value.** `design.md:263` now reads `KANAME_ESI_SCOPE_POLICY='{"revision":1,"enabledModules":["personalSkills"],"classes":{"characterSkills":"required"}}'`. It has no backslashes and matches the required value exactly.
- **Compose wiring.** `design.md:263` now reads: "Compose passes the two secrets and the non-secret SSO configuration to the `server` service only. It no longer passes `SERVERPOD_PASSWORD_adminKey` (`deploy/compose.yaml:91`)."
- **Wording note.** This is a paraphrase of the prescribed sentence rather than the exact text. It names the variables only collectively, as "the non-secret SSO configuration". The same paragraph sets exactly those variables immediately beforehand: `KANAME_ESI_SSO_CLIENT_ID`, `KANAME_ESI_SSO_REDIRECT_URI`, `KANAME_ESI_SSO_ALLOW_LOCAL_HTTP` and `KANAME_ESI_SCOPE_POLICY`. The substance is therefore met:
  - the four non-secret settings are passed;
  - they go to the `server` service only;
  - the admin key is dropped.
- **Apply note.** When editing `deploy/compose.yaml`, make sure `KANAME_ESI_SCOPE_POLICY` is included with the SSO settings. It is used by D3 rather than D1, so it should not be missed.

**Required Change 2: satisfied (M7).**
- **Definition.** `specs/static-data-settings/spec.md:5` now reads: "only over HTTPS or over HTTP to this machine (`127.0.0.1`, `::1`, `localhost`)".
- **Insecure remote connection.** The THEN at `specs/static-data-settings/spec.md:17` now includes: 'shows "Admin actions need a secure connection"'.
- **Local stack scenario.** Present at `specs/static-data-settings/spec.md:27-29`: WHEN the server address is `http://localhost/api/` and the current session has admin scope, THEN the section shows the admin controls.
- **Risk.** Present at `design.md:257`: "`server:dev` at `http://localhost:8080/` cannot complete confidential sign-in, because the registered callback is on port 80. Admin mutations need the loopback stack or HTTPS."
- **Remaining use of the old phrase.** The "Signed-in admin sees controls" scenario (`:8`) still says "on a secure connection". That phrase is now defined by the requirement text at `:5`, so it is no longer ambiguous.

**Required Change 3: satisfied (M8).**
- **Scenario.** Present under "Handoff parks the source before activating the destination" at `specs/esi-sso/spec.md:149-152`: WHEN a desktop holds a character solo, the server has no holder assignment for it, the device records its join intent and parks its credential, and the same character and owner complete confidential authorization, THEN the server activates only after that sequence, and refuses this path for a character with any existing assignment.
- **Definition.** `design.md:64` now reads: "for a character with no holder assignment row on the server: record a source-bound intent, park the device, then authorize server activation. A known different assignment never takes this path." The phrase "unclaimed server identity" no longer appears.