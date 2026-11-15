# Scaffold record (task 1.4)

Recorded 2026-11-15, Linux (WSL), Flutter 3.47.9 / Dart 3.13.7 through mise.

## CLI version

Pinned Serverpod CLI: `serverpod_cli` 4.1.2. It was first fetched into a throwaway
package outside the repository (one dev dependency, `serverpod_cli: ^4.1.0`, resolved
to 4.1.2) and run from there with `mise exec -- dart run`; nothing was installed
globally. In the repository it is a dev dependency of `server/kaname_server`.

## The `create` command

Run from the throwaway package:

```sh
mise exec -- dart run serverpod_cli create kaname --template server --no-auth \
  --database --redis --ide none --no-analytics --no-interactive
```

Output (relative to the generated project root): `kaname_server/`, `kaname_client/`,
a root `pubspec.yaml` listing only those two as a workspace (`name: _`), `.github/`,
`.vscode/`, `AGENTS.md`, `.gitignore`. Each package pubspec carries
`resolution: workspace`. Only `kaname_server/` and `kaname_client/` were copied into
this repository as `server/kaname_server/` and `server/kaname_client/`; the scaffold's
root files were not copied. Notes:

- The CLI executable is `serverpod_cli` (`bin/serverpod_cli.dart`; its pubspec
  `executables:` maps `serverpod` to it). `dart run serverpod_cli:serverpod` does not
  exist: it prints "Could not find `bin/serverpod.dart` in package `serverpod_cli`".
  The working forms are `dart run serverpod_cli <command>` or
  `dart run serverpod_cli:serverpod_cli <command>`.
- `--template server` produced no Flutter app. `--redis` still wrote `redis.enabled: false`.

## Stripped from the scaffold (S6)

Removed: `kaname_server/Dockerfile` and `kaname_server/docker-compose.yaml` (the latter
held generated database and Redis passwords), the `web/` folder and the `src/web/` and
`cache_busting.dart` demo web routes, the `greetings` example endpoint and model (server
and client), the greeting integration test, the Serverpod Cloud storage dependency and
its registration, `kaname_client/dartdoc_options.yaml` and `doc/`, the generated
`config/passwords.yaml` (git-ignored by `**/config/passwords.yaml`), and the scaffold's
only migration (it was created for the removed Cloud storage dependency; task 4.6
creates the initial migration). `migrations/` holds a `.gitkeep`. `config/` is kept
unchanged (task 3.2 edits it). Generated code was regenerated after stripping.

## Generated code locations (A9)

Confirmed against the pinned CLI's output:

- server: `server/kaname_server/lib/src/generated/` (`endpoints.dart`, `protocol.dart`,
  `protocol.yaml`, `serverpod.dart`); the test tool
  `server/kaname_server/test/integration/test_tools/serverpod_test_tools.dart` is also
  generated (`server_test_tools_path` in `config/generator.yaml`).
- client: `server/kaname_client/lib/src/protocol/` (`client.dart`, `protocol.dart`).

## Resolve

```
$ mise run resolve
... Changed 79 dependencies!
```

Exit 0 with `server/kaname_client` and `server/kaname_server` in the root `workspace:`
and the Flutter-pinned `flutter_test` versions (A7 holds). The root `pubspec.lock`
marks `serverpod_cli` `transitive`: a workspace lockfile marks only the root pubspec's
own dependencies as direct, so the dev dependency is declared in
`server/kaname_server/pubspec.yaml` and the lockfile holds the resolved 4.1.2.

## Version through the package-local CLI

```
$ mise exec -C server/kaname_server -- dart run serverpod_cli version
Serverpod version: 4.1.2
```
