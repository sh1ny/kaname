# Drift check evidence (task 2.5)

`mise run server:drift` runs the package-local `serverpod_cli generate`,
`dart format` over the generated paths, `git add --intent-to-add` over the same
paths (so files that generation newly creates are visible to `git diff`, which
ignores untracked files), then `git diff --exit-code --stat=200` over them (full paths, never shortened with `...`).

## Experiment

On the committed generated tree, with no generation run afterwards, two
hand-written definitions were added to `server/kaname_server/lib/src/`:

- `probe_endpoint.dart`: `ProbeEndpoint.echo(Session, String)`, a new endpoint.
- `probe.spy.yaml`: `class: Probe` with one `label: String` field, a new model.

Then `mise run server:drift` ran.

## Result: exit 1, differing generated files named

Re-run by the orchestrator after widening `--stat` to `--stat=200` and narrowing the test-tools path to the one generated file, with the same two probe definitions:

```text
[server:generate] $ dart run serverpod_cli generate
Generating code...
Generating code done. (8.3s)
✅ Done.

[server:drift] $ dart format server/kaname_server/lib/src/generated server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart server/kaname_client/lib/src/protocol
Formatted 8 files (0 changed) in 0.02 seconds.
[server:drift] $ git add --intent-to-add -- server/kaname_server/lib/src/generated server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart server/kaname_client/lib/src/protocol
[server:drift] $ git diff --exit-code --stat=200 -- server/kaname_server/lib/src/generated server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart server/kaname_client/lib/src/protocol
 server/kaname_client/lib/src/protocol/client.dart                          | 21 +++++++++++++++++++--
 server/kaname_client/lib/src/protocol/probe.dart                           | 57 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 server/kaname_client/lib/src/protocol/protocol.dart                        | 23 +++++++++++++++++++++--
 server/kaname_server/lib/src/generated/endpoints.dart                      | 29 ++++++++++++++++++++++++++++-
 server/kaname_server/lib/src/generated/probe.dart                          | 57 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 server/kaname_server/lib/src/generated/protocol.dart                       | 24 ++++++++++++++++++++++--
 server/kaname_server/lib/src/generated/protocol.yaml                       |  2 ++
 server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart | 46 ++++++++++++++++++++++++++++++++++++++++++++--
 8 files changed, 250 insertions(+), 9 deletions(-)
[server:drift] ERROR task failed
exit=1
```

`probe.dart` exists in both packages only because generation created it; the
intent-to-add step is what makes such untracked new files fail the check.

## Revert

The two probe definitions were deleted, the index reset, the new generated
`probe.dart` files removed, and generation re-run and formatted. `git status`
afterwards showed only the group's intended changes; no `probe` file remained.

On the clean tree (generated files in formatter output form and committed),
`mise run server:drift` exits 0 with no diff output.
