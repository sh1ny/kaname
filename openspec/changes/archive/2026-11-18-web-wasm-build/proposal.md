# Proposal

## Why

The product web build (`flutter build web --release --no-web-resources-cdn`) always renders with CanvasKit. In the M0 grid spike, CanvasKit was the one renderer that missed the scrolling budget: 12.0% missed frames against under 0.5% for skwasm (`docs/spikes/web-grid.md`, R61). This change serves milestone **M1 - Static data pipeline** and its agent-verified exit criterion: "The product web build is `--wasm` (skwasm, CanvasKit fallback for browsers without WasmGC), without COOP/COEP headers, and `webbuild --check` passes on it." It comes first in M1 so that the static-data screens that follow are built and measured on the renderer the product ships.

## What Changes

- The local web build task (`mise run build:web`), the CI web build and the stack's build compile the app with `--wasm`. Browsers with WasmGC get skwasm, the rest fall back to CanvasKit.
- No COOP/COEP headers are added, and the app's bootstrap forces skwasm single-threaded even if a proxy adds them. Single-threaded skwasm passed the spike and never crashed, while multi-threaded skwasm crashed once in nine runs.
- `kaname_tools webbuild --check` also fails a build that is not a wasm build, meaning one without the wasm entry point or without its JavaScript/CanvasKit fallback, or with the CanvasKit build listed first, and names what is missing. A `--single-threaded` option, passed by the product tasks but not by the grid spike's benchmark build, also requires the forced single-threaded setting. The existing self-contained checks stay as they are.
- `deploy/README.md` gains deploy notes: which renderer each kind of browser gets, why the stack sends no COOP/COEP headers, and what turning on multi-threaded skwasm later would take.
- Non-goals: no Caddyfile change (no headers, no compression), no wasm test run of the app's tests, no renderer indicator in the UI, and no work on the multi-threaded crash.

## Capabilities

### New Capabilities
- `web-build`: how the product web app is compiled and hosted for browsers: renderer selection (skwasm with a CanvasKit fallback), threading and the cross-origin isolation headers, and the build check that proves it.

### Modified Capabilities
None. The existing `ember-ui` requirement "The web build loads no engine or font files from third-party hosts" still holds unchanged on the `--wasm` output.

## Impact

- `mise.toml` (`build:web:compile`), `.github/workflows/ci.yml` (web matrix command) and the test that checks the CI workflow (`tools/kaname_tools/test/ci_workflow_test.dart`).
- `tools/kaname_tools/lib/src/webbuild.dart` and `test/webbuild_test.dart`: the new wasm-build check.
- `app/web/flutter_bootstrap.js`: the single-threaded loader setting.
- `server/kaname_client/test/stack/stack_test.dart` and `support/stack_support.dart`: header and content-type tests, with a helper that returns headers and leaves binary bodies undecoded.
- `deploy/README.md`: deploy notes. `deploy/Caddyfile` and `compose.yaml` are unchanged.
- The web build gets larger (wasm entry point plus the JavaScript fallback), and CI's web job takes longer.
- No Dart app code, server code or dependency changes. `THIRD_PARTY_NOTICES` is unaffected.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Ship `--wasm` without COOP/COEP headers (single-threaded skwasm)

- **Choice:** Build with `--wasm` and add no cross-origin isolation headers, so capable browsers run single-threaded skwasm.
- **Rejected:** Adding COOP/COEP for multi-threaded skwasm: it crashed intermittently in the spike (1 in 9 runs) and the crash is not yet understood. Staying on CanvasKit only: it missed the spike's scrolling budget.
- **Reversal cost:** low (the headers are one Caddyfile change)
- **Important:** yes, it changes behaviour users see (renderer and performance)
- **Chosen by:** user (stated in the agreed M1 exit criterion)

### S2: The build check requires a wasm build

- **Choice:** `webbuild --check` fails unless the output is a wasm build with its JavaScript/CanvasKit fallback.
- **Rejected:** Leaving the check unchanged: a later edit that drops `--wasm` would pass unnoticed.
- **Reversal cost:** low
- **Important:** yes, it binds future changes (a build contract every web build must meet)
- **Chosen by:** user

### S3: A new `web-build` capability holds the renderer requirements

- **Choice:** Add a `web-build` capability and leave `ember-ui`'s self-contained requirement unchanged.
- **Rejected:** Extending `ember-ui`: the renderer is not a design-system concern. Using `self-host-stack`: it would split the rule between two capabilities.
- **Reversal cost:** low
- **Important:** yes, it binds future changes (where web build and hosting requirements live)
- **Chosen by:** user

### S4: No wasm test run; build and check only

- **Choice:** CI and the local and stack builds compile with `--wasm` and run `webbuild --check`. The app's tests are not run compiled to wasm.
- **Rejected:** A CI wasm test job: slower CI and a new flaky surface while the app has no web-specific code. A local-only wasm test task: it adds a task nobody runs.
- **Reversal cost:** low
- **Important:** yes, chosen on weak evidence (no web-specific code exists yet to break); revisit when it lands
- **Chosen by:** user

### S5: Deploy notes only; Caddyfile unchanged

- **Choice:** Document the renderer, threading and headers in `deploy/README.md`. No compression or header changes.
- **Rejected:** Adding `encode zstd gzip` to Caddy: a faster first load, but it widens this change into self-host behaviour.
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user

### S6: No renderer indicator in the app

- **Choice:** No UI shows which renderer is in use.
- **Rejected:** A Settings → About line with renderer and thread mode: useful for support, but it adds app code and a user-visible change for little gain now.
- **Reversal cost:** low
- **Important:** yes, it concerns behaviour users see
- **Chosen by:** user
