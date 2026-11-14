# Evidence: `mise run check` passes and fails on planted problems (task 6.2)

Date: 2026-11-14, branch `feat/repo-scaffold`, WSL Ubuntu, Flutter 3.47.9 / Dart 3.13.7 through mise, after `mise run resolve`. `check` runs, in order and stopping at the first failure: `workspace`, `purity`, `analyze`, `format:check`, `test` (`test:core`, `test:tools`, `test:app`), `notices:check`.

## Clean run

`mise run check` → **exit 0**. Output, abridged to each sub-check's result:

```text
[workspace] $ dart run kaname_tools workspace
kaname_app at app/
kaname_core at packages/kaname_core/
kaname_tools at tools/kaname_tools/
[purity] $ dart run kaname_tools purity
kaname_core is pure at packages/kaname_core/
kaname_tools is pure at tools/kaname_tools/
[analyze] $ dart analyze --fatal-infos
No issues found!
[format:check] $ dart format --output=none --set-exit-if-changed app packages/k…
Formatted 21 files (0 changed) in 0.04 seconds.
[test:core] $ dart test
00:00 +1: All tests passed!
[test:tools] $ dart test
00:00 +26: All tests passed!
[test:app] $ flutter test
00:00 +1: All tests passed!
[notices:check] $ dart run kaname_tools notices --check
THIRD_PARTY_NOTICES is up to date
```

The 21 formatted files are exactly the Dart files of `app/`, `packages/kaname_core/` and `tools/kaname_tools/`, the directories `kaname_tools workspace --format-dirs` prints. No file under `.claude/` or `brand/` is analysed or formatted.

## Planted failures

Each plant was a throwaway edit to `packages/kaname_core/lib/kaname_core.dart`, restored from a copy before the next one.

| Plant | `mise run check` exit | Failing sub-check and what it names |
|---|---|---|
| Analysis info: a function with `var x = 1; return x;` | 1 | `[analyze]`: `info - packages/kaname_core/lib/kaname_core.dart:13:3 - Local variables should be final. Try making the variable final. - prefer_final_locals`, `1 issue found.`, `[analyze] ERROR task failed` |
| Unformatted file: `const String productName='Kaname';` | 1 | `[analyze]` `No issues found!`, then `[format:check]`: `Changed packages/kaname_core/lib/kaname_core.dart`, `Formatted 21 files (1 changed)`, `[format:check] ERROR task failed` |
| Flutter import: `import 'package:flutter/widgets.dart';` | 1 | `[purity]`: `packages/kaname_core/lib/kaname_core.dart: import of "package:flutter/widgets.dart" is not allowed in a pure-Dart package (rule: packages/ and tools/ stay pure Dart)`, `[purity] ERROR task failed` |

In each failing run the later sub-checks did not run.

## After reverting

`git status --short` showed only ` M mise.toml` (this group's task definitions, not yet committed); `git diff --stat -- .claude brand` printed nothing.
