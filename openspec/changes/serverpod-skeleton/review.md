# Review

## Metadata

- **Round:** 5
- **Prior round:** Round 4 re-check of commit ae70576 (D7 and A9) returned APPROVE_WITH_CHANGES. The round 3 Required Changes R3-1 and R3-2 stayed applied. Suggestions S-12 to S-15 were added, and S-6 to S-11 and round 2's S-2 to S-5 were carried forward.
- **Run:** amendment re-check of commit 3005672 (design.md D5 build stage and its `Chosen by` line, task 5.2 wording), after drift found during apply group 5. This is not a full re-review. In scope: whether `dart build cli` contradicts the `server-runtime` requirement "The server image takes its toolchain from mise" and its scenarios, C5, the State, Failure and Resource sections, or the licence and notices story now that the image bundles native libraries.
- **Reviewer:** fresh-context subagent (Claude Code, specwright-reviewer design-review mode)
- **Reviewed:** `git show 3005672`; openspec/changes/serverpod-skeleton/{proposal.md (:26, :42, :45), design.md (full; D5 :70-86, C5/C6 :196-197, State :243-253, Failure :255-266, Resource Bounds :268-276, Mechanism Ledger :285-297, Risks :299-304), review.md (round 4), tasks.md (test map :17-19, group 5 :97-103), specs/server-runtime/spec.md (:53-66)}. Tracked: pubspec.lock:883-898 (sqlite3 3.9.1, sqlite3_connection_pool 0.2.17, both transitive), THIRD_PARTY_NOTICES (lines 205-206 and a grep for `lru`, `rust`, `public domain`), server/kaname_client/pubspec.yaml and app/pubspec.yaml at HEAD, tools/kaname_tools/lib/src/licences.dart:1-11 (ci-matrix C5 doc comment), docs/adr/0002 (:16), openspec/specs/third-party-notices/spec.md:1-25, the archived ci-matrix design and proposal (native-dependency gap). Uncommitted group 5 work, read as evidence of intent only: deploy/server.Dockerfile, deploy/server.Dockerfile.dockerignore, tools/kaname_tools/test/dockerfile_test.dart, and the work-tree tasks.md diff (5.1-5.3 ticked). Pub cache, read as package evidence: sqlite3-3.9.1/{hook/build.dart, lib/src/hook/compile/description.dart, lib/src/hook/asset_hashes.dart, LICENSE}, sqlite3_connection_pool-0.2.17/{hook/build.dart, Cargo.toml, Cargo.lock, LICENSE, lib/src/precompiled/}, serverpod_database-4.1.2/pubspec.yaml, sqlite_async-0.14.5/pubspec.yaml. `mise exec -- dart build cli --help` (Dart 3.13.7). Project skills loaded: serverpod-deployment and serverpod-overview (both loaded). No referenced stores.

## Findings

### Amendment re-check

| Item | Status | Evidence |
|---|---|---|
| Hooks premise: Serverpod pulls in packages with build hooks | Supported | pubspec.lock:883-898 locks `sqlite3` 3.9.1 and `sqlite3_connection_pool` 0.2.17 as transitive. `serverpod_database` 4.1.2's pubspec depends on `sqlite3: ^3.3.1`, and `sqlite_async` 0.14.5 depends on `sqlite3_connection_pool`. Both locked packages ship `hook/build.dart`. The claim that `dart compile exe` refuses hooks was not re-run here; the commit message records it as observed in group 5 (see S-17). |
| Output layout and entrypoint | Matches the tool | `dart build cli --help` (Dart 3.13.7) documents `<output>/bundle/bin/<executable>` and `bundle/lib/<dynamic libraries>`. The work-tree Dockerfile builds with `--output /out`, copies `/out/bundle/` to `/app` and uses `ENTRYPOINT ["./bin/main"]`, as D5 says. `config/` and `migrations/` sit beside it, and the working directory is `/app`. |
| Spec: Flutter and Dart only through mise, no version in a Dockerfile (C5) | Still holds | The compiler is still the mise-installed Dart (`mise exec -- dart build cli`), and the Dockerfile prints `mise exec -- dart --version` first, so the build log can show it ("Image matches the pinned toolchain"). The file states no Flutter or Dart version. Its only version is `MISE_VERSION`, which the spec does not restrict, and which the test ties to CI's pin. The work-tree test's five version patterns match none of the Dockerfile's instruction lines. |
| Spec: resolve exactly as `pubspec.lock` holds | Still holds, with a new build-time fetch | `dart build cli` adds one input outside pub: by default the sqlite3 hook downloads a precompiled `libsqlite3` from `github.com/simolus3/sqlite3.dart` releases (`description.dart` around :296-353). It checks the download against a SHA-256 table in the package itself (`asset_hashes.dart`, check at `description.dart` around :207-227). That package is pinned by sha256 in pubspec.lock, so the bytes stay pinned through the lockfile. `sqlite3_connection_pool` copies a prebuilt `.so` from its own `lib/src/precompiled/` (no fetch, no compiler). No contradiction. The new network dependency is noted under S-18. |
| Spec: "No secrets in the image", "Lockfile out of date" | Unaffected | The dockerignore and `flutter pub get --enforce-lockfile` are unchanged by the amendment. The bundle directory adds no context path. |
| State & Ownership, Resource Bounds | Unaffected | The bundled libraries are build outputs with no state. No queue or bound changes. |
| Failure & Visibility | Unaffected in kind | A failed hook download fails `docker build`, just like a failed mise or Flutter download, which already have no table row. The build stage already needed GitHub for mise. See S-18. |
| Scope of the amendment | Confined | 3005672 changes only design.md:73 and :86 and tasks.md:100. The proposal, the specs and the other decisions are untouched. The `Chosen by` line records the owner's approval. |
| Licence and notices story | Gap not carried | See M-2 below. |

### Critical (blocking)

None.

### Moderate

- **M-2 (native code bundled by build hooks is outside every carried licence gap).** Since `dart build cli`, the server image ships two native libraries, and their contents come from more than the pub packages that THIRD_PARTY_NOTICES lists.
  - `libsqlite3.so` is a precompiled SQLite build downloaded by the hook. SQLite is public domain, so it carries no notice obligation.
  - `libsqlite3_connection_pool.so` is a Rust `cdylib` (`sqlite3_connection_pool-0.2.17/Cargo.toml`). It statically links the `lru` 0.16.3 crate (`Cargo.lock`), which is MIT-licensed, and the Rust standard library, which is MIT OR Apache-2.0.

  THIRD_PARTY_NOTICES lists only the pub packages `sqlite3` and `sqlite3_connection_pool` (both MIT, lines 205-206) and has no entry for `lru`, Rust std or SQLite. The SBOM is built from pubspec.lock alone. Neither existing gap names this kind of code:
  - C6 (design.md:197) covers only container base images (Postgres, Redis, Caddy, Debian).
  - ci-matrix's C5 (licences.dart:6-11) covers "Gradle, CocoaPods or SwiftPM packages, and the Flutter engine's bundled components".

  ADR 0002:16 says "`THIRD_PARTY_NOTICES` lists every bundled dependency". The third-party-notices spec's purpose is to name "every bundled third-party asset".

  In M0 nothing is distributed: self-hosters build the image locally, and the app does not depend on sqlite3. HEAD's `kaname_client` depends only on `serverpod_client`, and `app` does not depend on `kaname_client`. So the licences are compatible, and nothing needs a notice yet. But the gap is unrecorded. A later change could publish the server image (the "later deployment guide" in D12), or add a client dependency that brings a hook package into the distributed apps. Either change would then ship MIT and Apache-2.0 code without its notices, and neither the licence check nor C6 would say so.

  This is a deliberate-gap carried constraint that the design does not list, so it is Moderate. Fix it with R5-1.

### Suggestions

- **S-16 (D5's runtime-stage bullet lags the build-stage bullet).** design.md:74 still says the runtime stage "holds the executable, `config/` and `migrations/`". The build-stage bullet (design.md:73) and the work-tree Dockerfile also put the `bundle/lib/` native libraries there. Add "and its `lib/` native libraries" to :74 so the two bullets agree. The work-tree test does not check that the runtime stage copies `bundle/lib`. For a Postgres-only server, sqlite3 is probably never loaded at run time, so omitting the libraries would probably go unnoticed rather than fail. That is a reason to state it in the design rather than rely on a failure.
- **S-17 (the "`dart compile exe` refuses hooks" claim has neither a citation nor a checked assumption).** The dependency chain is verifiable from tracked pubspec.lock:883-898. The tool behaviour that motivates the amendment exists only in the commit message. Record it as a checked assumption (for example, "A11: checked in task 5.2, `dart compile exe` exits with the build-hooks error"), or cite the evidence of the group 5 run, so that a later Dart upgrade can re-test it.
- **S-18 (build-time network fetch from the sqlite3 hook).** `docker build` now also fetches `libsqlite3` from the sqlite3.dart GitHub releases. The fetch is hash-verified against the locked package, so integrity holds. An offline builder, or one with only a proxy, now fails at `dart build cli`, not only at the mise and Flutter downloads, and the hook's own error message explains this. For example, add a line to the Risks list, or to the deploy README in group 6.
- **S-19 (A6 still reads "Not checked inside a container yet").** The work-tree tasks.md ticks 5.2 ("Verify A6 ... `docker build` succeeds on Linux"). When group 5 is committed, mark A6 (design.md:184) checked with what the build showed, as was done for A9 and A10.
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

Round 2 Suggestions S-2 to S-5 remain as they were.

## Verdict

Commit 3005672 replaces `dart compile exe` with `dart build cli`, and it is consistent with the `server-runtime` requirement "The server image takes its toolchain from mise" and its three scenarios, and with C5. The compiler is still the mise-installed Dart, no Dockerfile states a toolchain version, and the one new build input (the hook-downloaded `libsqlite3`) is hash-pinned through the locked sqlite3 package. The State, Failure and Resource sections need no new row. The amendment does open one gap in the licence story: the image now bundles native code (SQLite, plus Rust `lru` and std inside `libsqlite3_connection_pool`) that neither THIRD_PARTY_NOTICES, the SBOM, C6 nor ci-matrix's C5 covers (M-2). This harms nothing in M0, because nothing is distributed, but a future change that publishes the image or brings a hook package into the apps would not be warned. One Required Change records the gap. The round 3 Required Changes stay applied.

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. **R3-1 (C-1).** Applied under the owner's option (b) (dfac727). Unaffected by 3005672.
2. **R3-2 (M-1).** Applied (design.md:201, C10). Unaffected by 3005672.
3. **R5-1 (M-2).** In design.md:197, extend C6 and keep its single destination. Replace the entry's first sentence with: "Container image licences (Postgres, Redis, Caddy, Debian), and the native libraries that pub build hooks bundle into the server image (`libsqlite3`, SQLite, public domain; `libsqlite3_connection_pool`, which statically links the Rust `lru` crate and Rust std, MIT/Apache-2.0), are outside the pub licence check, THIRD_PARTY_NOTICES' generated section and the SBOM; the server image is built locally and not redistributed, so a change that publishes it, or that brings a hook package into a distributed app, must add their notices first." Keep `Kind: deliberate gap. Destination: doc comment: tools/kaname_tools/lib/src/licences.dart LicencesCommand`. This edits a carried constraint only and reverses no `Chosen by: user` decision.

CHANGES_APPLIED: no

## Rebuttals

- C-1: fixed in dfac727 (ADR 0002 amended in place, option (b), owner decision). Accepted by reviewer.
- M-1: fixed in dfac727 (C10 added). Accepted by reviewer.
- M-2: open (R5-1).
