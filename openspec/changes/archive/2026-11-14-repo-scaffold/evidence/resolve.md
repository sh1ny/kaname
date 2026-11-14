# Evidence: one resolve on a fresh clone (task 6.3)

Date: 2026-11-14, WSL Ubuntu, Flutter 3.47.9 / Dart 3.13.7 through mise.

## Procedure

1. `git clone --branch feat/repo-scaffold` of the repository into a scratch directory outside it; the clone's tip was `ddb61e8 feat(repo-scaffold): group 5 Contribution policy documents`.
2. Group 6's `mise.toml` task definitions were not committed yet (the change commits once per task group), so the working tree's `mise.toml` diff was applied to the clone with `git apply`; it was the only modified file (`git status --short`: ` M mise.toml`). The committed `mise.toml` of this group is that same content.
3. `mise trust`, `mise install` (all tools already installed), then `mise run resolve` in the clone.
4. `find . -name pubspec.lock -not -path '*/.dart_tool/*'` and `git status --short`.
5. The clone was untrusted in mise and deleted.

## Result

- `mise run resolve` (`flutter pub get`) → **exit 0**, ending `Got dependencies!`.
- The only `pubspec.lock` in the clone is the root one: `./pubspec.lock`. No member (`app/`, `packages/kaname_core/`, `tools/kaname_tools/`) has its own.
- `git status --short` after resolving still showed only ` M mise.toml`: the committed root `pubspec.lock` was unchanged by a fresh resolve.
