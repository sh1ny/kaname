# Review

## Metadata

- **Round:** 3
- **Prior round:** REVISE. Round 2 left a blocking Windows verification finding and a Moderate finding on where to record the fork publishing restriction. The owner authorized this additional round.
- **Reviewer:** Codex CLI, independent read-only FULL design review.
- **Reviewed:** `openspec/changes/harden-desktop-take/{proposal.md,design.md,review.md,specs/esi-sso/spec.md}`, `openspec/schemas/specwright/templates/review.md`, and the `review` block of `openspec/schemas/specwright/schema.yaml`.
- **Reviewed:** ADRs 0002, 0005, 0010, and 0017 under `docs/adr/`.
- **Reviewed:** The cited ranges in `app/lib/esi_sso/data/{desktop_platform_io,device_store,native_account}.dart`, `app/lib/esi_sso/logic/account.dart`, `app/lib/esi_sso/ui/esi_account_section.dart`, `server/kaname_server/lib/src/esi/{sso_holder_row.spy.yaml,sso_handoff.dart,server_sso.dart,server_sso_grants.dart}`, `pubspec.lock`, `.github/workflows/ci.yml`, and `mise.toml`. Also checked the relevant ranges in `app/pubspec.yaml`, `THIRD_PARTY_NOTICES`, and `tools/kaname_tools/lib/src/notices.dart`. The source files checked were tracked regular files. A1–A3 remain external assumptions. No Windows execution was observed.
- **User decision:** "Fix it, no more review".

## Findings

### Critical (blocking)

1. **#49. The hosted baseline lacks a defined fault that can produce the required preservation failure.** The revised plan requires a red preservation assertion against hosted 4.2.2. Its baseline lists the production facade, directory fixture, and DPAPI format, but leaves the fault unspecified. The publication barriers belong to the patched path. A successful write and delete through the baseline facade could leave every unrelated entry intact while still using an interruption-unsafe rewrite. The plan also puts the baseline in the same file as the patched factory tests. A name filter still compiles that file, so any calls to patch-only callbacks in it can prevent the hosted run from reaching the assertion.

   Give the baseline an independently compilable entry point or identify the exact baseline-only revision to run before adding patched calls. Specify a deterministic fault available through the unmodified facade and assert a concrete preservation failure under the hosted pin. For example, if A1 is confirmed, use an isolated committed fixture that fails decoding and assert that the exact bytes remain after the operation. Run that same probe under the Git pin and require it to pass. Keep the four observed-exit write and delete cases as the separate proof of the patched interruption contract. Record the hosted checksum, resolved Git SHA, and assertion outcomes using synthetic data and diagnostics that omit credential values. [Assumptions](openspec/changes/harden-desktop-take/design.md#L74-L78) · [Windows verification plan](openspec/changes/harden-desktop-take/design.md#L177-L181) · [Hosted lock entry](pubspec.lock#L398-L405) · [Production facade](app/lib/esi_sso/data/desktop_platform_io.dart#L48-L60)

### Moderate

1. **#49. The carried publishing restriction has a durable destination, but its wording leaves an exception outside the approved scope.** C7 names a handwritten section in `THIRD_PARTY_NOTICES`, and notice regeneration preserves text outside its generated markers. D2 and C7 still qualify the upstream and third-party prohibitions with “without separate owner approval.” Carrying that wording into the notice would present those actions as an available continuation of this change. The owner authorized only the approved patch branch in the owner's fork after apply approval.

   Remove that qualification from D2 and C7 and carry the same wording into the handwritten notice during apply. Keep explicit `-R sh1ny/flutter_secure_storage` for fork `gh` operations, the prohibition on fork PRs, and the prohibitions on upstream and third-party pushes, PRs, issues, and comments. Record public provenance, the immutable pin, licence credit, and the removal condition outside the generated region. [Publishing decision](openspec/changes/harden-desktop-take/design.md#L36-L44) · [Carried restriction](openspec/changes/harden-desktop-take/design.md#L88) · [Notice regeneration](tools/kaname_tools/lib/src/notices.dart#L124-L135)

### Suggestions

None.

## Rebuttals

- **Round 2 Critical 1, #49.** The revised process protocol addresses the exit-observation gap. The child identifies the Windows test host at the barrier. The parent obtains its handle before acknowledging, checks the signalled handle and designated exit code, and reaps the runner before reopening the store. The plan also ties parent and child to the workspace-resolved package and requires an isolated default-facade check alongside the factory cases. The generated registrant, native initialization, and shared production save path still require Windows evidence during apply. The remaining baseline gap is Critical 1 above. [External assumption](openspec/changes/harden-desktop-take/design.md#L78) · [Windows execution plan](openspec/changes/harden-desktop-take/design.md#L177-L181) · [CI test entry](.github/workflows/ci.yml#L39-L67) · [App test task](mise.toml#L91-L94)
- **Round 2 Moderate 1, #49.** The missing destination is resolved by C7. Moderate 1 above addresses the wording that would be carried there. [Carried restriction](openspec/changes/harden-desktop-take/design.md#L88)
- **#47 and #48.** The Windows revisions leave the previously reviewed recovery and closure contracts intact. #47 retains the original proof while the outcome is uncertain and shows the new-Take notice after a committed rollback. #48 checks committed evidence before the cooldown and samples the clock after obtaining the holder row lock for the guarded write. The regression plan checks the lock wait, exact replay, and cooldown boundary. [Recovery contract](openspec/changes/harden-desktop-take/specs/esi-sso/spec.md#L62-L97) · [Closure decision](openspec/changes/harden-desktop-take/design.md#L54-L60) · [Lock-wait regression](openspec/changes/harden-desktop-take/design.md#L183)

## Verdict

Codex returned `REVISE` in round 3. Its remaining findings were the hosted Windows baseline and the wording of the publishing restriction. The owner ended design review after round 3 and accepted the narrow revision without a round 4. The design now names a standalone invalid-file preservation probe that runs unchanged under the hosted and fork pins. It limits publication to the approved fork branch and records where that rule will live. No reviewer rechecked those edits. Build and push still require separate owner approval; pre-ship review remains required.

VERDICT: USER_OVERRIDE
CHANGES_APPLIED: n/a