# Spec Delta

## Purpose

Defines how the product web app is compiled and hosted for browsers: which renderer each browser gets, whether it runs multi-threaded, and the build check that proves the web build meets these rules.

## ADDED Requirements

### Requirement: The web build is skwasm with a CanvasKit fallback
The app's release web build SHALL be a wasm build. A browser that supports WasmGC and WebGL and that Flutter's loader allows by default (Chromium-based browsers) SHALL get the app compiled to WebAssembly with the skwasm renderer. Every other browser SHALL get the app compiled to JavaScript with the CanvasKit renderer, from the same build output. The local web build task, the CI web build and the stack's build SHALL each produce this build.

#### Scenario: Wasm build with its fallback
- **WHEN** the web build task runs
- **THEN** the build output holds the WebAssembly entry point with its JavaScript support module and the JavaScript entry point, and its build configuration lists a WebAssembly build with the skwasm renderer first and a JavaScript build with the CanvasKit renderer after it

#### Scenario: Chromium browser
- **WHEN** the web app is opened from the stack in a Chromium-based browser with WasmGC and WebGL
- **THEN** the page loads the WebAssembly entry point and the skwasm engine, and the app shows its first screen

#### Scenario: Browser that gets the fallback
- **WHEN** the web app is opened in a browser that lacks WasmGC or WebGL, or whose engine the loader does not allow (such as Firefox or Safari by default)
- **THEN** the page loads the JavaScript entry point and the CanvasKit engine instead, shows its first screen, and loads no file from another host

#### Scenario: CI and stack builds
- **WHEN** CI's web build job or the stack's build produces the web app
- **THEN** it produces the same wasm build and runs the web build check on its output, and the job fails if the check fails

### Requirement: skwasm runs single-threaded
The web app SHALL run skwasm single-threaded whatever headers the hosting origin sends, and the self-host stack SHALL serve the web app without the `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers. The app SHALL NOT log a warning about running single-threaded.

#### Scenario: No isolation headers
- **WHEN** a client requests the web app's `index.html`, `flutter_bootstrap.js` or `main.dart.wasm` from the running stack
- **THEN** no response carries a `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy` header

#### Scenario: No single-threaded warning
- **WHEN** the stack's web app loads in a Chromium-based browser without isolation headers
- **THEN** the browser console holds no warning that skwasm runs single-threaded

#### Scenario: A proxy adds isolation headers
- **WHEN** a self-hoster's proxy adds `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, so the page is cross-origin isolated
- **THEN** the loader configuration still forces skwasm single-threaded, so the app does not start multi-threaded skwasm

### Requirement: The stack serves wasm files with their types
The self-host stack SHALL serve the web build's `.wasm` files with content type `application/wasm` and its `.mjs` files with a JavaScript content type, so browsers can compile and load them.

#### Scenario: Wasm and module types
- **WHEN** a client requests `main.dart.wasm` and `main.dart.mjs` from the running stack
- **THEN** the first answers with content type `application/wasm` and the second with a JavaScript content type

#### Scenario: Missing wasm file
- **WHEN** a client requests a `.wasm` path that the web build does not hold
- **THEN** the stack does not answer with content type `application/wasm`, so the loader fails on that file instead of compiling the app's `index.html`

### Requirement: The web build check requires a wasm build
The web build check SHALL fail unless the build configuration lists a WebAssembly build on skwasm before a JavaScript build on CanvasKit, and each entry point they name exists in the output. On failure it SHALL exit non-zero and name what is missing or out of order. This applies to every web build the check runs on, in addition to the existing self-contained checks.

#### Scenario: A wasm build passes
- **WHEN** the web build check runs on the output of the web build task
- **THEN** it exits 0

#### Scenario: A JavaScript-only build
- **WHEN** the web build check runs on a release build made without `--wasm`, which is otherwise self-contained
- **THEN** it exits non-zero and says the build configuration lists no WebAssembly build on skwasm

#### Scenario: A named entry point is missing
- **WHEN** the build configuration names `main.dart.wasm`, `main.dart.mjs` or `main.dart.js` but that file is absent from the output
- **THEN** the check exits non-zero and names the missing file

#### Scenario: No JavaScript fallback
- **WHEN** the build configuration lists a WebAssembly build but no JavaScript build on CanvasKit
- **THEN** the check exits non-zero and says browsers that cannot run skwasm would have no build to load

#### Scenario: Fallback listed first
- **WHEN** the build configuration lists the JavaScript build on CanvasKit before the WebAssembly build on skwasm
- **THEN** the check exits non-zero and says the loader would never choose skwasm

### Requirement: The product build check requires single-threaded skwasm
When asked to check the thread mode, the web build check SHALL fail unless every `forceSingleThreadedSkwasm` setting in the loader configuration is the literal `true` and at least one exists. The local web build task, the CI web build and the stack's build SHALL ask for it; a build that must run skwasm multi-threaded, such as the grid spike's benchmark, SHALL NOT.

#### Scenario: Product build passes
- **WHEN** the product web build task checks its output with the thread mode check
- **THEN** the check exits 0

#### Scenario: Setting missing, false or not a literal
- **WHEN** the thread mode check runs on a build whose bootstrap omits `forceSingleThreadedSkwasm`, sets it to `false`, or sets it from a variable
- **THEN** the check exits non-zero and says skwasm could start multi-threaded

#### Scenario: Spike build without the thread mode check
- **WHEN** the grid spike's build task checks its `--wasm` output, whose bootstrap sets `forceSingleThreadedSkwasm` from a query switch
- **THEN** the check runs without the thread mode check and exits 0
