I've read everything. The S1 changes only update attribution, so I'm writing up the recheck now.

---

# Review

## Metadata

- **Round:** 2, owner-confirmation recheck. This is not a fresh review and not a third full round. There have been two full rounds, followed by one Required Changes recheck and now this owner-confirmation recheck.
- **Prior round:** Full round 1 returned REVISE with 1 Critical, 7 Moderate and 7 Suggestion findings. Full round 2 returned APPROVE_WITH_CHANGES with 0 Critical, 4 Moderate and 5 Suggestion findings, plus 4 Required Changes. The Required Changes recheck verified all 4 Required Changes and kept APPROVE_WITH_CHANGES, with changes applied and 5 Suggestions. This recheck exists because the owner confirmed option A late. That confirmation changed S1's attribution and wording, and an edit to the proposal or design voids the prior verdict under the template rule.
- **Reviewer:** fresh-context Claude agent (Claude Code, `claude-opus-5-5`), no authoring context.
- **Reviewed:**
  - Change artifacts:
    - `openspec/changes/esi-token-vault/review.md`, the prior review, read in full
    - `proposal.md`: S1 and the whole proposal, for agreement
    - `design.md`: the decision summary S1 row and the whole design, for agreement
    - `specs/esi-token-vault/spec.md`
    - `tasks.md`
  - Roadmap: `openspec/roadmap.md`, M2 section (`:7-27`).
  - Review format: `openspec/schemas/specwright/templates/review.md`.
  - Cited source, checked for S1 agreement: `docs/adr/0005-run-modes-and-one-token-holder.md:22-31`.
  - Project skill references: the same as the prior review, which used only the Specwright review template. None were added for this attribution-only update.
  - Scope: tracked files and the named change artifacts only. No credentials, ignored files or other worktrees were opened, and nothing was edited.

### Owner confirmation, verified against the reviewed option A

| Element of option A | Proposal S1 (`proposal.md:34-40`) | Design summary S1 (`design.md:57`) | Roadmap M2 (`roadmap.md:27`) | Elsewhere, unchanged | Status |
|---|---|---|---|---|---|
| One authority | "one active holder per character in one authoritative vault" | "One authoritative store" | "in its authoritative store" | `spec.md:11`, C1 `design.md:70` | Agrees |
| Park before transfer | "Refuse another holder until the current holder parks" | not restated (summary row) | implied by ADR 0005 reference | `spec.md:11,13-16`, `design.md:30`, ADR 0005:26 | Agrees |
| Shared native policy | "share vault logic with native consumers" | (D1 row: "Shared Dart") | — | `proposal.md:10`, D1 `design.md:26` | Agrees; native storage, login and handoff are still not invoked |
| `esi-sso` owns real server↔device wiring | "`esi-sso` owns the real server↔device handoff and wiring" | "`esi-sso` wires handoff"; Rejected "Cross-install wiring now" | "`esi-sso` owns server↔device handoff and wiring" | `proposal.md:13` out of scope, `design.md:30,170`, Mechanism Ledger `:183` | Agrees |
| M4 general solo store | "general solo store choice stays in M4" | — | "remains in M4" | `proposal.md:10,13`, ADR 0005:31, `roadmap.md:35` (R32 spike) | Agrees |
| No global exclusivity | "No global exclusivity across independent stores" | — | "not across independent stores" | `proposal.md:13`, `design.md:170,191` | Agrees |
| Attribution | "Chosen by: user. The owner confirmed option A through Orca after the author drafted the same boundary." | Chosen by: user | — | DECISION_MAKING: all (`proposal.md:31`) | Consistent. Important: yes, chosen by the user |

**Broadening check:**
- The S1 Choice, Rejected, Reversal cost (medium) and Important (yes) fields describe the same boundary that was reviewed. The edits add no requirement, consumer, store, startup wiring or deployment input.
- The roadmap sentence at `:27` narrows the meaning of the M2 exit criteria at `:15` and `:18` to the authoritative store, and assigns handoff to a later change. It does not widen this change's scope.
- ADR 0005:22-26 makes global holder exclusivity a product outcome. Option A composes that outcome from this vault's guarantee within one store plus `esi-sso`'s park-then-handoff. This is the same composition the reviewed rounds accepted.

**Evidence that the reviewed bodies are unchanged:**
- Every line citation from the prior recheck still lands on the same content:
  - `design.md:35, 43, 49, 61, 66, 77-79, 151, 160, 162`
  - `spec.md:59, 71-74, 91-94, 96-99`
  - `proposal.md:32`
- The proposal and design body text around S1 has not shifted. The spec and design wording that RCs 1–4 rely on is intact.

### Scenario testability, rechecked

- `spec.md` has 21 scenarios:
  - One active holder: 4
  - Encryption and secret-free failures: 4
  - Single-flight refresh: 8
  - Invalid grant: 5
- `tasks.md:5-27` maps all 21 one-to-one, by exact scenario title, to a named test file and test name. All are in state `red`.
- 19 scenarios are covered by the shared package (`vault_test.dart`) with a hand-written atomic store, injected clock and event barriers (`tasks.md:32`).
- 2 scenarios need real Postgres sessions (`postgres_vault_test.dart`), covered by `tasks.md:38`.
- Each scenario has an observable WHEN and THEN:
  - bearer returned or not
  - exchange count
  - busy, unavailable or re-login result
  - raw row contents
  - lease and fence state
  - dead marking
- The fake clock and barriers make the timing scenarios deterministic:
  - margins at `spec.md:66-74`
  - lease deadline at `:76-79`
  - salvage and supersession at `:91-99`, `:120-123`
- The S1 edits changed no scenario.

### Required Changes, carried from the prior recheck

| RC | Required | Status | Evidence (current lines) |
|---|---|---|---|
| 1 | Mandatory late-rotation salvage, plus a positive scenario | **Verified; unchanged** | `spec.md:59`, `:91-94`; refusal at `:96-99`; `design.md:49` |
| 2 | Separate pre-refresh and read-only margins, plus a scenario | **Verified; unchanged** | `design.md:160`, C8 `:77`, summary `:61`; `spec.md:71-74` |
| 3 | Reserve the PostgreSQL lock namespace; verify-before-use assumption | **Verified; unchanged** | C9 `design.md:78`, A2 `:66`, D3 `:43`; task 2.1 settles A2 before the adapter relies on it |
| 4 | Key provisioning at startup and in deployment; destination for the backup warning | **Verified; unchanged** | D2 Startup `design.md:35`, C10 `:79`; task 2.3 names `deploy/README.md` |

### Prior findings: disposition (preserved)

- **Round 1 Critical 1** (the strict fence defeats recovery): closed. RC1 made the salvage mandatory in the spec.
- **Round 1 Moderates 2–8:** closed, as recorded in round 2. Moderate 3 was closed fully through RC2.
- **Round 2 Moderates:**
  - 1: closed by RC1.
  - 2: closed by RC2.
  - 3: closed by RC3.
  - 4: closed by RC4.
- **Round 2 Suggestions:**
  - 5: partly addressed and carried as recheck Suggestion 1.
  - 6: addressed at `design.md:43`.
  - 7: addressed in tasks (`tasks.md:31-39`).
  - 8: addressed in Rebuttals.
  - 9: addressed at `design.md:162`.
- **Required Changes recheck Suggestions:**
  - 1–5: the author's dispositions are recorded in Rebuttals.
  - 1 and 3 were dispositioned to tasks. The text at `design.md:151` and `spec.md:66-69` is still unchanged, so they are carried below as non-blocking.
  - 2, 4 and 5: addressed through tasks 2.3, 2.1 and the workflow notes.

## Findings

### Critical (blocking)

None.

### Moderate

None. The owner-confirmation edits change who chose S1 and how it is worded, not what it does. No reviewed behavior was broadened.

### Suggestions

1. **Carried from recheck Suggestion 1: name the superseded salvager's result.**
   - `design.md:151` still does not say that the salvaging attempt returns `unavailable`.
   - The test name at `tasks.md:21` asserts that no bearer is published, so the test is still valid.
   - Naming the result type would let the test assert it as well.
2. **Carried from recheck Suggestion 3: name the bearer path in "Bearer is too close to expiry to dispatch".**
   - `spec.md:69` still says "attempts refresh".
   - That is only true for a refresh-capable call. Under C8, a read-only lookup refuses without refreshing.
   - The scenario is testable through the refresh-capable path, and the test named at `tasks.md:16` ("refuses and refreshes") covers both behaviors. Saying "a refresh-capable call" in the WHEN would remove the ambiguity.
3. **Test-name wording at `tasks.md:15`.**
   - `same character waits for a committed rotation without duplicate exchange` suggests the competitor waits.
   - The scenario and D3 say the competitor gets busy, with no queue.
   - Consider renaming to `…competitor is busy until the rotation commits…` so the test does not drift toward a queued design.
4. **Optional roadmap consistency.**
   - The note at `roadmap.md:27` assigns server↔device handoff to `esi-sso`, but `esi-sso`'s own change line (`roadmap.md:25`) does not list handoff.
   - Adding "server↔device handoff (park before transfer)" to that line would keep the next change's scope self-describing.
   - This does not affect this change.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

All four were applied by the author and verified by the reviewer in the prior Required Changes recheck. This owner-confirmation recheck confirms they are still in place at the same lines.

1. Salvage is mandatory in `spec.md:59`, with the positive scenario at `spec.md:91-94`. **Verified.**
2. The bearer margins are split (>5 s read-only, >15 s refresh-capable) at `design.md:160`. C8 at `design.md:77` restates the rule, and the scenario is at `spec.md:71-74`. **Verified.**
3. C9 reserves the lock namespace with the destination `server_esi_vault.dart` `_vaultLockKey`. A2 makes key-space separation a verify-before-use assumption that D3 depends on (`design.md:66,78`). **Verified.**
4. The D2 startup and test-key statement is at `design.md:35`. C10 covers deployment inputs, the generator, the backup warning, timing and destination (`design.md:79`). **Verified.**

No new Required Changes arise from the S1 attribution and wording update.

CHANGES_APPLIED: yes

## Rebuttals

- Re-check suggestions 1 and 3: implementation tasks verify no bearer from a superseded attempt and separate the read-only dispatch test from the refresh-capable threshold test.
- Re-check suggestion 2: task 2.3 names `deploy/README.md` and the separate key backup/restore warning.
- Re-check suggestion 4: task 2.1 verifies A1 and A2 before the Postgres adapter relies on them.
- Re-check suggestion 5: tasks record CI placement, deterministic barriers, generated model scope and dependency notice updates. The two review rounds and the re-check dispositions are recorded above.
- Owner-confirmation recheck: S1 is now attributed to the user (`proposal.md:40`, `design.md:57`). The roadmap M2 note at `roadmap.md:27` records the same boundary. No author rebuttal is needed: the recheck Suggestions are non-blocking.

---

I didn't edit any files; the review above is ready to paste into `openspec/changes/esi-token-vault/review.md`.

- **Verdict:** APPROVE_WITH_CHANGES, with changes applied. The four required changes are still in place at the same lines and nothing new is required.
- **S1:** the edits change only who chose it and how it's worded. They match option A as reviewed and don't widen any behavior.
- **Scenarios:** all 21 are still testable, and each one maps to a named test in `tasks.md`.
- **How I checked:** the change folder is untracked, so I couldn't diff it. Instead I checked that every line the previous recheck cited still points at the same text.

The four suggestions are optional. The most useful one is to update the "too close to expiry" scenario at `spec.md:66-69` so it says it applies to refresh-capable calls. As written, a read-only lookup would appear to refresh too.