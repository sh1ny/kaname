{{flutter_js}}
{{flutter_build_config}}

// Fallback fonts load from an empty path on the app's own origin, never from
// the engine's default Google host. Caddy answers /font-fallback/* with 404
// (deploy/Caddyfile): keep the two paths identical. `kaname_tools webbuild
// --check` fails the build when this setting is missing or is not an
// own-origin path.
//
// skwasm runs single-threaded whatever headers the origin sends: multi-threaded
// skwasm crashed intermittently in the grid spike (docs/spikes/web-grid.md).
// `kaname_tools webbuild --check --single-threaded` fails the build unless
// forceSingleThreadedSkwasm is the literal true; see the doc comment on
// WebBuildChecker before turning it off.
//
// wasmAllowList stays at Flutter's default, so only Chromium-based browsers get
// skwasm, and Firefox and Safari get the CanvasKit build. Widening the list
// needs a measured run on those browsers first.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "/font-fallback/",
    forceSingleThreadedSkwasm: true,
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
