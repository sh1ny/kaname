# Review

## Metadata

- **Round:** 3
- **Prior round:** Round 2 (openspec/architecture-review.md) returned APPROVE_WITH_CHANGES with three Moderates (worker-isolate access to Postgres, Redis and the bus; the token-refresh crash window; static data for mobile solo-lite) and three Suggestions. All ten Required Changes were applied exactly (CHANGES_APPLIED: yes). The owner accepted the narrowing of R52 and left R56 and R57 pending. Round-2 S3 (the in-force table) is now resolved: all eleven ADRs are accepted and listed in architecture.md's In-force ADRs table.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer)
- **Reviewed:** openspec/strategy.md, openspec/architecture.md, docs/adr/0001 to 0011 and openspec/roadmap.md on `docs/project-baseline`, focusing on the one uncommitted edit since round 2: the third Consequences bullet of docs/adr/0001-stack-platforms-and-deployment.md (line 22). Checked against roadmap M0 (roadmap.md:13, :25), strategy R12 (strategy.md:53), R21 (strategy.md:62) and AGENTS.md:9. No skills loaded; none were named. No packs and no referenced stores.

## Findings

**Scan results.** The edited line names no third-party EVE tool, no private path and no URL. The rest of the reviewed set is unchanged since round 2's scan.

**The edit.** Old: "Windows desktop builds need a Windows machine. CI covers the other targets (roadmap M0)." New: "CI builds every target, Windows included, on Linux, Windows and macOS runners (roadmap M0, R21). Local Windows desktop builds and runs need the separate Windows machine."

- **Roadmap M0:** consistent. roadmap.md:13 says CI on Linux, Windows and macOS runners builds web, Windows, Linux, macOS, Android and iOS, and roadmap.md:25 (`ci-matrix`) says three-OS build for all six targets. The old text ("CI covers the other targets") contradicted this, so the correction is right.
- **R21:** consistent. strategy.md:62 chooses Linux, Windows and macOS runners and all six targets from M0. The new text does not repeat "(no codesign)", which is acceptable because it cites R21 instead of restating the rule.
- **AGENTS.md:9 and R12:** consistent in substance. Both say a separate Windows clone is used only to build and run the Windows desktop app, which is what "local Windows desktop builds and runs" describes. R12's rationale "Windows builds need Windows" still holds for local builds and does not conflict with CI.
- **Scope of the edit:** it changes a Consequence, not the Decision, and it now matches a `Chosen by: user` row (R21), so it re-litigates nothing.
- **New contradictions:** none found. No other file in the set mentions Windows builds, a Windows machine or the CI matrix in a conflicting way. The architecture.md index entry for ADR 0001 (Serverpod, Postgres, Redis, one Flutter app, Docker Compose, one instance) is unaffected.

### Critical (blocking)

None.

### Moderate

None.

### Suggestions

**S1. Name the clone, not "the separate Windows machine" (ADR 0001:22).** ADR 0001 has not introduced a "separate Windows machine", so the definite article points at nothing within the ADR. R12 and AGENTS.md:9 both say "a separate Windows clone". For example: "Local Windows desktop builds and runs use the separate Windows clone (R12)."

**S2. Land this edit before the baseline merges (ADR 0001 status).** ADR 0001 is `accepted` as of commit 167cc9b, and the specwright schema (schema.yaml, ADR RULES) says accepted ADRs are immutable and need a superseding ADR instead of an edit. This edit is acceptable because the ADR has not reached `main` yet: the baseline PR is still under review, and the edit corrects that PR's own content. Commit it on `docs/project-baseline` before the PR merges. After the merge, any further change to an accepted ADR needs a superseding ADR.

## Verdict

The edit is correct. It removes a real contradiction with roadmap M0 and R21, agrees with R12 and AGENTS.md:9, and adds no new inconsistency. The two Suggestions are optional wording and process notes, so no change is required.

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals

None.
