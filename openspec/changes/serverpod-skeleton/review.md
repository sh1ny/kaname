# Review

## Metadata

- **Round:** 2
- **Prior round:** Round 1 returned REVISE (1 Critical, 9 Moderate, 4 Suggestions). Round 2 returned APPROVE_WITH_CHANGES with eight Required Changes (R2-1 to R2-6) and `CHANGES_APPLIED: no`.
- **Run:** Required Changes re-check run for round 2. Only the eight Required Changes and the author's application of round 1 suggestion #12 (round 2 S-1) are re-checked, together with whether the edits introduced a contradiction in the edited text. No full re-review was done.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** openspec/changes/serverpod-skeleton/proposal.md, design.md, specs/workspace-layout/spec.md, specs/server-runtime/spec.md (grep across all five delta specs for the edited terms), review.md (round 2); main spec openspec/specs/workspace-layout/spec.md (requirement "Analysis and formatting are clean", compared line by line with the MODIFIED delta). Owner decisions as relayed in the request: change 1 option (a), `platform: linux/amd64`, arm64 under emulation, no native arm64 commitment; change 2 one Redis password shared by development and test; change 4 only one checkout at a time runs the development Redis, stated in the design and the server README. Project skills loaded: serverpod-overview, serverpod-configuration, serverpod-deployment, dart-run-static-analysis (all four loaded). No referenced stores.

## Findings

### Required Changes: re-check

| # | Status | Evidence |
|---|---|---|
| 1 (R2-1, platform) | Applied | D5 gains a **Platform** bullet: `server` and `migrate` set `platform: linux/amd64`, and arm64 hosts build and run under emulation, with no native arm64 commitment (design.md:76). The D5 summary row names `linux/amd64` (design.md:159), and D5's Chosen by line records the round 2 pin (design.md:86). A6 names linux-x64 under `platform: linux/amd64` (design.md:175). The `server-runtime` scenario "Supported platform stated" now says `linux/amd64` container, arm64 under emulation (specs/server-runtime/spec.md:104-106). This matches the owner's option (a). |
| 2 (R2-2a, one Redis password) | Applied | D11 generates one Redis password shared by `development` and `test`, plus per-mode database passwords and service secrets, and rewrites `.env` from `passwords.yaml` (design.md:130). The D11 summary row (design.md:165), C8 (design.md:191) and the State & Ownership row (design.md:243) all say the same. D6's `.env` source (design.md:90) is consistent with it. |
| 3 (R2-2b, CI Redis source) | Applied | D3 now reads "used by the stack and by the server package's development Compose file (which the CI `server` job also starts)" (design.md:56). proposal.md:12 now reads "a container from the server package's development Compose file in CI tests". No "service container" wording is left in the proposal, design or specs (grep). |
| 4 (R2-2c, concurrent checkouts) | Applied | Flow & State Gaps "Concurrent checkouts" says that only one checkout at a time runs the development Redis and that the server README says so (design.md:273). This matches the owner's decision. |
| 5 (R2-3, analysis exclusion) | Applied | specs/workspace-layout/spec.md:3-26 adds MODIFIED "Analysis and formatting are clean". It keeps every in-force sentence and all four in-force scenarios (compared with openspec/specs/workspace-layout/spec.md:61-78), adds the exclusion with generated code still format-checked, and adds the scenario "Generated code". C9 names that requirement as its only destination (design.md:190). |
| 6 (R2-4, build context) | Applied | D5's **Build context** bullet adds a deny-by-default `deploy/server.Dockerfile.dockerignore` (the Dockerfile-specific ignore file beside `deploy/server.Dockerfile`) that excludes `**/config/passwords*.yaml`, `**/.env*` and `**/.serverpod/` (design.md:77). The scenario "No secrets in the image" sits under "The server image takes its toolchain from mise" and asserts no `passwords.yaml` and no `.env` (specs/server-runtime/spec.md:60-62). |
| 7 (R2-5, unhealthy recovery) | Applied | The `server` row now covers container exit only (design.md:250). A new row says that an unhealthy server is marked unhealthy but not restarted, is recovered by hand, and is seen in `docker compose ps` (design.md:251). |
| 8 (R2-6, claim and command) | Applied | design.md:24 cites the global `-C, --cd` flag in `mise --help`. proposal.md:25 gives the command exactly as the design does: `mise exec -C server/kaname_server -- dart run serverpod_cli:serverpod mcp-server --server-dir .`. |
| S-1 (round 1 #12, digest pins) | Applied | D3 says that the stack's `postgres:16` and `caddy:2` images are digest-pinned the same way as Redis (design.md:56). This matches "Postgres 16+" in S2 and the proposal. |

### Critical (blocking)

None.

### Moderate

None. All eight Required Changes are applied as written.

### Suggestions

- **S-6 (wording left over from change 5, not blocking).** The scenario "An analysis info" was copied verbatim, so it still says "**WHEN** any package contains code that produces an analysis info" (specs/workspace-layout/spec.md:12-14). The requirement text now limits the rule to hand-written code, and the new "Generated code" scenario says generated infos are not reported. Read on its own, the copied scenario pulls the other way. The specific scenario and the requirement text settle the conflict, so it does not block. When the spec is next edited, change the WHEN to "any package contains hand-written code that ...", so the scenario no longer conflicts with "Generated code". Note that this edit would itself touch the reviewed spec.
- **S-7 (cosmetic).** C9 comes before C8 in `## Carried constraints` (design.md:190-191). Putting them in numeric order would make the IDs easier to scan.

Round 2 Suggestions S-2 to S-5 are outside this re-check and remain as they were.

## Verdict

Every Required Change from round 2 is applied as written, and each owner decision (changes 1, 2 and 4) is reflected as relayed. The edits introduced no contradiction that blocks. The one wording tension is recorded as S-6.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R2-1.** In D5 and A6, state that the image targets `platform: linux/amd64` for `server` and `migrate`, with arm64 under emulation. Update the `server-runtime` scenario "Supported platform stated", the D5 entry and its summary row. Applied (design.md:76, 86, 159, 175; specs/server-runtime/spec.md:104-106).
2. **R2-2a.** In D11, use one Redis password for development and test, and derive `.env` from it. Update C8 and the State & Ownership row. Applied (design.md:130, 165, 191, 243).
3. **R2-2b.** Remove the CI service-container wording from D3 and proposal.md:12, and name the server package's development Compose file instead. Applied (design.md:56; proposal.md:12).
4. **R2-2c.** State in Flow & State Gaps that only one checkout at a time runs the development Redis, and say so in the server README. Applied (design.md:273).
5. **R2-3.** Add MODIFIED "Analysis and formatting are clean" with the generated-code exclusion and a scenario for it, plus a carried constraint with that requirement as its destination. Applied (specs/workspace-layout/spec.md:3-26; design.md:190).
6. **R2-4.** Add a deny-by-default build-context ignore file to D5, and a scenario that the image holds no `passwords.yaml` and no `.env`. Applied (design.md:77; specs/server-runtime/spec.md:60-62).
7. **R2-5.** Correct the Failure & Visibility `server` row so that it separates container exit from the unhealthy case. Applied (design.md:250-251).
8. **R2-6.** Cite `mise --help` for `-C`, and give the proposal's MCP command in the design's form. Applied (design.md:24; proposal.md:25).

CHANGES_APPLIED: yes

## Rebuttals

None needed. Each Required Change was fixed at the lines cited above.
