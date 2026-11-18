# Browser run (D5, task 5.3)

- **Date:** 2026-11-18, on WSL Ubuntu with the owner's approval for heavy steps.
- **Browser:** Google Chrome for Testing 156.0.8078.80, headless (`mise run spike:chrome`, held below as `$CHROME`). It renders WebGL on SwiftShader.
- **Build:** `app/build/web` from `mise run build:web` (task 3.6): `--wasm --release --no-web-resources-cdn`, checked by `webbuild --check --single-threaded`.
- **Scratch:** the session scratchpad, held below as `$SCRATCH`. The scratch build copy, Chrome profiles, net logs and console logs were deleted after the run. Only the two screenshots are kept, next to this file.

Both loads use the same Chrome flags. Chrome's own background requests (component updates, the spellcheck dictionary, account and time checks) are not the page's, so they are told apart by the net log's `initiator`. Requests the page started carry the page's origin. Requests Chrome starts itself carry `not an origin`, or no initiator at all. The file lists below are the page-initiated `URL_REQUEST_START_JOB` URLs, without query strings.

```sh
FLAGS="--headless=new --no-sandbox --no-first-run --disable-background-networking \
  --disable-component-update --disable-sync --disable-default-apps \
  --enable-logging=stderr --v=0 --window-size=1280,800 --virtual-time-budget=20000"
```

## Default load: the stack's build (skwasm)

The stack was up after task 4.3: `mise run stack:up`, with Caddy serving the build at `http://localhost/` without COOP/COEP headers.

```sh
"$CHROME" $FLAGS --user-data-dir="$SCRATCH/profile-default" \
  --log-net-log="$SCRATCH/default-netlog.json" \
  --screenshot="$SCRATCH/default.png" http://localhost/ 2> "$SCRATCH/default-console.log"
```

The page fetched these files, all from `http://localhost`:

```
/api/health/check
/assets/FontManifest.json
/assets/fonts/MaterialIcons-Regular.otf
/assets/fonts/fallback/Roboto-Regular.ttf
/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf
/assets/packages/kaname_ember_ui/fonts/Geist%255Bwght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/Literata%255Bopsz,wght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/Literata-Italic%255Bopsz,wght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/OFL-geist.txt
/assets/packages/kaname_ember_ui/fonts/OFL-literata.txt
/canvaskit/skwasm.js
/canvaskit/skwasm.wasm
/favicon.png
/flutter_bootstrap.js
/icons/Icon-192.png
/main.dart.mjs
/main.dart.wasm
/manifest.json
/version.json
```

- It fetched `main.dart.wasm` (with `main.dart.mjs`) and `skwasm.wasm`. It fetched neither `main.dart.js` nor any `canvaskit.wasm`, so Chrome got skwasm (A5: the default allow list admits Chromium).
- Console: two "Automatic fallback to software WebGL has been deprecated" messages and two "GL Driver Message … GPU stall due to ReadPixels" messages, both from headless SwiftShader. Neither is a warning that skwasm runs single-threaded or that the page is not cross-origin isolated (scenario "No single-threaded warning", A5).
- Screenshot: [browser-run-skwasm.png](browser-run-skwasm.png). The home screen rendered, with "Server connected" in the status bar.

## Forced-CanvasKit load: a scratch copy (fallback)

A copy of the same build in `$SCRATCH/web-canvaskit`, with one line added to its bootstrap's loader config: `renderer: "canvaskit"`. The product bootstrap is unchanged. The copy was served without isolation headers:

```sh
cp -r app/build/web "$SCRATCH/web-canvaskit"
# add `renderer: "canvaskit",` after `forceSingleThreadedSkwasm: true,` in its flutter_bootstrap.js
mise exec -- dart run kaname_tools serve "$SCRATCH/web-canvaskit" --port 8091 --no-isolation &
"$CHROME" $FLAGS --user-data-dir="$SCRATCH/profile-ck" \
  --log-net-log="$SCRATCH/canvaskit-netlog.json" \
  --screenshot="$SCRATCH/canvaskit.png" http://127.0.0.1:8091/ 2> "$SCRATCH/canvaskit-console.log"
```

The page fetched these files, all from `http://127.0.0.1:8091`:

```
/api/health/check
/assets/FontManifest.json
/assets/fonts/MaterialIcons-Regular.otf
/assets/fonts/fallback/Roboto-Regular.ttf
/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf
/assets/packages/kaname_ember_ui/fonts/Geist%255Bwght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/Literata%255Bopsz,wght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/Literata-Italic%255Bopsz,wght%255D.ttf
/assets/packages/kaname_ember_ui/fonts/OFL-geist.txt
/assets/packages/kaname_ember_ui/fonts/OFL-literata.txt
/canvaskit/chromium/canvaskit.js
/canvaskit/chromium/canvaskit.wasm
/favicon.png
/flutter_bootstrap.js
/icons/Icon-192.png
/main.dart.js
/manifest.json
/version.json
```

- It fetched `main.dart.js` and `canvaskit.wasm`, the Chromium variant the loader picks on Chrome. It fetched neither `main.dart.wasm` nor `skwasm.wasm`, so the forced renderer loads the same dart2js build that a browser without WasmGC gets (A3).
- Every page request went to the page's own origin, and none to another host.
- Console: "Injecting <script> tag. Using callback." from the loader, plus the same SwiftShader WebGL messages as the default load.
- Screenshot: [browser-run-canvaskit.png](browser-run-canvaskit.png). The home screen rendered. "Server unreachable" is expected, because the scratch server has no `/api`.
