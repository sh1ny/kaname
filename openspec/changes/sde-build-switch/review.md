# Review

## Metadata

- **Round:** 1
- **Prior round:** Round 1 (fresh-context subagent) gave APPROVE_WITH_CHANGES with seven Moderate (M1-M7) and Required Changes 1-7; its first re-check found 1 and 3-7 applied, Required Change 2 applied except the "CCP unreachable during a check" Failure row, and added Suggestions S5-S7. This file is the second re-check of those remaining items.
- **Reviewer:** fresh-context subagent (Claude Code)
- **Reviewed:** openspec/changes/sde-build-switch/review.md (round 1, first re-check and the author's notes), design.md (D2, D4-D6, Carried constraints, State & Ownership, Failure & Visibility, Resource Bounds, Flow & State Gaps, Mechanism Ledger), specs/static-data-builds/spec.md; main specs under openspec/specs/ (searched for conflicting catch-up, rollback and comparison rules). Tracked source checked: server/kaname_server/pubspec.yaml (for S8). No skills were named in the request, so none were loaded.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

Claims check (second re-check): no edit since the first re-check added or moved a citation. The citations the first re-check verified are unchanged in design.md. The round-1 claims check also still holds.

### Critical (blocking)

None.

### Moderate

- **M1. The main import spec forbids what D6 does at start.** Fixed (first re-check). Accepted.
- **M2. A restart around 12:00 UTC can miss a day's build.** Fixed. The remaining row is now correct: design.md:258 gives the recovery for "CCP unreachable during a check" as "The next day's check, or a start after the next 12:00 UTC (D6 catch-up)". This matches D6's `catchUpDue` (design.md:88), the spec requirement "The server checks for a new build every day", its scenarios "Restart across 12:00 UTC" and "Restart after today's check", and the Flow & State Gaps "Restart mid-operation" entry. No text in design.md or the delta specs still states the 24-hour rule. The only mention left is S4's rejected alternative, "catch-up after 24 h (review round 1)" (design.md:146), which is correct as a rejected option.
- **M3. The spec requires a comparison for every import.** Fixed (first re-check). Accepted.
- **M4. The raw-record diff join does not match how keys are stored.** Fixed (first re-check). Accepted.
- **M5. Carried constraints miss the rule that the switch runs under the lock.** Fixed (first re-check). Accepted.
- **M6. The daily schedule sits outside the pure-Dart job package, against ADR 0009.** Fixed (first re-check). Accepted.
- **M7. The THEN in "Switch fails" cannot be asserted as written.** Fixed (first re-check). Accepted.

### Suggestions

- **S1.** Applied (kind values `forward` and `rollback`). Accepted.
- **S2.** Applied (a rollback clears `held` on the build it makes active). Accepted.
- **S3.** Applied (the diff task reads in one `REPEATABLE READ READ ONLY` transaction). Accepted.
- **S4.** Noted under Risks / Trade-offs. Accepted.
- **S5.** Applied. The requirement body now reads "Before a forward switch to a newer build, the server SHALL compare …" (specs/static-data-builds/spec.md:77). This agrees with D2, which gives `RollbackJob` no diff, with D5's `forward` kind, and with the "at most 2" bound on `sde_build_diff` rows. The requirement title, "Each build switched to is compared with the build it replaces", still reads wider than its body, because a rollback also "switches to" a build. The body governs, and the scenarios all describe forward switches, so this has no assertable consequence. If you want an exact match, the title could say "Each build forward-switched to …". This is optional.
- **S6.** Applied. D6 step 1 (design.md:89) places `staticDataRuntime` in `server/kaname_server/lib/src/static_data/`, not exported, so the hook and the future call can both import it. Tests set the holder and clear it with a `@visibleForTesting` `reset()`. See S8 for a follow-on.
- **S7.** Applied. C5 (design.md:176) now carries D4's per-record rule. A non-empty key that occurs exactly once on each side is paired. Empty or repeated keys are compared as a multiset of `(key, record)` per file, with added and removed counts only. The two texts agree.
- **S8 (new).** `@visibleForTesting` needs a direct `meta` dependency in the server package. It comes from `package:meta`, and `server/kaname_server/pubspec.yaml:10-19` does not list `meta` as a direct dependency. With the `lints` package's `depend_on_referenced_packages`, importing it without a direct dependency produces an analyzer warning, and `mise run check` runs analyze. Adding `meta` is a dependency change, so it also needs `mise run notices`. Either name that step in the task that adds the holder, or replace the annotation with a plain doc-commented `reset()`.

No new contradiction: the edits since the first re-check change only design.md:258, C5, D6's holder sentence and the comparison requirement's body. Each now agrees with D2, D4, D5, D6, the Failure, Resource Bounds and Flow tables, and the delta specs. The main specs under openspec/specs/ contain no catch-up, rollback or comparison rule that these edits touch.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

Status after the second re-check: all applied.

1. (M1) Applied.
2. (M2) Applied. The "CCP unreachable during a check" Failure & Visibility row now states the D6 catch-up rule (design.md:258).
3. (M3) Applied.
4. (M4) Applied.
5. (M5) Applied.
6. (M6) Applied.
7. (M7) Applied.

CHANGES_APPLIED: yes

## Rebuttals

- **M1:** fixed. `specs/static-data-import/spec.md` adds a MODIFIED "An import starts when no build is active": the start-up check imports; "Restart with an active build" imports only when the check finds a newer build that is not held; "First start offline" writes no import record and a failed check record. Accepted by reviewer.
- **M2:** fixed, after the owner agreed to the S4 and D6 changes. The catch-up runs when no build is active or no check has started since the most recent 12:00 UTC (design D6, spec "The server checks for a new build every day", with new scenarios "Restart across 12:00 UTC" and "Restart after today's check"). `checkedAt` is the job's start time. The overdue-row claim is removed from Flow & State Gaps and A2. The future call reaches the supervisor through the `staticDataRuntime` holder, published before scheduling, and awaits `supervisor.ready`. Accepted by reviewer. The remaining row was fixed after the first re-check (see below), and the second re-check accepts it.
- **M3:** fixed, after the owner agreed to the S3 change ("compare at switch"). The requirement is now "Each build switched to is compared with the build it replaces". A staged build gets no report until it is switched to (new scenario "Build imported by the development task"). The "First build" THEN is "no report is stored". Accepted by reviewer.
- **M4:** fixed. D4 classifies `sde_record` rows per record (`sde_ingest.dart:169-174`, `:98`, `:154-155`): a key that occurs exactly once on each side is paired, and every other record is compared as a multiset of `(key, record)` per file. Accepted by reviewer.
- **M5:** fixed. New C7: every switch and rollback takes the lock and changes states in one transaction on its connection, never through the main isolate's ORM (doc comment on `StaticDataStore`). Accepted by reviewer.
- **M6:** fixed, after the owner agreed to the D6 change. `DailyBuildCheckSchedule` in `kaname_static_data` declares the cron and `catchUpDue`, and the server adapts it into the future call (D6, new C8). Accepted by reviewer.
- **M7:** fixed. "Switch fails" uses a failing statement with Postgres reachable. The Failure table records the unreachable case in the log only. Accepted by reviewer.
- **S1:** applied. The kind values are `forward` and `rollback`. Accepted by reviewer.
- **S2:** applied. A rollback clears `held` on the build it makes active (D2, spec scenario "Rollback"). Accepted by reviewer.
- **S3:** applied. The diff task reads in one `REPEATABLE READ READ ONLY` transaction (D7). Accepted by reviewer.
- **S4:** noted under Risks / Trade-offs. The first change that adds another future call raises the concurrency limit, or lets this call return once the request has been handed to the worker. Accepted by reviewer.

Author, after the first re-check:
- **Required Change 2 (remaining row):** fixed. The "CCP unreachable during a check" row of Failure & Visibility now reads "or a start after the next 12:00 UTC (D6 catch-up)". Accepted by reviewer.
- **S5:** applied. The requirement text reads "Before a forward switch to a newer build"; a rollback is never compared. Accepted by reviewer (optional title wording noted under S5).
- **S6:** applied. D6 names the holder's real visibility (in `lib/src/static_data/`, not exported) and its `@visibleForTesting` `reset()`. Accepted by reviewer (dependency follow-on in S8).
- **S7:** applied. C5 states the per-record rule from D4. Accepted by reviewer.
