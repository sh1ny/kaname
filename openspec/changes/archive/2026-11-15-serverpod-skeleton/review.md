# Review

## Metadata

- **Round:** 6
- **Prior round:** Round 5 re-check of commit 3005672 (D5 `dart build cli` amendment) returned APPROVE_WITH_CHANGES with one Required Change, R5-1 (M-2: native libraries bundled by pub build hooks were outside every carried licence gap). The round 3 Required Changes R3-1 and R3-2 stayed applied. Suggestions S-16 to S-19 were added, and S-6 to S-15 and round 2's S-2 to S-5 were carried forward.
- **Run:** Required Changes re-check of commit b49de65 (author's application of R5-1, plus S-16 and S-19). This is not a full re-review. In scope: whether R5-1 is applied as written, and whether the edits in b49de65 introduced a contradiction. Everything else is carried forward unchanged.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** `git show b49de65` (design.md :74, :184, :197; review.md round 5); openspec/changes/serverpod-skeleton/{design.md (D5 :70-86, A6 :184, C5-C10 :193-201), review.md (round 5), tasks.md at b49de65 (group 5 :97-101, group 6 task 6.6 :110) and its uncommitted work-tree diff (5.1-5.3 ticked), proposal.md (:45), specs/server-runtime/spec.md (grep)}. Tracked: tools/kaname_tools/lib/src/licences.dart:1-11. Uncommitted group 5 work, read as evidence of intent only: deploy/server.Dockerfile (:18, :40-41, :72-82). Project skill loaded: serverpod-deployment (loaded; no deployment action is in scope). No referenced stores.

## Findings

### Required Changes re-check

| Item | Status | Evidence |
|---|---|---|
| R5-1 (M-2): C6 replaced with the review's exact first sentence, single destination kept | Applied | design.md:197 now reads, word for word, the sentence R5-1 gave: container image licences (Postgres, Redis, Caddy, Debian) and the hook-bundled native libraries (`libsqlite3`, SQLite, public domain; `libsqlite3_connection_pool` with Rust `lru` and std, MIT/Apache-2.0) are outside the pub licence check, THIRD_PARTY_NOTICES' generated section and the SBOM, with the publish/hook-package trigger. `Kind: deliberate gap. Destination: doc comment: tools/kaname_tools/lib/src/licences.dart LicencesCommand` is unchanged. No `Chosen by: user` decision is touched. M-2 is closed. |
| S-16: D5 runtime stage names `lib/` | Applied, consistent | design.md:74 now says the runtime stage holds `bin/`, `lib/`, `config/` and `migrations/`, which agrees with the build-stage bullet (:73, "the runtime stage copies both") and with the work-tree Dockerfile (`COPY --from=build /out/bundle/ ./`, :72; `ENTRYPOINT ["./bin/main"]`, :82). |
| S-19: A6 marked checked | Applied, consistent with D5 | design.md:184 records "Checked in task 5.2: `mise install --locked flutter` installs it from `mise.lock` with its checksum verified, without the other tools." This matches D5's "runs `mise install flutter` in locked mode" (:73) and the work-tree Dockerfile (:41, `mise install --locked flutter`). See S-21 for timing. |
| Contradiction with proposal or specs | None | proposal.md:45 names only container images as outside the licence check. C6 is now broader, but the proposal does not say nothing else is outside it, so the two do not conflict. No spec names C6 or the bundled libraries. The ci-matrix C5 doc comment (licences.dart:6-11) covers different code (platform package managers and the Flutter engine) and does not overlap C6. |
| Scope of b49de65 | Confined | Only design.md :74, :184, :197 and review.md change. No proposal, spec or other decision is edited, so the verdict is not voided. |

### Critical (blocking)

None.

### Moderate

None. M-2 is closed by R5-1.

### Suggestions

- **S-20 (task 6.6 still carries C6's old wording).** tasks.md:110 says: "Write C6 as part of the doc comment on `LicencesCommand` ...: container image licences (Postgres, Redis, Caddy, Debian) are outside the pub licence check and the SBOM." That is the pre-R5-1 text. An implementer who writes the task's summary instead of design.md:197 would leave the hook-bundled native libraries out of the doc comment, which is exactly the gap R5-1 records, and the pre-ship check of C6 at its destination would then fail. Update 6.6 to point at C6 as written in design.md:197 (or quote it), so the task and the design agree. tasks.md is outside this verdict, so this does not void it.
- **S-21 (A6 is marked checked before task 5.2 is committed).** At b49de65, design.md:184 says A6 was "Checked in task 5.2", while tasks.md at the same commit still has 5.2 unticked. Ticking 5.2 only exists in the uncommitted work tree. This resolves itself when group 5 is committed. If group 5 is reworked first, make sure the A6 note still matches what the build showed.
- **S-17 (carried forward unchanged from round 5).** The "`dart compile exe` refuses hooks" claim has neither a citation nor a checked assumption.
- **S-18 (carried forward unchanged from round 5).** The sqlite3 hook adds a build-time network fetch; note it in Risks or the deploy README.
- **S-12 (carried forward unchanged from round 4).** Local `server:drift` failures leave intent-to-add index entries, and the design has no Failure/State note about them.
- **S-13 (carried forward unchanged from round 4).** The drift task's scope is the test tools directory, but D7 names only the file.
- **S-14 (carried forward unchanged from round 4).** The wording of tasks 2.2 and 2.4 lags D7.
- **S-15 (carried forward unchanged from round 4).** The mise.toml comment says "commit" where `git diff` compares with the index. The evidence and the task's `--stat` form should also be aligned.
- **S-11 (carried forward unchanged from round 3).** The `serverpod` exception's reason in licence-policy.yaml should cite "ADR 0002; design D13".
- **S-8 (carried forward unchanged from round 3).** The SBOM records no licence for a package excepted as `unrecognised`.
- **S-9 (carried forward unchanged from round 3).** A7 (design.md:185) should be marked checked, because task 1.1 is ticked.
- **S-10 (carried forward unchanged from round 3).** The THEN at specs/server-runtime/spec.md:14 cannot be asserted literally.
- **S-6 (carried forward unchanged from round 2).** The WHEN of the scenario "An analysis info" should say "hand-written code".
- **S-7 (carried forward unchanged from round 2).** C9 is still listed before C8 (design.md:199-200).

S-16 and S-19 are applied (see the table). Round 2 Suggestions S-2 to S-5 remain as they were.

## Verdict

Commit b49de65 applies R5-1 word for word: C6 (design.md:197) now records the hook-bundled native libraries (SQLite; Rust `lru` and std inside `libsqlite3_connection_pool`) as a deliberate gap beside the container image licences, with the trigger that a change publishing the image or bringing a hook package into a distributed app must add their notices first, and its single destination is unchanged. The two Suggestion edits (D5 runtime stage naming `lib/`, A6 marked checked) agree with the build-stage bullet, with each other and with the work-tree Dockerfile. No edit contradicts the proposal, the specs or another decision. The only remaining mismatch is outside the design: task 6.6 still summarises the old C6 (S-20). The round 3 Required Changes stay applied.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R3-1 (C-1).** Applied under the owner's option (b) (dfac727). Unaffected by b49de65.
2. **R3-2 (M-1).** Applied (design.md:201, C10). Unaffected by b49de65.
3. **R5-1 (M-2).** Applied in b49de65 (design.md:197, C6, exact wording, destination kept). Re-checked by reviewer.

CHANGES_APPLIED: yes

## Rebuttals

- C-1: fixed in dfac727 (ADR 0002 amended in place, option (b), owner decision). Accepted by reviewer.
- M-1: fixed in dfac727 (C10 added). Accepted by reviewer.
- M-2: fixed in b49de65 (C6 extended per R5-1). Accepted by reviewer.
