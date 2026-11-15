# Task 8.1 evidence: `mise run check` and planted failures

Environment: Linux (WSL2, kernel `6.18.33.2-microsoft-standard-WSL2`), mise 2026.11.8 linux-x64, `dart` and `flutter` resolved to Linux paths under `~/.local/share/mise/installs/flutter/3.47.9/bin/`. Branch `feat/serverpod-skeleton`, HEAD `2517e24`, clean tree (`git status --short` empty) before the first run.

Every command was `mise run check` from the repo root. Its output was captured with `> file 2>&1`, then the repo path and home directory were replaced by `<repo>` and `<home>` with `sed "s|$PWD|<repo>|g;s|$HOME|<home>|g"`. Nothing else was edited; omitted lines are marked `...`. Planted diffs are the `git diff` taken just before each run. Each plant was reverted with `git checkout -- <file>`, and `git status --short` was empty afterwards.

## 1. Clean tree: exit 0

Command: `mise run check`. Exit code: **0**.

Steps run, in order (all step header lines of the log): workspace, purity, analyze, format:check, test:core, test:tools, test:app, notices:check, licences. There is no `test:server` step (the log has no `test:server` line; the server tests belong to the separate `test:server` task) and no `kaname_server` or `kaname_client` test output.

(a) workspace members and analysis (root-workspace `dart analyze --fatal-infos` covers every member, including both server packages):

```
[workspace] $ dart run kaname_tools workspace
kaname_app at app/
kaname_core at packages/kaname_core/
kaname_client at server/kaname_client/
kaname_server at server/kaname_server/
kaname_tools at tools/kaname_tools/
[purity] $ dart run kaname_tools purity
kaname_core is pure at packages/kaname_core/
kaname_tools is pure at tools/kaname_tools/
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
No issues found!
```

The analysis covering the server packages is proven by plant 1 below: an `info` planted in `server/kaname_server/lib/src/health/health_endpoint.dart` is reported by this same analyze step.

(b) format check, naming both server packages in its command line:

```
[format:check] $ dart format --output=none --set-exit-if-changed app packages/kaname_core server/kaname_client server/kaname_server tools/kaname_tools
Formatted 72 files (0 changed) in 0.21 seconds.
```

(c) the test step: only core, tools and app tests ran:

```
[test:core] $ dart test
00:00 +0: loading test/kaname_core_test.dart
00:00 +0: test/kaname_core_test.dart: exposes the product name
00:00 +1: All tests passed!
[test:tools] $ dart test
...
[test:app] $ flutter test
Resolving dependencies in `<repo>`...
...
00:00 +0: shows Kaname
00:00 +1: All tests passed!
[notices:check] $ dart run kaname_tools notices --check
THIRD_PARTY_NOTICES is up to date
...
EXIT=0
```

(The `test:tools` suite includes a test whose name mentions `kaname_server` (`workspace_test.dart: root workspace lists kaname_server and kaname_client ...`); that is a workspace-layout test in `tools/kaname_tools`, not a server test.)

## 2. An analysis info in hand-written server code (`prefer_final_locals`, info level; `--fatal-infos` makes it fatal)

Planted diff:

```diff
diff --git a/server/kaname_server/lib/src/health/health_endpoint.dart b/server/kaname_server/lib/src/health/health_endpoint.dart
index acbdb05..0e9cac4 100644
--- a/server/kaname_server/lib/src/health/health_endpoint.dart
+++ b/server/kaname_server/lib/src/health/health_endpoint.dart
@@ -73,4 +73,9 @@ class HealthEndpoint extends Endpoint {
     }
     return DependencyStatus.down;
   }
+
+  int plantedInfo() {
+    var planted = 1;
+    return planted;
+  }
 }
```

Command: `mise run check`. Failed step: `analyze`.

```
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
   info - server/kaname_server/lib/src/health/health_endpoint.dart:78:5 - Local variables should be final. Try making the variable final. - prefer_final_locals
1 issue found.
[analyze] ERROR task failed
EXIT=1
```

## 3. An unformatted hand-written file (server)

Planted diff:

```diff
diff --git a/server/kaname_server/lib/src/health/server_version.dart b/server/kaname_server/lib/src/health/server_version.dart
index 9c26e2a..b8279b4 100644
--- a/server/kaname_server/lib/src/health/server_version.dart
+++ b/server/kaname_server/lib/src/health/server_version.dart
@@ -3,3 +3,4 @@
 /// It must equal the `version:` in the package's pubspec.yaml; a unit test
 /// keeps the two in step.
 const serverVersion = '0.1.0';
+int   plantedUnformatted( )   =>   1;
```

Command: `mise run check`. Failed step: `format:check`.

```
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
No issues found!
[format:check] $ dart format --output=none --set-exit-if-changed app packages/kaname_core server/kaname_client server/kaname_server tools/kaname_tools
Changed server/kaname_server/lib/src/health/server_version.dart
Formatted 72 files (1 changed) in 0.22 seconds.
[format:check] ERROR task failed
EXIT=1
```

## 4. An unformatted generated server file (`server/kaname_server/lib/src/generated/protocol.dart`): excluded from analysis (analyze reports no issues) but still format-checked

Planted diff:

```diff
diff --git a/server/kaname_server/lib/src/generated/protocol.dart b/server/kaname_server/lib/src/generated/protocol.dart
index 55aa983..5f77b75 100644
--- a/server/kaname_server/lib/src/generated/protocol.dart
+++ b/server/kaname_server/lib/src/generated/protocol.dart
@@ -182,3 +182,4 @@ class Protocol extends _is.DatabaseSerializationManager
     throw Exception('Unsupported record type ${record.runtimeType}');
   }
 }
+int   plantedGenerated( )   =>   1;
```

Command: `mise run check`. Failed step: `format:check`.

```
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
No issues found!
[format:check] $ dart format --output=none --set-exit-if-changed app packages/kaname_core server/kaname_client server/kaname_server tools/kaname_tools
Changed server/kaname_server/lib/src/generated/protocol.dart
Formatted 72 files (1 changed) in 0.23 seconds.
[format:check] ERROR task failed
EXIT=1
```

## 5. An unformatted generated client file (`server/kaname_client/lib/src/protocol/protocol.dart`), same as above

Planted diff:

```diff
diff --git a/server/kaname_client/lib/src/protocol/protocol.dart b/server/kaname_client/lib/src/protocol/protocol.dart
index 91f67e6..14b6e25 100644
--- a/server/kaname_client/lib/src/protocol/protocol.dart
+++ b/server/kaname_client/lib/src/protocol/protocol.dart
@@ -134,3 +134,4 @@ class Protocol extends _isc.SerializationManager
     throw Exception('Unsupported record type ${record.runtimeType}');
   }
 }
+int   plantedGenerated( )   =>   1;
```

Command: `mise run check`. Failed step: `format:check`.

```
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
No issues found!
[format:check] $ dart format --output=none --set-exit-if-changed app packages/kaname_core server/kaname_client server/kaname_server tools/kaname_tools
Changed server/kaname_client/lib/src/protocol/protocol.dart
Formatted 72 files (1 changed) in 0.20 seconds.
[format:check] ERROR task failed
EXIT=1
```

## 6. A failing core test

Planted diff:

```diff
diff --git a/packages/kaname_core/test/kaname_core_test.dart b/packages/kaname_core/test/kaname_core_test.dart
index f0f1e24..adbebb9 100644
--- a/packages/kaname_core/test/kaname_core_test.dart
+++ b/packages/kaname_core/test/kaname_core_test.dart
@@ -3,6 +3,6 @@ import 'package:test/test.dart';
 
 void main() {
   test('exposes the product name', () {
-    expect(productName, 'Kaname');
+    expect(productName, 'Planted');
   });
 }
```

Command: `mise run check`. Failed step: `test:core`.

```
[analyze] $ dart analyze --fatal-infos
Analyzing kaname...
No issues found!
[format:check] $ dart format --output=none --set-exit-if-changed app packages/kaname_core server/kaname_client server/kaname_server tools/kaname_tools
Formatted 72 files (0 changed) in 0.20 seconds.
[test:core] $ dart test
00:00 +0: loading test/kaname_core_test.dart
00:00 +0: test/kaname_core_test.dart: exposes the product name
00:00 +0 -1: test/kaname_core_test.dart: exposes the product name [E]
  Expected: 'Planted'
    Actual: 'Kaname'
     Which: is different.
            Expected: Planted
              Actual: Kaname
                      ^
             Differ at offset 0
  
  package:matcher                 expect
  test/kaname_core_test.dart 6:5  main.<fn>
  
00:00 +0 -1: Some tests failed.
Failing tests:
  test/kaname_core_test.dart: exposes the product name
Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
[test:core] ERROR task failed
EXIT=1
```

Each run stopped at its first failing step (expected for `check`), exited non-zero (see the `EXIT=` line, which was appended by the capture command after `mise run check` returned) and named the failing file or test. The info plant exits 1 because analyze reports 1 issue; the format plants name the changed file (`Changed <path>`); the core test run names `test/kaname_core_test.dart: exposes the product name`.

## Reverted

All five plants were reverted with `git checkout -- <file>` before the next run. Final state:

```
$ git status --short   # before this evidence file was written
(empty)
```

After writing this file, `git status --short` lists only `?? openspec/changes/serverpod-skeleton/evidence/check-task.md`.

