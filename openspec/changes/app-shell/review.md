# Review

## Metadata

- **Round:** 1 (second re-check of Required Changes)
- **Prior round:** re-check left N1 open (APPROVE_WITH_CHANGES, CHANGES_APPLIED: no)
- **Reviewer:** fresh-context subagent (Claude Code specwright-reviewer)
- **Reviewed:** openspec/changes/app-shell/review.md (prior run), design.md (D2, D3, D8, D9, the decision summary, Carried constraints, Failure & Visibility, Resource Bounds, Risks), proposal.md Impact line 51, specs/app-shell/spec.md (not-found requirement, lines 76-84). Dependency source used as evidence for the client time-out (outside the repo, not cited by the design): serverpod_client 4.1.2 `lib/src/serverpod_client_io.dart:44,66` and `lib/src/serverpod_client_browser.dart:79`. Skill loaded: flutter-setup-declarative-routing. Scope: only N1, plus the applied suggestions S-f, S-g and S-h, checked for new problems.

<!-- This verdict covers only the contents reviewed. Editing proposal, specs or design afterward (other than applying Required Changes, or an edit confined to the proposal's `## Release Notes` section) voids it. -->

## Findings

### Earlier findings, re-checked

- **Round 1 M1-M7 (RC1-RC7):** verified in the previous re-check. Not re-opened.
- **N1 (client time-out claim) → Required Change 1: fixed.** D3 (design.md:49) now says `connectionTimeout` limits opening the connection and makes the client stop waiting for an answer after 10s, but does not abort the HTTP request underneath. It calls the notifier's `Future.timeout` "a backstop of the same kind" and keeps single-flight over the logical call. It says that each "Check again" after a time-out can leave at most one more abandoned request open per press, until the server, Caddy, the OS or the browser closes it, and that aborting requests would be a new decision. The source supports this: `HttpClient.connectionTimeout` is set at `serverpod_client_io.dart:44`, and the response wait is a `.timeout(connectionTimeout)` on the post future at `serverpod_client_io.dart:66` and `serverpod_client_browser.dart:79`. Neither cancels the request. The Resource Bounds row "Health calls in flight" (design.md:234) matches. The owner's choice in D3 and its summary row are unchanged. The Mechanism Ledger row "10s client time-out" (design.md:253) claims only that "Checking" does not hang, which stays true.
- **S-f (hosting of `/not-found`): applied, no new problem.** D2 (design.md:37) puts the route in a hidden branch. The registry does not list that branch, and the rail and bottom bar do not show it. It renders in the frame with no destination selected. The Branch navigators row (design.md:236) counts 5 in M0: the four registry slots (Home, Personal, Organisation, Settings, per S1 and the diagram) plus the hidden branch. This matches the spec's "not-found state inside the shell" (specs/app-shell/spec.md:76,84). C9 (bottom bar past about five slots) still holds, because the hidden branch is never a bottom-bar item. C11 (lazy branches) keeps the hidden branch unbuilt until an unknown path is visited.
- **S-g (dependency count): applied, no new problem.** Risks (design.md:266) names six dependencies. The proposal's Impact (proposal.md:51) also lists `flutter_web_plugins` and `kaname_client`, so the count in Risks is a subset; see suggestion S-i.
- **S-h (D9 order): applied.** D9 now follows D8 (design.md:100-106). Its text matches the D9 the previous re-check verified, and the summary table order is D1-D9.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

**S-i.** Risks (design.md:266) counts `flutter_localizations`, an SDK package, but leaves out `flutter_web_plugins`, also an SDK package, which the proposal's Impact lists. Either count only the pub.dev packages (five, as A3 lists them) or add `flutter_web_plugins`. This is cosmetic: the licence check covers the lockfile either way.

**S-j.** The "At 10x / 100x" cell of the Branch navigators row (design.md:236) still says "19 modules = 19 branches". With the hidden not-found branch it is 20 (19 module branches plus the hidden one, if Settings counts as one of the 19). This is cosmetic.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **D3 and the Resource Bounds "Health calls in flight" row (N1):** correct the claim about the client time-out. Applied and verified in this run (design.md:49, design.md:234).

CHANGES_APPLIED: yes

## Rebuttals
