# Review

## Metadata

- **Round:** 2 (re-check of Required Changes)
- **Prior round:** Re-check 2 accepted items 2–7; item 1 still needed explicit query parameter encoding.
- **Reviewer:** OMP (OpenAI Codex), read-only
- **Reviewed:** `proposal.md`, `design.md`, all four spec deltas, `purity.dart:12–23,46–47`, `ci.yml:38–49,66–67`, and the review template.

## Findings

1. **Satisfied — Encoding ownership.** D9 and the client spec assign the relative `Uri` to the client, which percent-encodes each path and query parameter value exactly once. The transport only resolves it against the ESI origin. The scenarios assert the exact request target and that `after=a%2Bb%2Fc%3D` decodes once to `a+b/c=`.
2. **Satisfied — Interleaved fetches.** D8 and the generation spec require unique temporary files, snapshot-first and pin-last renames, and a post-write re-read. The deterministic scenario uses distinct hashes and verifies that A fails and the check rejects the final pair. The design explicitly retains no lock and makes no guarantee against later writes.
3. **Satisfied — Hash before parsing.** Generate and check verify the exact bytes they parse. The hand-edited snapshot scenario requires both commands to fail and generate to leave existing output untouched.
4. **Satisfied — Package boundary.** D11, C1, and the client spec cover imports, exports, parts, and conditional URIs, including generated files. The package-escape scenario keeps the pubspec unchanged.
5. **Satisfied — CCP notice.** The notices delta names the snapshot and generated directory, preserves AGPL-3.0 for Kaname’s own code, and requires the check to report a missing snapshot path, source URL, licence name or URL, or proprietary notice.
6. **Satisfied — Fixture assertions.** D6 and the client spec require exact result cases and decoded values for inbound tests, and captured requests for outbound cursor and body tests. The malformed-response scenarios distinguish a conforming body from non-JSON at status 200 and the root JSON path.
7. **Satisfied — Citations.** The design cites `purity.dart:12–23` and `ci.yml:38–49,66–67`; the cited ranges support the purity and three-OS CI claims.

### Critical (blocking)

None outstanding.

### Moderate

None outstanding.

### Suggestions

None. This re-check was limited to the seven Required Changes.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

None remaining.

CHANGES_APPLIED: yes

## Rebuttals

None.