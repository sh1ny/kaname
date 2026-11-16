{{flutter_js}}
{{flutter_build_config}}

// Fallback fonts load from an empty path on the app's own origin, never from
// the engine's default Google host. Caddy answers /font-fallback/* with 404
// (deploy/Caddyfile): keep the two paths identical. `kaname_tools webbuild
// --check` fails the build when this setting is missing or is not an
// own-origin path.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "/font-fallback/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
