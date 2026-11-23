# Tasks

Skills for every implementer and reviewer packet (`.claude/skills/<name>/SKILL.md`): `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis`, `dart-add-unit-test`, `dart-build-cli-app`, `dart-use-path-package`, `flutter-implement-json-serialization`, `codebase-design`; with the "Dart and Flutter code" section of `AGENTS.md`. Run everything through `mise exec --` or `mise run`. Before any local test or build, run the owner's gaming check named in the brief; when it exits 1, skip local runs, rely on CI, and say so in the group's report.

## Test map

Test paths: `tools/kaname_tools/test/` (abbreviated `tools/…`) and `packages/kaname_esi/test/` (abbreviated `esi/…`).

| Requirement | Scenario | Test file | Test name | State |
|---|---|---|---|---|
| esi-client-generation → One pinned spec snapshot | Pin matches snapshot | tools/esi_repo_test.dart | committed snapshot hash and date match the pin | red |
| esi-client-generation → One pinned spec snapshot | Pin missing a field | tools/esi_pin_test.dart | pin without date, source or sha256 is refused by generate and check | red |
| esi-client-generation → Generation reads only pinned bytes | Pinned bytes accepted | tools/esi_generate_test.dart | generate parses a snapshot whose hash and date match the pin | red |
| esi-client-generation → Generation reads only pinned bytes | Pin date edited by hand | tools/esi_pin_test.dart | pin date differing from info.version or the header enum fails generate and check | red |
| esi-client-generation → Generation reads only pinned bytes | Snapshot edited by hand | tools/esi_pin_test.dart | snapshot hash mismatch fails generate and check and leaves output untouched | red |
| esi-client-generation → Deliberate fetch for a date bump | Fetch a listed date | tools/esi_fetch_test.dart | fetch writes snapshot and pin for the served date | red |
| esi-client-generation → Deliberate fetch for a date bump | Spec reports another date | tools/esi_fetch_test.dart | fetch refuses a spec reporting another date and changes nothing | red |
| esi-client-generation → Deliberate fetch for a date bump | Download fails | tools/esi_fetch_test.dart | fetch reports error, timeout or non-200 and changes nothing | red |
| esi-client-generation → Deliberate fetch for a date bump | Bad date argument | tools/esi_fetch_test.dart | fetch without a valid YYYY-MM-DD date prints usage and downloads nothing | red |
| esi-client-generation → Fetch writes and verifies | Re-read passes | tools/esi_fetch_test.dart | single fetch re-reads a matching pair and leaves no temp file | red |
| esi-client-generation → Fetch writes and verifies | Two fetches interleave in one checkout | tools/esi_fetch_test.dart | interleaved fetches with different hashes fail the late pin writer and check | red |
| esi-client-generation → Reproducible generation | Generate twice | tools/esi_generate_test.dart | second generate changes no byte | red |
| esi-client-generation → Reproducible generation | Unsupported construct in the snapshot | tools/esi_spec_reader_test.dart | unsupported construct names its JSON path and nothing is written | red |
| esi-client-generation → Drift check | Committed output current | tools/esi_repo_test.dart | esi check passes on the committed output and writes nothing | red |
| esi-client-generation → Drift check | Generated file edited by hand | tools/esi_check_test.dart | check names a hand-edited generated file | red |
| esi-client-generation → Drift check | Snapshot bumped without regenerating | tools/esi_check_test.dart | check names generated files that differ after a bump | red |
| esi-route-catalogue → One catalogue entry per operation | Complete catalogue | esi/catalogue_test.dart | catalogue has 208 entries, one per operation id | red |
| esi-route-catalogue → One catalogue entry per operation | Unknown operation id | esi/catalogue_test.dart | unknown operation id has no entry | red |
| esi-route-catalogue → Lookup by method and path template | Found by method and path | esi/catalogue_test.dart | lookup by method and path template finds the entry | red |
| esi-route-catalogue → Lookup by method and path template | Method not defined for the path | esi/catalogue_test.dart | DELETE on the assets path has no entry | red |
| esi-route-catalogue → Rate group per route | Route with a rate group | esi/catalogue_test.dart | alliance contacts carry alliance-social 300 per 15m | red |
| esi-route-catalogue → Rate group per route | Route without a rate group | esi/catalogue_test.dart | GET /alliances carries EsiRateGroup.none | red |
| esi-route-catalogue → Scopes and required roles per route | Scoped route with roles | esi/catalogue_test.dart | extractions carry the mining scope and Station_Manager | red |
| esi-route-catalogue → Scopes and required roles per route | Public route | esi/catalogue_test.dart | public route has no scopes and no roles | red |
| esi-route-catalogue → Cache behaviour per route | Route with stated cache facts | esi/catalogue_test.dart | /alliances cache facts as stated, cache mode absent | red |
| esi-route-catalogue → Cache behaviour per route | Route with no cache facts | esi/catalogue_test.dart | alliance icons have every cache fact absent | red |
| esi-route-catalogue → Pagination kind per route | Page-numbered route | esi/catalogue_test.dart | assets route is page-numbered | red |
| esi-route-catalogue → Pagination kind per route | Cursor route | esi/catalogue_test.dart | freelance jobs route is cursor-paginated | red |
| esi-route-catalogue → Pagination kind per route | Unpaginated route | esi/catalogue_test.dart | /alliances is unpaginated | red |
| esi-client → One typed method per operation | Every operation covered | esi/operations_test.dart (generated) | every operation sends its method and filled path | red |
| esi-client → One typed method per operation | Cursor value reaches the wire unchanged | esi/request_test.dart | cursor a+b/c= is encoded once as after=a%2Bb%2Fc%3D | red |
| esi-client → One typed method per operation | Required parameter left out | tools/esi_render_test.dart | required parameters render as required named arguments | red |
| esi-client → Requests carry the pinned compatibility date | Request built | esi/request_test.dart | assets request target, compatibility date and absent headers | red |
| esi-client → Requests carry the pinned compatibility date | Body request | esi/request_test.dart | POST /universe/names sends JSON [1,2] | red |
| esi-client → Requests carry the pinned compatibility date | Body outside the spec's bounds | esi/request_test.dart | empty id list is an invalid request and nothing is sent | red |
| esi-client → Optional and forbidden headers | Conditional request | esi/request_test.dart | If-None-Match carries the caller's ETag exactly | red |
| esi-client → Optional and forbidden headers | Language requested | esi/request_test.dart | Accept-Language only when the caller passes it | red |
| esi-client → The transport is the only way out | Fixture transport | esi/contract_test.dart | fixture transport answers and no connection is opened | red |
| esi-client → The transport is the only way out | Disallowed library imported | esi/guard_test.dart | disallowed dart: library in lib/ fails naming file and library | green |
| esi-client → The transport is the only way out | Import leaves the package | esi/guard_test.dart | import, export or conditional URI leaving lib/ fails naming file and URI | green |
| esi-client → The transport is the only way out | Runtime dependency added | esi/guard_test.dart | runtime dependency in pubspec fails naming it | green |
| esi-client → The transport is the only way out | Transport fails | esi/result_test.dart | transport failure becomes a result, never an exception | green |
| esi-client → Call identity stays with the transport | Two clients, two transports | esi/request_test.dart | two clients on two transports each send only their own request | red |
| esi-client → Call identity stays with the transport | No identity in requests | esi/request_test.dart | built requests hold no Authorization, token or priority | red |
| esi-client → Typed results, never thrown | Success | esi/result_test.dart | 200 with ETag, Expires, Last-Modified and X-Pages 3 | green |
| esi-client → Typed results, never thrown | No content | esi/result_test.dart | 204 is a success without a body | green |
| esi-client → Typed results, never thrown | Not modified | esi/result_test.dart | 304 is not modified with ETag and Expires | green |
| esi-client → Typed results, never thrown | ESI error with body | esi/result_test.dart | 404 with an error message | green |
| esi-client → Typed results, never thrown | ESI error without a readable body | esi/result_test.dart | 502 with a non-JSON body | green |
| esi-client → Malformed responses are reported | Conforming body | esi/decode_test.dart | conforming alliance body decodes | red |
| esi-client → Malformed responses are reported | Body that is not JSON | esi/decode_test.dart | non-JSON 200 is malformed at the root path | red |
| esi-client → Malformed responses are reported | Missing required field | esi/decode_test.dart | missing required field is malformed with its path | red |
| esi-client → Malformed responses are reported | Wrong JSON type | esi/decode_test.dart | string for an integer is malformed with its path | red |
| esi-client → Values the pinned spec does not list | New enum value | esi/decode_test.dart | unlisted enum string decodes to unknown | red |
| esi-client → Values the pinned spec does not list | New oneOf variant | esi/decode_test.dart | single-key object with unlisted key decodes to unknown | red |
| esi-client → Values the pinned spec does not list | Extra field | esi/decode_test.dart | undeclared field is ignored | red |
| esi-client → Values the pinned spec does not list | Known variant with a wrong-typed payload | esi/decode_test.dart | listed key with wrong payload type is malformed | red |
| esi-client → Values the pinned spec does not list | oneOf object without exactly one key | esi/decode_test.dart | zero- or two-key oneOf object is malformed | red |
| esi-client → Values the pinned spec does not list | Enum position holding a non-string | esi/decode_test.dart | number in an enum position is malformed | red |
| esi-client → Values the pinned spec does not list | Known variant | esi/decode_test.dart | isk variant decodes with amount 1500.5 | red |
| esi-client → Contract tests over recorded exchanges | Exact assertion | esi/contract_test.dart | forward-compatibility notification type asserts the exact unknown string | red |
| esi-client → Contract coverage | Every construct covered | esi/contract_coverage_test.dart | every listed inbound and outbound construct has an asserting exchange | red |
| esi-client → Contract coverage | Snapshot bump breaks an asserted behaviour | esi/contract_test.dart | a conforming exchange whose decoded case differs fails naming the operation | red |
| third-party-notices → Vendored assets are listed by hand | Current vendored assets listed | tools/notices_repo_test.dart | existing vendored asset entries (unchanged) | green |
| third-party-notices → Vendored assets are listed by hand | A vendored source without an entry | tools/notices_test.dart | existing missing-source cases (unchanged) | green |
| third-party-notices → Vendored assets are listed by hand | ESI spec snapshot listed | tools/notices_repo_test.dart | ESI entry names snapshot, generated folder, source, licence, notice and AGPL | red |
| third-party-notices → Vendored assets are listed by hand | ESI spec snapshot without an entry | tools/notices_test.dart | ESI entry missing path, source, licence name, URL or notice fails naming each | red |

## 1. Package scaffold and guards

- [x] 1.1 Verify A1: compare the `dart_style` version locked in `pubspec.lock` with the formatter version reported by `mise exec -- dart format --version`, and format one sample file with both (`DartFormatter` in a scratch script and `dart format`) to confirm identical output; record the result in the group report. A mismatch is design drift: stop and report.
- [x] 1.2 Create `packages/kaname_esi` (pubspec with no runtime dependencies, `test` as a dev dependency, SDK constraint matching the workspace) and add it to the root `pubspec.yaml` workspace; `analysis_options.yaml` like `packages/kaname_core` plus `exclude: lib/src/generated/**`. Add `test:esi` to `mise.toml` and to the `test` task. Add `kaname_esi` to `PurityCheck.webSafePackages`. Verify: `mise run resolve`, `mise run workspace`, `mise run purity` pass; the purity test covering the web-safe list passes.
- [x] 1.3 Write failing tests in `esi/guard_test.dart` for "Disallowed library imported", "Import leaves the package" and "Runtime dependency added": the scanner function takes a package root, so each negative case runs against a temp package; one case runs against the real `packages/kaname_esi`. Verify each fails for the missing scanner.
- [x] 1.4 Implement the guard scanner in the test support code (every import, export, part and conditional-import URI under `lib/`; allow the six `dart:` libraries and URIs resolving inside `lib/`; pubspec runtime dependencies must be empty). Verify the three guard rows go green.
- [x] 1.5 C1: confirm the text of C1 is in `specs/esi-client/spec.md` → "The transport is the only way out" (already written at planning); tick when present.

## 2. Hand-written runtime

- [x] 2.1 Write failing tests in `esi/result_test.dart` for "Transport fails", "Success", "No content", "Not modified", "ESI error with body" and "ESI error without a readable body", driving a small hand-written test operation through a fixture transport (no generated code yet). Verify they fail for the missing runtime.
- [x] 2.2 Implement `lib/src/transport.dart` (`EsiTransport.send(EsiRequest) → Future<EsiTransportOutcome>`, sealed outcome; `EsiRequest` with method, operation id, relative `Uri` target, headers and body bytes), `lib/src/result.dart` (sealed `EsiResult<T>`: success, not modified, ESI error, malformed, invalid request, transport failure) and the response-header reading (ETag, Expires, Last-Modified, X-Pages). Verify the 2.1 rows go green.
- [x] 2.3 C6: write the doc comment on `EsiTransport` in `packages/kaname_esi/lib/src/transport.dart` stating that `User-Agent`, `Authorization`, `If-Modified-Since` and `X-Tenant` are the transport's headers, never the generated client's. Verify by reading the file; `dart doc`-style lint (`public_member_api_docs`) passes in `mise run analyze`.
- [x] 2.4 Implement `lib/src/catalogue_types.dart` (`EsiRoute`, `EsiRateGroup` with `none`, scopes, roles, cache facts as optional values, pagination kind) with its unit tests for value equality. C5: write the doc comment on `EsiRateGroup` stating that routes without `x-rate-limit` carry `EsiRateGroup.none` and that budget meaning belongs to the scheduler. Verify `mise run test:esi` and `mise run analyze`.
- [x] 2.5 C3: write the `packages/kaname_esi/lib/kaname_esi.dart` library doc comment stating that `int` is exact only up to 2^53 on the web and the client is not meant for web builds (ADR 0005). Verify by reading the file and `mise run analyze`.
- [x] 2.6 C8: confirm the text of C8 is in `specs/esi-client/spec.md` → "Call identity stays with the transport"; tick when present.

## 3. Spec reader and pin

- [x] 3.1 Write failing tests in `tools/esi_pin_test.dart` ("Pin missing a field", "Pin date edited by hand", "Snapshot edited by hand") and `tools/esi_spec_reader_test.dart` ("Unsupported construct in the snapshot") using small Kaname-written OpenAPI fixtures in `tools/kaname_tools/test/fixtures/esi/`. Verify they fail for the missing reader.
- [x] 3.2 Implement `tools/kaname_tools/lib/src/esi_pin.dart` (read and validate `pin.yaml`; hash the exact bytes, then compare date with `info.version` and the `X-Compatibility-Date` enum) and `tools/kaname_tools/lib/src/esi_spec.dart` (`EsiSpecReader`: the D4 subset into typed values, failing closed with the JSON path). C4: write the `EsiSpecReader` doc comment stating that only the D4 subset is supported and widening it is a deliberate generator change in the bump PR. Verify the 3.1 rows go green and `mise run test:tools` passes.
- [x] 3.3 C2: confirm the text of C2 is in `specs/esi-client-generation/spec.md` → "One pinned spec snapshot"; tick when present.

## 4. Fetch

- [x] 4.1 Write failing tests in `tools/esi_fetch_test.dart` for "Fetch a listed date", "Spec reports another date", "Download fails", "Bad date argument", "Re-read passes" and "Two fetches interleave in one checkout", with the downloader and the file steps injected so the interleave runs deterministically. Verify they fail for the missing command.
- [x] 4.2 Implement `kaname_tools esi fetch --date` (D8: `dart:io` `HttpClient`, 60 s timeout, 16 MB cap, date check, unique temp files renamed into place, snapshot first and pin last, re-read and hash compare) and the `esi:fetch` mise task. Verify the 4.1 rows go green.
- [x] 4.3 Run `mise run esi:fetch -- --date 2026-11-19` once to create `packages/kaname_esi/spec/openapi.json` and `spec/pin.yaml`; this is the only network step, run by the implementer, never by CI. Verify the pin's date is `2026-11-19` and its sha256 matches `sha256sum` of the snapshot.

## 5. Generator and committed output

- [x] 5.1 Write failing tests in `tools/esi_generate_test.dart` ("Pinned bytes accepted", "Generate twice") and `tools/esi_render_test.dart` ("Required parameter left out", plus rendering of models, `oneOf` unions with unknown cases, enums with unknown cases, and a naming collision that fails generation) over the Kaname-written fixtures. Verify they fail for the missing generator.
- [x] 5.2 Implement `kaname_tools esi generate` (D12 layout: per-tag models and client files, `catalogue.dart`, `pin.dart`; render all in memory with `DartFormatter`, write only when all render; D1 decoding rules, D7 headers, D10 bound checks, D13 no identity) and the `esi:generate` mise task. Verify the 5.1 rows go green.
- [x] 5.3 Run `mise run esi:generate` on the pinned snapshot and commit the generated `lib/src/generated/` output. Verify A2: time `esi:generate` (and later `esi:check`) and record the seconds in the group report; more than about 10 s is design drift to report.
- [x] 5.4 Write the failing generated coverage test `esi/operations_test.dart` ("Every operation covered": every method called with placeholder arguments sends the fixture transport the catalogue's method and the path computed independently from the snapshot's template) and `esi/catalogue_test.dart` (all esi-route-catalogue rows). Make them pass by fixing the generator, regenerate, and verify all their rows go green.
- [x] 5.5 Write and pass `esi/request_test.dart` ("Request built", "Cursor value reaches the wire unchanged", "Body request", "Body outside the spec's bounds", "Conditional request", "Language requested", "Two clients, two transports", "No identity in requests") and `esi/decode_test.dart` (every "Malformed responses are reported" and "Values the pinned spec does not list" row), red first against the generated client, then green after any generator fix and regeneration.

## 6. Drift check

- [x] 6.1 Write failing tests in `tools/esi_check_test.dart` ("Generated file edited by hand", "Snapshot bumped without regenerating") and `tools/esi_repo_test.dart` ("Pin matches snapshot", "Committed output current"). Verify they fail for the missing check.
- [x] 6.2 Implement `kaname_tools esi check` (pin and hash checks first, then regenerate into a temp directory and compare; report missing, extra and differing files; write nothing in the repository) and the `esi:check` mise task, added to `check` after `l10n:check`. Verify the 6.1 rows go green and the existing `tools/ci_workflow_test.dart` and mise-related tests still pass.

## 7. Contract fixtures

- [ ] 7.1 Write Kaname-written exchange files under `packages/kaname_esi/test/exchanges/` in three sets (conforming, negative, forward-compatibility), holding no data copied from ESI (C7), and failing tests `esi/contract_test.dart` ("Fixture transport", "Exact assertion", "Snapshot bump breaks an asserted behaviour", the last by asserting a deliberately altered expectation fails with the operation named) and `esi/contract_coverage_test.dart` ("Every construct covered", which checks that each listed inbound and outbound construct has a tagged exchange). Verify they fail for the right reason, then pass with the generated client; flip their rows green.
- [ ] 7.2 C7: confirm the text of C7 is in `specs/esi-client/spec.md` → "Contract tests over recorded exchanges"; tick when present.

## 8. Third-party notices

- [ ] 8.1 Write failing tests: `tools/notices_test.dart` for "ESI spec snapshot without an entry" (each of path, source URL, licence name, licence URL and proprietary notice line removed in turn) and `tools/notices_repo_test.dart` for "ESI spec snapshot listed". Verify they fail for the missing check and entry.
- [ ] 8.2 Extend the notices check to read `packages/kaname_esi/spec/pin.yaml` and require the ESI entry's items; add the hand-written CCP entry to `THIRD_PARTY_NOTICES` (snapshot path, `packages/kaname_esi/lib/src/generated/`, source URL, `EVE Developer License` and its URL, CCP's proprietary notice, and that Kaname's own code keeps AGPL-3.0). Run `mise run notices` if needed. Verify the two red rows go green, and re-run the existing tests for "Current vendored assets listed" and "A vendored source without an entry" to confirm they stay green.

## 9. Integration

- [ ] 9.1 Run `mise run check` end to end (or, when the gaming check exits 1, push and rely on CI's three-OS `check` job) and confirm every stage passes, including `esi:check`, `format:check` on the generated files, purity, notices and licences. Every test-map row is green.
