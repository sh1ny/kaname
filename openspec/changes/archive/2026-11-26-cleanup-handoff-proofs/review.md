# Review

## Metadata

- **Round:** 3, the final round the owner authorized
- **Prior round:** Round 2 returned APPROVE_WITH_CHANGES. It accepted M1 to M4 and left two Required Changes open: N1 (the absence fallback sat in an adapter that was neither injected nor tested) and N2 (unchecked plugin claims while `## Assumptions` read `None`). There were no Criticals.
- **Reviewer:** cross-model CLI (Claude Code, claude-opus-5-5)
- **Reviewed:**
  - **Change artifacts:** `openspec/changes/cleanup-handoff-proofs/proposal.md`, `design.md`, `specs/esi-sso/spec.md` and `review.md` (round 2).
  - **Schema and project rules:** `openspec/schemas/specwright/templates/review.md`, `openspec/schemas/specwright/schema.yaml:290-339` and `AGENTS.md`.
  - **Skills:** `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis`, `dart-add-unit-test` and `dart-use-path-package`.
  - **Source:**
    - `app/lib/esi_sso/data/device_store.dart:1-21` (the `DeviceSecrets` interface)
    - `app/lib/esi_sso/data/desktop_platform_io.dart` (whole file)
    - `app/test/esi_sso/native_sso_test.dart:995-1014` (`_MemoryKeyring`)
    - `pubspec.lock:350-405`
    - `DeviceStore.open` call sites in `app/`
  - **ADRs:** ADR 0005 and ADR 0017, as cited in round 2. No ADR text changed in this round.
  - **Provenance:** The session's git status shows only the change directory as untracked, so the cited sources are the tracked files at `d7aa5ca`. I had read-only file tools and no shell, so I did not run `git ls-files` or a symlink check. I opened no pub cache, package archive or external path. I checked the plugin claims only against the repo's lockfile pins and the planned behaviour.

Editing the proposal, specs or design after this review voids this verdict. Two kinds of edit are exempt: applying the Required Changes below, and edits confined to the proposal's `## Release Notes` section.

## Findings

### Critical (blocking)

None.

### Moderate

**N1, the absence fallback behind an injectable seam: fixed and accepted.**
- **Where the logic lives now:**
  - D2 (`design.md:34`) puts the decision in `DeviceStore`. If `DeviceSecrets.delete` throws, the store calls the injected `DeviceSecrets.contains` for that exact name.
  - It acknowledges the row only when `contains` returns `false`. Both `true` and an exception leave the row tracked, and the error text is discarded.
  - `contains` returns presence without loading the proof, and throws when presence or absence can't be established.
  - So the only code that decides whether to acknowledge after a backend error can now be reached through the `DeviceSecrets` fake. Today that fake has only `failDelete` (`native_sso_test.dart:999-1014`).
  - Flow & State Gaps (`design.md:146`) asks for tests of the three fallback outcomes through `DeviceSecrets`, plus a sink that records the message and a sink that throws. That covers round 2's concern that regressions could reach CI untested.
- **C4 (`design.md:59`):**
  - The destination is now `doc comment: app/lib/esi_sso/data/device_store.dart DeviceSecrets`, as required.
  - The fact now says "successful cleanup" where the Required Change said "successful deletion". The guarantee is the same.
  - C4 also adds the throw-when-unsure rule to the interface contract.
- **Deviation from the round-2 text: accepted.**
  - Round 2 asked that `_Keyring` "adds no logic of its own". The design instead lets `_Keyring.contains` delegate to `containsKey` on macOS and Linux only. On Windows it reports that absence can't be established.
  - New evidence supports this. A1 records that the Windows 4.2.2 legacy check can return `false` after a failed file-attribute lookup if no generic credential exists, so it can mix up "inaccessible" with "absent".
  - This choice is the more conservative one, and the owner authorized the fix.
- **What it means on Windows, within #43's journal scope:**
  - A failed Windows delete is never acknowledged on the strength of a lookup. The row stays tracked and the next open retries.
  - Scenario 2's "confirms it is already absent" still holds on Windows with working storage. Per A1, a healthy backend accepts deleting a missing entry, so after a crash between delete and acknowledgement, the retried delete completes and the row is acknowledged.
  - If a Windows delete keeps failing, the backlog grows by one tracking row per stuck key. Resource Bounds already allows for this (`design.md:138`), and a later healthy open clears it.
  - A wrong `false` on any platform can only leave an untracked orphan. Cleanup only considers unreferenced candidates, so C1 still holds.

**N2, recording the unchecked plugin claims: fixed and accepted.**
- **A1 (`design.md:52`):**
  - It names flutter_secure_storage 11.2.0, darwin 0.4.3, linux 3.0.3 and windows 4.2.2. The cited lines `pubspec.lock:358-381,398-405` match those four pins exactly.
  - It says where the evidence comes from: released plugin source outside the repo, not an OS run. It also states the Linux limit: the check throws only when it detects an unavailable or locked store.
  - It names its dependents, D2 and C4, and requires a recheck of the pins and contracts before they are implemented.
  - It forbids acknowledging a thrown Windows delete on the strength of a presence lookup.
  - This meets the schema's requirements for an assumption entry: the claim, why it wasn't checked in the repo, and its dependents (`schema.yaml:304-308`). It also gives the planner and implementer the signal that round 2 said was missing.
- **Resource Bounds (`design.md:139`):** The Windows "rewriting its shared file" claim is gone. Backend-internal work now points to #49 and is not stated as fact.
- **Scope of #49:** Still out of scope and not claimed. The spec requirement, C7, the Resource Bounds row and the Risks section each limit the guarantee to the journal and exact-key requests.

**Round-2 suggestions:**
- **S5:** addressed. The same sink is kept for inline rollback cleanup, a missing sink does nothing, and `openDesktopHolder` wires the sink before building `NativeAccount` (`design.md:146`).
- **S6:** addressed. The downgrade stranding is now a separate deliberate gap, C8 (`design.md:63`).
- **S7:** mostly addressed (`design.md:146`). The ordered operation log and the secret-free assertions are left to the tasks.

### Suggestions

- **S8. Carry the Windows refusal to the code it constrains.**
  - The Windows "never confirm absence" rule currently lives in A1 and D2, which are archived with the change. C4 on `DeviceSecrets` states only the general throw-when-unsure contract.
  - A later maintainer could make `_Keyring.contains` call `containsKey` on every platform, and no test would catch it, because no test imports `desktop_platform_io.dart`.
  - Add C9: "`_Keyring.contains` throws on Windows because the legacy lookup can report an inaccessible file as absent (A1)." Kind: invariant. Destination: `doc comment: app/lib/esi_sso/data/desktop_platform_io.dart _Keyring`.
  - The schema sends "why a path is not taken" to the code's own doc comment, which justifies documenting this private class.
- **S9. Widen the pin recheck to the platform interface if it is on the call path.** The lockfile also pins `flutter_secure_storage_platform_interface` 2.1.1 (`pubspec.lock:382-389`). If the Dart `containsKey` call for macOS or Linux passes through that package, add it to A1's list of pins to recheck during apply.
- **S10. Name `contains` in Failure row 4.** Row 4 (`design.md:131`) lists the cleanup failures it catches, and a `contains` exception isn't among them. D2 and Flow & State Gaps already say such an exception leaves the row tracked. Adding it to the row makes that table complete for the planner.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

Both Required Changes are applied and stand. The Windows-specific narrowing in D2 is supported by the evidence A1 records, and it is the more conservative choice. The guarantees accepted in round 2 still hold:
- No live or pending proof is deleted.
- An unverified store fails closed with no keyring changes.
- Optional cleanup cannot make the holder unavailable.
- Diagnostics carry no secrets or identifiers.
- The spec makes no claim about the Windows backend tracked in #49.

Tasks may now be planned. S8 to S10 are optional.

## Required Changes

1. **(N1) Move the absence fallback behind an injectable seam.** Applied:
   - D2 (`design.md:34`) moves the decision into `DeviceStore`.
   - `DeviceSecrets.contains` carries the contract: presence without the value, and a throw when it can't answer.
   - C4 (`design.md:59`) is re-targeted to the `DeviceSecrets` doc comment.
   - The Windows `_Keyring` deviation is accepted on the A1 evidence.
2. **(N2) Record the unchecked plugin claims.** Applied:
   - A1 (`design.md:52`) names the pins, the out-of-repo source, its limits and its dependents, D2 and C4.
   - The Windows shared-file claim is removed from Resource Bounds (`design.md:139`).

CHANGES_APPLIED: yes

## Rebuttals

- **M1 to M4:** fixed in round 2. Accepted by reviewer.
- **N1:** fixed (design D2, C4, Flow & State Gaps paragraph 3). Accepted by reviewer, including the deviation for Windows `_Keyring.contains`.
- **N2:** fixed (design A1, Resource Bounds startup row). Accepted by reviewer.