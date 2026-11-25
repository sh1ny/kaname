# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 (Claude) gave APPROVE_WITH_CHANGES and left three Moderates open. M1: a server lookup exception produces the same fixed 401 as an invalid session. M2: the action's `signedOut` notice was kept alongside a retained viewer. M3: the planned regressions did not pin conditions that prove the holder check. This round, the owner chose scope option A ("Yes, include it"), which brings the viewer route's lookup path into the change.
- **Reviewer:** Claude (fresh-context review, Claude Code)
- **Reviewed:** `AGENTS.md`; `openspec/changes/refresh-failure-not-signout/{proposal.md, specs/esi-sso/spec.md, design.md, review.md}`; `openspec/specs/esi-sso/spec.md` (searched for conflicting refresh and viewer requirements; none found); ADR 0005, ADR 0010, ADR 0017 (searched for constraints that touch viewer refresh or desktop reservation; none conflict); `app/lib/esi_sso/logic/account.dart`; `app/lib/esi_sso/data/connected_account.dart`; `app/test/esi_sso/native_sso_test.dart:280-559`; `server/kaname_server/lib/src/esi/sso_sessions.dart`; `server/kaname_server/lib/src/esi/sso_route.dart:100-400,478-557`; callers of `SsoSessions.viewer` (`sso_route.dart:216,367,396,424`, `server_sso_grants.dart:151`, `sso_skills.dart:37,44`); `server/kaname_server/test/integration/esi/connected_sso_test.dart:1-260`; `openspec/schemas/specwright/templates/review.md`.
- **Applied-changes recheck:** I rechecked only `review.md` and `specs/esi-sso/spec.md`, and only for Required Change 1. I did not reopen the design or widen the scope.

Prior findings:

- **M1: addressed.** The owner's decision S3 and the design's D3 resolve it with a server change instead of a residual-risk note.
  - Context now describes the 401 accurately. `viewer` catches `Exception` and returns null (`sso_sessions.dart:85-101`). The route turns that null into the fixed 401 (`sso_route.dart:366-373`). Exceptions that reach dispatch already become the fixed 503 (`sso_route.dart:169-171,548-555`).
  - D3 adds a lookup that throws its errors, `viewerForRefresh`, and only `_viewer` calls it. The other five `viewer` callers keep the guard (the `begin`, opt-in and handoff routes in `sso_route.dart`, `server_sso_grants.dart:151`, and `sso_skills.dart:37,44`), as does `authenticate`. Other auth routes therefore keep their behavior, matching the owner's scope.
  - The planned test is feasible. `SsoSessions` gets its own clock closure (`connected_sso_test.dart:131`), separate from the route's clock (`:204`). The clock is read inside the guarded block (`sso_sessions.dart:86`), so a synthetic `Exception` from it exercises the exact path. The test covers the 503 during the fault, recovery with the same bearer after it, and the 401 after a real invalidation, using boolean assertions. Wire formats are unchanged.
- **M2: addressed.** D2 now turns the action's `signedOut` into `unavailable` whenever the refresh keeps or replaces the session. Only a confirmed invalidation from the viewer produces the signed-out state in this path. Failure & Visibility matches this.
- **M3: addressed.** The test plan now:
  - uses the real `_TakeDevice` and `_TakeServer` fixtures, with a refused Take (or a Return) so the desktop owns no reservation;
  - lists every inconclusive reply class: transport exception, fixed 503, generic 401, non-JSON 200, a non-string or null holder (round 1 S1), and a mismatched member or character;
  - asserts `blocked` and `nativeRequests == 0`;
  - checks both directions of a verified replacement;
  - covers the fixed 401, the action's own 401 for the notice rule, a completer barrier across sign-out, and scoped completion.

  Round 1 S3 (name the test file) is also applied, and S2 (scoped completion) is now decided in D2.

## Findings

### Critical (blocking)

None.

### Moderate

**M4. The spec gives a server scenario no normative text of its own. (Fixed)**
The new scenario "A temporary lookup error is not session invalidation" (`specs/esi-sso/spec.md:25-28`) says what the viewer route must do. However, the requirement it sits under (`spec.md:7`) only made "SHALL" statements about the app. Nothing in the spec normatively required the route to report a lookup error as unavailable. The design's C3 recorded that invariant only as a doc comment. Option A added the server half in this revision, so the spec needed to state it.

*Recheck:* Fixed. `specs/esi-sso/spec.md:7` now contains the requested sentence word for word: "The viewer route SHALL report a temporary session lookup error as unavailable, not as sign-in required, and SHALL NOT expose the error or a credential." It comes directly after "An inconclusive reply SHALL neither sign the viewer out nor grant desktop authorization.", which is the position the change asked for. The scenario at `spec.md:25-28` now has normative text in its requirement. That matches the approved scope, which already included the viewer route's existing fixed 503.

### Suggestions

**S1. The positive "lets native authorization start" case needs a fixture variant.**
`_TakeDevice` builds its native `MockClient` and `launch` callbacks so they call `fail('native authorization must not start')` (`native_sso_test.dart:539-543`). For the verified no-holder replacement, the task should use a device variant that records a native request or browser launch without failing. The pass condition should then be `nativeRequests > 0` (or a launch was observed), not a returned notice. `_TakeServer` also hard-codes its viewer reply (`:481-482`), so it will need a scriptable viewer response alongside `reply`. These belong in the tasks, not the design.

**S2. Keep the bearer-shape check first in `viewerForRefresh`.**
`viewerForRefresh` should run the bearer-shape check and return null before any I/O, as `viewer` does now (`sso_sessions.dart:84`). That way a malformed bearer still gets the fixed 401 rather than an exception path. The route's `_bearer` already filters most of these (`sso_route.dart:482-487`), but the lookup's own contract (C3) should not depend on that.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. In `openspec/changes/refresh-failure-not-signout/specs/esi-sso/spec.md`, line 7 (the requirement body), add this sentence after `An inconclusive reply SHALL neither sign the viewer out nor grant desktop authorization.`: `The viewer route SHALL report a temporary session lookup error as unavailable, not as sign-in required, and SHALL NOT expose the error or a credential.` (Applied: the sentence is at `spec.md:7` in the requested position, with exact wording.)

CHANGES_APPLIED: yes

## Rebuttals

None.