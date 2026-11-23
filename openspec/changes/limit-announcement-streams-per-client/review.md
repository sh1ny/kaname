# Review

## Metadata

- **Round:** 8
- **Prior round:** Round 7 returned `REVISE` (2 Critical, 3 Moderate). The custom-proxy check order and YAML rationale are fixed. The saturation and header-cutoff scenarios still permit false passes. Of round 1’s nine findings, six are accepted, two are partially accepted, and one is not accepted.
- **Reviewer:** user (USER_OVERRIDE) after OMP round 8. Round 8 reviewer: Fresh-context, read-only OMP design reviewer
- **Reviewed:** Proposal, design, three spec deltas and their main specs, prior review, architecture, ADRs 0001/0008/0014, cited source and fixtures, lockfile, applicable skills, and review template. Reviewed issue #20 through the proposal and round 1 through the carried findings in `review.md`. Git-index membership could not be independently verified. No files changed or runtime tests run.

## Findings

### Critical (blocking)

1. **D5 moves the first-event deadline on a premise that the existing transport probe contradicts.** `design.md:66,111` ties the 20-second deadline to Serverpod attaching its listener, claiming that a timely first announcement prevents idle timeout and that a late listener will time out and reconnect if the clock assumption is wrong. The recorded Serverpod 4.1.2 probe (`announcement_stream_probe_test.dart:15–24,79–117`) shows that inbound traffic, including pongs, resets the idle timer. A healthy but quiet transport can therefore remain open without triggering the promised reconnect. The probe does not establish when the initial timer starts, but it does invalidate treating that timer as a first-announcement deadline. The main spec (`openspec/specs/realtime-bus/spec.md:42–54`) and the existing generated-client fixture (`bundle_stream_test.dart:164–176`) measure from subscription; the delta permits an admitted subscription to wait much longer with no announcement. Record that as an intentional change to the client-visible guarantee, justify it independently of idle timeout, and align the spec and test map. Keep the existing generated-client startup timing check; it tests a different contract from a direct endpoint’s late-listen test.

### Moderate

1. **A second generated client is not necessarily a second quota bucket.** D4 (`design.md:58`) first says both extra subscriptions come from the same client, then assigns the stress refusal to a second client. `_Rig` uses `InProcessPod.baseUrl`, which is on `127.0.0.1` (`bundle_stream_test.dart:940,975–978`; `test/integration/support/in_process_pod.dart:23–25`). A second `Client` on that URL does not by itself change the source address. With the raised limit still active, an empty stream proves the global refusal but not that the refused bucket holds fewer than 16, as `specs/realtime-bus/spec.md:69–71` requires. Specify a distinct server-observed bucket for the refused request and verify it is empty. For the stalled-reader fixture, state how the test keeps its refusal attributable to the global limit.
2. **The cutoff test can still pass without reaching the cutoff.** `specs/realtime-bus/spec.md:171–173` allows 20 or more complete trusted entries in the suffix. A parser that incorrectly accepts a partial entry can stop at the 20-entry cap and return the expected fallback. Require fewer than 20 complete entries and a boundary entry whose full value and truncated suffix are both valid untrusted addresses. Then ignoring either the byte cap or the partial-entry rule produces the wrong bucket. Pin the 20-entry cap separately with a complete untrusted entry just beyond it.
3. **The custom proxy’s trusted address is distinct, but not reserved.** S3 (`proposal.md:63`) and C6 (`design.md:119`) require the front proxy to join the stack network with its own address, then put that address in both trust lists. The pre-public checks prove the address is correct at that moment, not after container recreation. If the address changes, clients collapse into one bucket; if it is reassigned, both lists trust the wrong peer. Extend the README handoff to require a fixed front-proxy address outside dynamic allocation, distinct from Caddy and the gateway, and repeat the existing checks after a network or address change.

### Suggestions

None.

## Verdict

VERDICT: USER_OVERRIDE

The OMP reviewer returned REVISE in round 8, as in every round since round 1, and the author escalated to the owner. The owner's decision (2026-11-23, through the Orca coordinator): Q1 "Yes, from subscribing"; Q2 "Stop now: apply Q1, record gaps, write tasks". Findings open at the override, none re-checked by a reviewer:

- Round 8 Critical 1 (first-event clock): resolved by the owner's Q1; the fix was not reviewed.
- Round 8 Moderates 1-3 (distinct test buckets, cutoff test, front-proxy address): fixed by the author, not reviewed.
- The accepted gaps in design.md, section "Accepted gaps after the design review".

Escalate the unresolved first-event contract to the owner; consecutive design rounds have returned `REVISE`.

## Required Changes

CHANGES_APPLIED: n/a

## Rebuttals

| Round 1 finding | Round 8 disposition |
|---|---|
| Critical 1 — admission and first-event timing | **Not accepted.** Admission is separated from listening, but A6 does not justify moving the observable first-event deadline. |
| Critical 2 — an expired reservation can restart on late listen | **Accepted.** D5, C2, and the post-expiry scenario require both places to be freed and prohibit subsequent bus attachment or sends. |
| Moderate 1 — warning coverage and suppressed counts | **Accepted.** D6 covers refusals and proxy fallback; C9 records loss on inactivity or eviction. |
| Moderate 2 — bounded refusal work | **Accepted.** D1 bounds the suffix walk; D6 checks only the oldest warning for eviction. The cutoff scenario still needs a discriminating fixture. |
| Moderate 3 — address parsing and trust matching | **Accepted.** D1 specifies address forms, repeated-line order, mapped normalization, whole-address trust, and unknown peers. |
| Moderate 4 — proof of admission before listen | **Accepted.** D5 exercises the production endpoint while returned streams remain unlistened under both bounds. |
| Moderate 5 — saturation overrides and reset | **Partially accepted.** The overrides and reset sites are identified; the stress fixture still does not establish a distinct, below-cap bucket for the refused request. |
| Moderate 6 — operator and app handoff | **Partially accepted.** App backoff and the two-stage operator check are covered. The custom proxy’s trusted address must remain assigned to that proxy across recreation. |
| Suggestion — pinned subnet and dynamic range | **Accepted.** The shipped dynamic range excludes Caddy’s fixed address, and the upgrade procedure preserves named volumes. |

**Round 7 responses:** Critical 1 and 2 are **accepted**: the checks now run in prerequisite order, and D2 accurately describes the baked YAML and the override cost. Moderate 1 is **partially accepted**: health and fan-out remain, but a second client object does not establish a second quota bucket. Moderate 2 is **not accepted**: a dedicated transport-timing seam is not required to correct the rationale and state the actual guarantee. Moderate 3 is **partially accepted**: the right edge is tested separately, but the cutoff case can still pass without reaching the partial entry.
### Author's response (round 8)

The owner answered on 2026-11-23: Q1 "Yes, from subscribing"; Q2 "Stop now: apply Q1, record gaps, write tasks". No round 9 runs. design.md, section "Accepted gaps after the design review", records what stays open.

- **Critical 1 (first-event clock):** fixed by the owner's Q1. The 20-second limit runs from subscribing, as in the main spec. A late-listened stream sends the current bundle as soon as it is listened to, with no time promise of its own. A6 now assumes Serverpod listens promptly. Its gate is the existing generated-client startup test (`bundle_stream_test.dart:164-176`).
- **Moderate 1 (distinct buckets in tests):** fixed. D4: the runtime holds the session-to-client-key function. Tests that need several clients replace it with per-client keys; production wiring is proven by "Direct connection" and the stack scenarios. The 2,000-stream fixture's refused key is checked to hold no stream. The stalled-reader fixture's refusal is attributable to the global bound because its key holds 1,999 under a limit of 2,001.
- **Moderate 2 (cutoff test):** fixed. Fewer than 20 complete trusted entries, and a cut fragment that is itself a valid untrusted address. A separate scenario, "Twenty-entry cap", pins the cap.
- **Moderate 3 (front-proxy address):** fixed. The front proxy needs a fixed address outside the dynamic range, distinct from Caddy's and the gateway's, and both checks are repeated after any network or address change (C6, proposal).
