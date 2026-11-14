# Evidence: web release build on WSL (task 6.4)

Date: 2026-11-14, branch `feat/repo-scaffold`, WSL Ubuntu, Flutter 3.47.9 / Dart 3.13.7 through mise.

`mise run build:web` (`flutter build web --release` in `app/`) → **exit 0**. Output tail:

```text
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 1472 bytes (99.4% reduction). …
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). …
Compiling lib/main.dart for the Web...                             18.4s
✓ Built build/web
```

`ls -la app/build/web/index.html` → present, 1508 bytes. `app/build/` is ignored by `.gitignore` (`build/`), so `git status` showed no build output.
