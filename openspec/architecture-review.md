# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 returned REVISE with 13 Moderate findings (Redis optional or required, multi-instance workers, scheduler atomicity, token refresh races, the one-holder rationale, push-path privacy, offline caches, login scopes, solo job reuse, redundant job locks, the fit-engine rejection reason, hot-loop bounds, LWW ordering) and 10 Suggestions, with no Critical findings.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer)
- **Reviewed:** openspec/strategy.md, openspec/architecture.md, docs/adr/0001-stack-platforms-and-deployment.md through docs/adr/0011-fit-engine-behind-an-interface.md (uncommitted drafts on `docs/project-baseline`), checked against round 1 in openspec/architecture-review.md. Context only: AGENTS.md, openspec/specwright.yaml and the specwright review template. All nine named skills loaded: serverpod-overview, serverpod-server-events, serverpod-scheduling, serverpod-models, serverpod-database, serverpod-auth (plus its references/setup.md for custom identity providers), flutter-apply-architecture-best-practices, codebase-design and domain-modeling. No ADRs are in force yet: all eleven are `proposed`, and the architecture's in-force table is empty. No packs and no referenced stores.

## Findings

**Scan results.** None of the reviewed files mentions a third-party EVE tool or product other than CCP's services (ESI, SSO, SDE, image server, Tranquility), EVEShipFit's engine and the owner's kumiko. The other names are dependencies, integration targets or agent runtimes: Serverpod, Flutter, Riverpod, go_router, Bloc and melos (as rejected options), drift, Postgres, Redis, Caddy, Discord, UnifiedPush/ntfy, FCM/APNs, Mumble, Claude Code, Codex and OMP. No file contains a private machine path, a URL or a private link. ADR 0003:9 cites Serverpod's documentation by title only.

**Round-1 resolution check.**

| Round 1 | Status | Evidence |
|---|---|---|
| M1 Redis optional vs required | Resolved | ADR 0001:13, :25; ADR 0008:9, :30; R30, R48 |
| M2 per-instance workers | Resolved (one instance in 1.0) | ADR 0001:14, :21, :26; ADR 0009:26; R48; architecture.md:96 |
| M3 scheduler atomicity | Resolved | ADR 0007:16-17, :56; architecture.md:38, :66; R52 |
| M4 refresh crash window and races | Partly resolved: single-flight added, but the crash-window recovery is wrong (see M2 below) | ADR 0007:37-40; architecture.md:63 |
| M5 one-holder rationale | Resolved | ADR 0005:9, :37; R26 |
| M6 push-path privacy | Resolved | ADR 0006:9, :13-14, :26; ADR 0008:21; R54 |
| M7 offline caches after revoke | Resolved (residual wording, S1) | ADR 0006:17, :30; architecture.md:46, :69; R49 |
| M8 login scopes | Resolved | ADR 0006:18, :31; ADR 0007:41-43; R50 |
| M9 solo job reuse | Resolved | ADR 0009:21, :33; ADR 0005:21; architecture.md:52; R53 |
| M10 redundant job locks | Resolved | ADR 0009:17, :21, :34; R53 |
| M11 fit-engine rejection reason | Resolved | ADR 0011:20; R55 |
| M12 hot-loop bounds | Resolved | ADR 0007:26-31; architecture.md:89 |
| M13 LWW ordering | Resolved as an explicit open item | ADR 0008:17; R51 |
| S1 to S8, S10 | Resolved | compute worker (ADR 0009:25); three builds (ADR 0004:16, architecture.md:64, :91); queue and log bounds (architecture.md:94-95); isolate naming (architecture.md:7); ADR 0010:20; ADR 0003:9; ADR 0006:21-22; ADR 0004:27; R34 |
| S9 in-force table | Still open (expected until acceptance); see S3 |

### Critical (blocking)

None.

### Moderate

**M1. Worker isolates have no stated way to reach Postgres, Redis or the bus, and "cross-isolate" Serverpod messages are not a documented capability (ADR 0001, ADR 0009, architecture).**
ADR 0001:13 says Redis "carries Serverpod's cross-isolate and cross-instance messages". ADR 0008:20 builds the `RealtimeBus` on Serverpod's message system, and ADR 0009:26 has workers talk to the main isolate "through typed messages and the `RealtimeBus`". The architecture has the realtime and compute workers writing Postgres and Redis directly (architecture.md:37), and the realtime worker spends ESI budget through "a Redis script" (ADR 0007:17) and refreshes tokens from the vault under a per-character lock (ADR 0007:37). The installed skills tie all of these to a Serverpod `Session`: the ORM and raw SQL take `session` (serverpod-database), and the message system is `session.messages`, delivered "locally within the server instance" or across instances through Redis (serverpod-server-events). No installed skill describes a spawned isolate getting a `Session`, or Serverpod messages crossing isolates. A worker started with `Isolate.spawn` therefore has no ORM, no bus and no Redis client unless the design gives it one. ADR 0006:13 also requires the Discord worker to apply the privacy scope, which needs policy data from Postgres. The change that adds the first worker (the compute worker's static-data import, before M11's loops) will have to pick between proxying all I/O through the main isolate, which puts import and loop load back on the endpoint isolate that ADR 0009:22 wants to keep free, and giving workers their own connections outside the ORM. R31's process model and its "medium" reversal cost (ADR 0009:35) rest on this choice, and nothing records it as open.

**M2. The token-refresh "retry after a crash window" cannot recover the crash it names (ADR 0007, architecture, R52).**
ADR 0007:38-39 saves the rotated token "as soon as CCP returns it" and says that "if the process dies between CCP's answer and the save, the next `invalid_grant` is retried once with the stored token, after the lock". After such a crash, the stored token is the old one, the same token that just produced `invalid_grant`, so retrying it gives the same answer. Either the old token is still accepted, and no `invalid_grant` occurs, or it is not, and the retry fails too. The retry only helps when another refresher saved a newer token between the read and the call, which the single-flight lock (ADR 0007:37) already prevents unless the lock expires. Architecture.md:63 and R52 repeat the claim as a recovery. Round 1 M4 asked for a precise statement of the crash window and its recovery. As written, a later change will build and test a retry believed to save tokens, while a crash in that window still kills the token and forces a re-login. The dead-token row (architecture.md:90) also omits this cause. The fix keeps the owner's mechanism and corrects only the claim about what it recovers.

**M3. Mobile solo-lite has no source of static data (ADR 0004 vs ADR 0005 and R17).**
ADR 0005:18 and R17 give mobile a solo-lite mode with no server. ADR 0004:19-22 gives apps static data only by fetching a bundle from the server, or, for solo desktop, by running the importer itself. The client-bundle row (architecture.md:65, "Server build job (solo: local importer)") says the same. Nothing says how a phone with no server gets type names, dogma data or anything else a personal module needs: whether it runs the importer on the device (a full JSONL build on a phone) or downloads a prebuilt bundle (from where, given that the project runs no central services, strategy.md:15). The mobile scope decision is deferred to M7 (R40), but the bundle format is fixed in M1 with a "high" reversal cost (ADR 0004:29). M1 should therefore know that this question is open, so that its format rules out neither answer.

### Suggestions

**S1.** ADR 0006:16 still says "revoking consent hides the data immediately", while ADR 0006:17 now says that for other viewers "a revoke takes effect for every viewer on their next fetch". An offline viewer whose app is still open keeps showing the in-memory copy until then. Align the two sentences, for example "hides it on the server immediately and from every viewer on their next fetch or stream update".

**S2.** Architecture.md:49 says the realtime worker "publishes on the RealtimeBus through the privacy scope". ADR 0006:13 defines the scope "for the delivering viewer", and the publisher has no viewer: the scope applies when each subscriber receives the event (ADR 0008:21). Say "events reach subscribers through the privacy scope", so that no one builds a publish-side filter that cannot know the audience.

**S3.** Carried from round 1 S9: once the ADRs are accepted, fill the in-force table (architecture.md:98-103). Until then, no change design review checks against these decisions.

## Verdict

There are no Critical findings. Eleven of the thirteen round-1 Moderates are fully resolved, and M7 is resolved apart from wording (S1). Three Moderates remain: one is round-1 M4 only partly resolved, and two are new. Each can be closed by correcting a claim and recording an open question as a pending owner decision, without choosing a design on the owner's behalf. The required changes below do that.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **ADR 0001:13 (M1).** Replace `It holds ESI rate-limit state and carries Serverpod's cross-isolate and cross-instance messages.` with `It holds ESI rate-limit state and per-character refresh locks, and backs Serverpod's global (cross-instance) messages.`
2. **ADR 0009, after line 26 (M1).** Add this bullet:
   > - **Open, settled by the first change that adds a worker isolate (strategy R56):** how a worker isolate reaches Postgres, Redis, the token vault, the privacy scope and the `RealtimeBus`. Serverpod's ORM and `session.messages` need a `Session`, which a spawned isolate does not have; the candidates are proxying through the main isolate over typed messages, or worker-owned connections behind the same interfaces.
3. **ADR 0007:39 (M2).** Replace the line with:
   >   - on `invalid_grant`, the refresher re-reads the stored token under the lock and retries once if it differs; this covers an expired lock, not a crash. A crash between CCP's answer and the save loses the rotated token: the token is marked dead and the member logs in again;
4. **architecture.md:63 (M2).** In the "Invalidation / rebuild" cell, replace `one retry after a crash window (ADR 0007)` with `a crash before the save means re-login (ADR 0007)`.
5. **architecture.md:90 (M2).** In the "On failure" cell, replace `Token marked dead, never retried` with `Token marked dead (revoked, or lost in a crash before save), never retried`.
6. **strategy.md:93, R52 (M2).** In the Choice cell, replace `with save-on-return and one retry after a crash window` with `with save-on-return and one re-read retry under the lock (a crash before the save still means re-login)`.
7. **ADR 0004:22 (M3).** Replace `  - solo desktop runs the importer itself.` with `  - solo desktop runs the importer itself; how mobile solo-lite gets static data is open (strategy R57), and the M1 bundle format must not rule out either importing on the device or downloading a prebuilt bundle.`
8. **strategy.md, after R55 (M1, M3).** Add two pending rows:
   `| R56 | init | Worker isolate access to Postgres, Redis, vault, privacy scope and bus (review round 2 M1) | Open, settle in the first change that adds a worker isolate | — | Serverpod's ORM and messages need a Session | yes | pending |`
   `| R57 | init | Static-data source for mobile solo-lite (review round 2 M3) | Open, settle with the mobile scope (R40); M1's bundle format keeps both options | — | No server to fetch a bundle from | yes | pending |`
9. **ADR 0006:16 (S1).** Replace `revoking consent hides the data immediately` with `revoking consent hides the data on the server immediately and from every viewer on their next fetch or stream update`.
10. **architecture.md:49 (S2).** Replace `publishes on the RealtimeBus through the privacy scope` with `publishes on the RealtimeBus; events reach subscribers through the privacy scope`.

CHANGES_APPLIED: yes

## Rebuttals

Re-check by a fresh-context reviewer subagent (Claude Code), limited to the ten Required Changes above, against the current working-tree drafts on `docs/project-baseline`. The owner was asked about Required Change 3, which narrows a user decision (R52), and accepted it. The owner chose to leave R56 and R57 pending. No finding was rebutted.

1. **ADR 0001:13 (M1): applied exactly.** The line now reads "It holds ESI rate-limit state and per-character refresh locks, and backs Serverpod's global (cross-instance) messages."
2. **ADR 0009:27 (M1): applied exactly.** The R56 open-item bullet follows the "Workers talk to the main isolate" bullet, with the text as specified.
3. **ADR 0007:39 (M2): applied exactly** (owner-accepted). The `invalid_grant` line now covers an expired lock only and says a crash before the save means a dead token and a new login.
4. **architecture.md:63 (M2): applied exactly.** The cell reads "a crash before the save means re-login (ADR 0007)".
5. **architecture.md:90 (M2): applied exactly.** The cell reads "Token marked dead (revoked, or lost in a crash before save), never retried".
6. **strategy.md:93, R52 (M2): applied exactly.** The Choice cell reads "with save-on-return and one re-read retry under the lock (a crash before the save still means re-login)".
7. **ADR 0004:22 (M3): applied exactly.** The solo bullet names R57 as open and says the M1 bundle format must not rule out either importing on the device or downloading a prebuilt bundle.
8. **strategy.md:97-98, R56 and R57 (M1, M3): applied exactly.** Both rows are present after R55 with the specified cells, and both are `pending` (the owner's choice).
9. **ADR 0006:16 (S1): applied exactly.** The line reads "revoking consent hides the data on the server immediately and from every viewer on their next fetch or stream update".
10. **architecture.md:49 (S2): applied exactly.** The cell reads "publishes on the RealtimeBus; events reach subscribers through the privacy scope".

None of the replaced wording remains in the edited lines. All ten Required Changes are applied, so the changes-applied marker is set to yes and the verdict is unchanged. S3 (fill the in-force table once the ADRs are accepted) is still expected to stay open until acceptance and had no Required Change.
