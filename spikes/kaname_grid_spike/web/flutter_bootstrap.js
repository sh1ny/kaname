{{flutter_js}}
{{flutter_build_config}}

// Benchmark switches (design D8). `?renderer=skwasm|canvaskit` picks the
// renderer and `?threads=single` forces single-threaded skwasm. Without a
// parameter the loader's automatic choice applies; an unknown value is ignored
// and logged.
const params = new URLSearchParams(window.location.search);

const rendererParam = params.get("renderer");
let renderer;
if (rendererParam === "skwasm" || rendererParam === "canvaskit") {
  renderer = rendererParam;
} else if (rendererParam !== null) {
  console.warn(`Ignoring unknown renderer=${rendererParam}; expected skwasm or canvaskit.`);
}

const threadsParam = params.get("threads");
let forceSingleThreadedSkwasm = false;
if (threadsParam === "single") {
  forceSingleThreadedSkwasm = true;
} else if (threadsParam !== null) {
  console.warn(`Ignoring unknown threads=${threadsParam}; expected single.`);
}

// Fallback fonts load from an empty path on the app's own origin, as in the
// product bootstrap (app/web/flutter_bootstrap.js). `kaname_tools webbuild
// --check` recognises fontFallbackBaseUrl only as an object key followed by a
// string literal: keep that line in this literal.
_flutter.loader.load({
  config: {
    renderer: renderer,
    forceSingleThreadedSkwasm: forceSingleThreadedSkwasm,
    fontFallbackBaseUrl: "/font-fallback/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
