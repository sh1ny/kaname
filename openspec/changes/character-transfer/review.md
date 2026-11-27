# Character transfer design review

## Metadata

- Round: 2 recheck
- Prior round: APPROVE_WITH_CHANGES
- Reviewer: Codex CLI
- Reviewed: `openspec/changes/character-transfer/review.md`, `design.md` and `specs/esi-sso/spec.md` in the same change, and the relevant sections of tracked `app/lib/esi_sso/data/native_account.dart` and `docs/adr/0017-esi-holder-handoff.md`.

## Findings

1. The lost-reply scenario and test plan drop the committed reservation reply before the desktop saves it and reopen the original desktop’s persisted `taking` journal after transfer. Replay stays pending without a new owner fingerprint, the exact proof survives Take and Return, Return sends no release, and server ESI stays blocked. This matches the baseline, where Return retries Take and exits when it stays pending. A separate case verifies that ordinary Return succeeds after parking with the proof and generation saved before transfer, and that fresh scoped authorization is required afterward. [Design](design.md#flow--state-gaps-full) · [ESI SSO spec](specs/esi-sso/spec.md#scenario-the-device-reserve-commits-first-but-its-reply-is-lost) · [Baseline Return](../../../app/lib/esi_sso/data/native_account.dart#L353)
2. Proposed ADR 0020 qualifies ADR 0017’s Recovery section when CCP ownership changes. An unfinished Take cannot resume or use ordinary Return across owners. A completed reservation can use ordinary Return when the original device kept the proof and generation and can park. The current owner still needs fresh authorization for server ESI. The design calls for a cross-reference from the architecture index entry for ADR 0017 and preserves the accepted ADR text. [Proposed ADR 0020](design.md#adrs) · [ADR 0017 Recovery](../../../docs/adr/0017-esi-holder-handoff.md#recovery)
3. The accepted refresh risk says a later correct proof can restore sign-in and allow fresh ESI authorization through a fresh account. The former account keeps its records and remains accessible through any surviving eligible signer. If none remain, the former account has no connected sign-in path. [Design risk](design.md#risks--trade-offs)

## Verdict

VERDICT: APPROVE_WITH_CHANGES

CHANGES_APPLIED: yes

## Required Changes

None remain from round 2.

## Rebuttals

None.