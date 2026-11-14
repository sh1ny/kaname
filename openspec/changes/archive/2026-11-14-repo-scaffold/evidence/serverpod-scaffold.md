# Evidence: Serverpod CLI scaffold uses pub workspaces (A3, task 1.1)

Date: 2026-11-14. Toolchain: Flutter 3.47.9 / Dart 3.13.7 through mise.

## Procedure

1. In a scratch directory outside the repository, a throwaway package `sp_probe_host` declared `serverpod_cli: ^4.1.0` as a dev dependency; `mise exec -- dart pub get` resolved it.
2. `mise exec -- dart run serverpod_cli version` printed `Serverpod version: 4.1.2`.
3. `mise exec -- dart run serverpod_cli create probe --no-interactive --no-analytics --ide none -f` (default `fullstack` template) ended with `✅ Serverpod project created.`
4. Every generated `pubspec.yaml` outside `.dart_tool/` and `build/` was inspected; the scratch directory was then deleted.

## Result

CLI version: **4.1.2** (`serverpod_cli` resolved from `^4.1.0`).

| Pubspec | `name` | `resolution: workspace` | Notes |
|---|---|---|---|
| `pubspec.yaml` (root) | `_` | n/a (root) | `workspace:` lists `probe_client`, `probe_server`, `probe_flutter` |
| `probe_client/pubspec.yaml` | `probe_client` | yes (line 7) | `serverpod_client: 4.1.2` |
| `probe_server/pubspec.yaml` | `probe_server` | yes (line 9) | `serverpod: 4.1.2` |
| `probe_flutter/pubspec.yaml` | `probe` | yes (line 24) | Flutter app |

The only `pubspec.lock` outside `.dart_tool/` was the root one. The scaffold's SDK constraint is `'^3.12.2'`, below Kaname's `^3.13.0` (D5); `serverpod-skeleton` sets its own constraints.

**A3 holds:** the pinned Serverpod 4.1 CLI scaffolds a root pub workspace whose members declare `resolution: workspace`. No owner escalation needed.

Observation for `serverpod-skeleton` (not this change): the scaffold places packages at `<name>_server/`, `<name>_client/` and `<name>_flutter/` beside a root pubspec named `_`; Kaname's layout (S2) places them under `server/` as `kaname_server` and `kaname_client`, so that change adapts the generated paths and names rather than adopting the scaffold's root.
