# Benchmark evidence: development machine

- **Machine:** the owner's development PC, Intel Core i7-13700K, through WSL2 (Linux 6.18, 6 logical CPUs and 23 GB visible to WSL).
- **Browser:** Chrome for Testing 157.0.8103.78, headless, viewport 1600×900 at device pixel ratio 1.
- **GPU path:** software. WebGL reports `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)`. This is Chrome's own WebGL renderer string, recorded by the runner, not a copy of the `chrome://gpu` page. The runner launches Chrome with `--enable-unsafe-swiftshader` because WSL exposes no GPU to headless Chrome (A3).
- **Load state:** the owner confirmed the machine idle ("i am done gaming", 2026-11-17); load average 0.05 before the first run and 0.58 before the second (the preceding build).
- **Serving:** `kaname_tools serve` on loopback with COOP/COEP.

The JSON below is the runner's output as written, except that the Chrome executable's absolute path is shortened to its path under the spike.

## Current run (2026-11-18, about 00:40 local time)

`mise run bench:spike` after the pre-ship review fix that matches frame timings to their frames by frame number. The report quotes this run.

### skwasm multi-threaded

`build/grid-bench/skwasm-multi.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-threaded",
  "renderer": "skwasm",
  "threads": "multi",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:37831/?bench=1&renderer=skwasm&threads=multi",
  "elapsedSeconds": 94.978,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": true
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "skwasm",
      "requestedRenderer": "skwasm",
      "threadMode": "multi",
      "wasm": true,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.665,
    "seedMs": 43.226,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1198,
        "missedFrames": 3,
        "missedRatio": 0.002497918401332223,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 66.66,
        "work": {
          "samples": 1198,
          "p90Ms": 12.154
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 939,
        "missedFrames": 863,
        "missedRatio": 0.47891231964483905,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 939,
          "p90Ms": 83.826
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 938,
        "missedFrames": 864,
        "missedRatio": 0.4794672586015538,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 50,
        "work": {
          "samples": 938,
          "p90Ms": 82.506
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 298,
        "missedFrames": 3,
        "missedRatio": 0.009966777408637873,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 66.665,
        "work": {
          "samples": 295,
          "p90Ms": 13.699
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 300,
        "missedFrames": 1,
        "missedRatio": 0.0033222591362126247,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 33.33,
        "work": {
          "samples": 300,
          "p90Ms": 12.55
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.674,
        "untilFrameMs": 56.704,
        "rasterMs": 47.04,
        "untilOnScreenMs": 103.744
      },
      {
        "step": "category",
        "engineMs": 2.056,
        "untilFrameMs": 44.735,
        "rasterMs": 28.864,
        "untilOnScreenMs": 73.599
      },
      {
        "step": "sortText",
        "engineMs": 3.43,
        "untilFrameMs": 27.26,
        "rasterMs": 24.5,
        "untilOnScreenMs": 51.760000000000005
      },
      {
        "step": "sortInteger",
        "engineMs": 5.505,
        "untilFrameMs": 27.37,
        "rasterMs": 26,
        "untilOnScreenMs": 53.370000000000005
      },
      {
        "step": "sortFloat",
        "engineMs": 3.271,
        "untilFrameMs": 25,
        "rasterMs": 24.51,
        "untilOnScreenMs": 49.510000000000005
      },
      {
        "step": "groupFirst",
        "engineMs": 4.61,
        "untilFrameMs": 26.425,
        "rasterMs": 21.724,
        "untilOnScreenMs": 48.149
      },
      {
        "step": "groupSecond",
        "engineMs": 3.245,
        "untilFrameMs": 25.271,
        "rasterMs": 10.32,
        "untilOnScreenMs": 35.591
      },
      {
        "step": "collapseAll",
        "engineMs": 0.005,
        "untilFrameMs": 10.889,
        "rasterMs": 23.555,
        "untilOnScreenMs": 34.444
      },
      {
        "step": "expandAll",
        "engineMs": 0.03,
        "untilFrameMs": 23.519,
        "rasterMs": 64.52,
        "untilOnScreenMs": 88.03899999999999
      },
      {
        "step": "clear",
        "engineMs": 0.224,
        "untilFrameMs": 64,
        "rasterMs": null,
        "untilOnScreenMs": 64
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 42.83,
        "rasterMs": null,
        "untilOnScreenMs": 42.83
      }
    ],
    "verdict": {
      "missedOk": true,
      "p99Ok": true,
      "workOk": true,
      "operationsOk": true,
      "passed": true
    }
  }
}
```

### skwasm single-threaded

`build/grid-bench/skwasm-single.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-single",
  "renderer": "skwasm",
  "threads": "single",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:40367/?bench=1&renderer=skwasm&threads=single",
  "elapsedSeconds": 95.189,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": false
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "skwasm",
      "requestedRenderer": "skwasm",
      "threadMode": "single",
      "wasm": true,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.7,
    "seedMs": 43.8,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1197,
        "missedFrames": 4,
        "missedRatio": 0.0033305578684429643,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 16.8,
        "maxMs": 83.3,
        "work": {
          "samples": 1198,
          "p90Ms": 12.2
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 765,
        "missedFrames": 1037,
        "missedRatio": 0.5754716981132075,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.7,
        "maxMs": 66.7,
        "work": {
          "samples": 766,
          "p90Ms": 36.501
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 752,
        "missedFrames": 1049,
        "missedRatio": 0.5824541921154914,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.699,
        "maxMs": 66.7,
        "work": {
          "samples": 753,
          "p90Ms": 36.601
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 299,
        "missedFrames": 2,
        "missedRatio": 0.006644518272425249,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 16.8,
        "maxMs": 50,
        "work": {
          "samples": 300,
          "p90Ms": 11.8
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 296,
        "missedFrames": 5,
        "missedRatio": 0.016611295681063124,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 33.3,
        "maxMs": 50,
        "work": {
          "samples": 297,
          "p90Ms": 11.8
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.599,
        "untilFrameMs": 60.401,
        "rasterMs": 9.101,
        "untilOnScreenMs": 69.50200000000001
      },
      {
        "step": "category",
        "engineMs": 2,
        "untilFrameMs": 55.5,
        "rasterMs": 9.2,
        "untilOnScreenMs": 64.7
      },
      {
        "step": "sortText",
        "engineMs": 3.5,
        "untilFrameMs": 36.7,
        "rasterMs": 8.3,
        "untilOnScreenMs": 45
      },
      {
        "step": "sortInteger",
        "engineMs": 4.8,
        "untilFrameMs": 34,
        "rasterMs": 9.101,
        "untilOnScreenMs": 43.101
      },
      {
        "step": "sortFloat",
        "engineMs": 3.2,
        "untilFrameMs": 33.801,
        "rasterMs": 9,
        "untilOnScreenMs": 42.801
      },
      {
        "step": "groupFirst",
        "engineMs": 3.101,
        "untilFrameMs": 34.6,
        "rasterMs": 10.299,
        "untilOnScreenMs": 44.899
      },
      {
        "step": "groupSecond",
        "engineMs": 3.401,
        "untilFrameMs": 33.101,
        "rasterMs": 9.4,
        "untilOnScreenMs": 42.501
      },
      {
        "step": "collapseAll",
        "engineMs": 0,
        "untilFrameMs": 19,
        "rasterMs": 6.899,
        "untilOnScreenMs": 25.899
      },
      {
        "step": "expandAll",
        "engineMs": 0.101,
        "untilFrameMs": 26.7,
        "rasterMs": 7.801,
        "untilOnScreenMs": 34.501
      },
      {
        "step": "clear",
        "engineMs": 0.3,
        "untilFrameMs": 72.8,
        "rasterMs": 8.7,
        "untilOnScreenMs": 81.5
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 44.299,
        "rasterMs": null,
        "untilOnScreenMs": 44.299
      }
    ],
    "verdict": {
      "missedOk": true,
      "p99Ok": true,
      "workOk": true,
      "operationsOk": true,
      "passed": true
    }
  }
}
```

### CanvasKit

`build/grid-bench/canvaskit-na.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "canvaskit",
  "renderer": "canvaskit",
  "threads": "na",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:46733/?bench=1&renderer=canvaskit&threads=na",
  "elapsedSeconds": 96.324,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": true
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "CanvasKit",
      "requestedRenderer": "canvaskit",
      "threadMode": "n/a",
      "wasm": false,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.665,
    "seedMs": 50.784,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1079,
        "missedFrames": 123,
        "missedRatio": 0.10232945091514144,
        "p50Ms": 16.665,
        "p90Ms": 33.33,
        "p99Ms": 33.335,
        "maxMs": 99.995,
        "work": {
          "samples": 1080,
          "p90Ms": 18.652
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 474,
        "missedFrames": 1328,
        "missedRatio": 0.7369589345172031,
        "p50Ms": 66.665,
        "p90Ms": 66.665,
        "p99Ms": 83.335,
        "maxMs": 99.995,
        "work": {
          "samples": 475,
          "p90Ms": 60.825
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 479,
        "missedFrames": 1322,
        "missedRatio": 0.7340366463076069,
        "p50Ms": 66.665,
        "p90Ms": 66.67,
        "p99Ms": 83.33,
        "maxMs": 83.335,
        "work": {
          "samples": 480,
          "p90Ms": 59.801
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 287,
        "missedFrames": 14,
        "missedRatio": 0.046511627906976744,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.335,
        "maxMs": 66.66,
        "work": {
          "samples": 288,
          "p90Ms": 16.739
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 286,
        "missedFrames": 15,
        "missedRatio": 0.04983388704318937,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.335,
        "maxMs": 66.665,
        "work": {
          "samples": 287,
          "p90Ms": 17.13
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.696,
        "untilFrameMs": 69.155,
        "rasterMs": 12.969,
        "untilOnScreenMs": 82.124
      },
      {
        "step": "category",
        "engineMs": 1.609,
        "untilFrameMs": 62.505,
        "rasterMs": 14.06,
        "untilOnScreenMs": 76.565
      },
      {
        "step": "sortText",
        "engineMs": 2.675,
        "untilFrameMs": 50.765,
        "rasterMs": 13.786,
        "untilOnScreenMs": 64.551
      },
      {
        "step": "sortInteger",
        "engineMs": 2.764,
        "untilFrameMs": 53.659,
        "rasterMs": 14.271,
        "untilOnScreenMs": 67.93
      },
      {
        "step": "sortFloat",
        "engineMs": 2.879,
        "untilFrameMs": 48.164,
        "rasterMs": 13.325,
        "untilOnScreenMs": 61.489000000000004
      },
      {
        "step": "groupFirst",
        "engineMs": 2.591,
        "untilFrameMs": 52.031,
        "rasterMs": 14.216,
        "untilOnScreenMs": 66.247
      },
      {
        "step": "groupSecond",
        "engineMs": 2.971,
        "untilFrameMs": 50.656,
        "rasterMs": 23.016,
        "untilOnScreenMs": 73.672
      },
      {
        "step": "collapseAll",
        "engineMs": 0.044,
        "untilFrameMs": 45.765,
        "rasterMs": 10.119,
        "untilOnScreenMs": 55.884
      },
      {
        "step": "expandAll",
        "engineMs": 0.01,
        "untilFrameMs": 59.98,
        "rasterMs": 11.604,
        "untilOnScreenMs": 71.584
      },
      {
        "step": "clear",
        "engineMs": 0.285,
        "untilFrameMs": 78.96,
        "rasterMs": null,
        "untilOnScreenMs": 78.96
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 83.005,
        "rasterMs": null,
        "untilOnScreenMs": 83.005
      }
    ],
    "verdict": {
      "missedOk": false,
      "p99Ok": false,
      "workOk": false,
      "operationsOk": true,
      "passed": false
    }
  }
}
```

### Summary

`build/grid-bench/summary.json`

```json
{
  "runnerSchemaVersion": 1,
  "rows": [
    {
      "row": "skwasm-threaded",
      "file": "skwasm-multi.json",
      "status": "done",
      "reason": null,
      "smoke": false,
      "verdictPassed": true
    },
    {
      "row": "skwasm-single",
      "file": "skwasm-single.json",
      "status": "done",
      "reason": null,
      "smoke": false,
      "verdictPassed": true
    },
    {
      "row": "canvaskit",
      "file": "canvaskit-na.json",
      "status": "done",
      "reason": null,
      "smoke": false,
      "verdictPassed": false
    }
  ]
}
```

## Earlier run (2026-11-17, about 23:20 to 23:35 local time)

The first `mise run bench:spike`, before that fix: raster times could be credited to the wrong frame, and work timings that arrived late were counted to the step running when they arrived. The multi-threaded row crashed; `mise run bench:spike:run -- --row skwasm-threaded --out build/grid-bench-retry<n>` re-ran it twice. Kept for the crash record.

### Full run, skwasm multi-threaded (failed)

`build/grid-bench/skwasm-multi.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-threaded",
  "renderer": "skwasm",
  "threads": "multi",
  "status": "failed",
  "reason": "Page error: Evaluation failed: RuntimeError: memory access out of bounds\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[221]:0xb9ca\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[2500]:0x77e49\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[2529]:0x78bb6\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[4105]:0xe22a3\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[9209]:0x2267b7\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[10232]:0x26d31d\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[3912]:0x1056ce)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[4128]:0x10d24e)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[11072]:0x1c7c5a)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[11735]:0x1e141b)",
  "smoke": false,
  "url": "http://127.0.0.1:44265/?bench=1&renderer=skwasm&threads=multi",
  "elapsedSeconds": 100.118,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": null,
    "webglRenderer": null,
    "crossOriginIsolated": null
  },
  "consoleErrors": [],
  "result": null
}
```

### Full run, skwasm single-threaded

`build/grid-bench/skwasm-single.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-single",
  "renderer": "skwasm",
  "threads": "single",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:39605/?bench=1&renderer=skwasm&threads=single",
  "elapsedSeconds": 95.28,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": false
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "skwasm",
      "requestedRenderer": "skwasm",
      "threadMode": "single",
      "wasm": true,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.7,
    "seedMs": 47.3,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1196,
        "missedFrames": 5,
        "missedRatio": 0.004163197335553705,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 16.8,
        "maxMs": 83.3,
        "work": {
          "samples": 1203,
          "p90Ms": 12.8
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 731,
        "missedFrames": 1070,
        "missedRatio": 0.5941143808995003,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.7,
        "maxMs": 66.8,
        "work": {
          "samples": 730,
          "p90Ms": 38.2
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 723,
        "missedFrames": 1079,
        "missedRatio": 0.5987791342952276,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.7,
        "maxMs": 66.8,
        "work": {
          "samples": 726,
          "p90Ms": 38.4
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 296,
        "missedFrames": 5,
        "missedRatio": 0.016611295681063124,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 33.4,
        "maxMs": 49.9,
        "work": {
          "samples": 295,
          "p90Ms": 12.8
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 299,
        "missedFrames": 2,
        "missedRatio": 0.006644518272425249,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 16.8,
        "maxMs": 50,
        "work": {
          "samples": 301,
          "p90Ms": 12.200000000000001
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.7,
        "untilFrameMs": 57.1,
        "rasterMs": null,
        "untilOnScreenMs": 57.1
      },
      {
        "step": "category",
        "engineMs": 6.1,
        "untilFrameMs": 60.5,
        "rasterMs": 9.1,
        "untilOnScreenMs": 69.6
      },
      {
        "step": "sortText",
        "engineMs": 3.9,
        "untilFrameMs": 41.9,
        "rasterMs": null,
        "untilOnScreenMs": 41.9
      },
      {
        "step": "sortInteger",
        "engineMs": 3.2,
        "untilFrameMs": 35,
        "rasterMs": null,
        "untilOnScreenMs": 35
      },
      {
        "step": "sortFloat",
        "engineMs": 4.8,
        "untilFrameMs": 36.7,
        "rasterMs": 9,
        "untilOnScreenMs": 45.7
      },
      {
        "step": "groupFirst",
        "engineMs": 3.6,
        "untilFrameMs": 37.4,
        "rasterMs": null,
        "untilOnScreenMs": 37.4
      },
      {
        "step": "groupSecond",
        "engineMs": 3.3,
        "untilFrameMs": 32.8,
        "rasterMs": null,
        "untilOnScreenMs": 32.8
      },
      {
        "step": "collapseAll",
        "engineMs": 0,
        "untilFrameMs": 19,
        "rasterMs": null,
        "untilOnScreenMs": 19
      },
      {
        "step": "expandAll",
        "engineMs": 0,
        "untilFrameMs": 30,
        "rasterMs": 8.4,
        "untilOnScreenMs": 38.4
      },
      {
        "step": "clear",
        "engineMs": 0.2,
        "untilFrameMs": 80.4,
        "rasterMs": null,
        "untilOnScreenMs": 80.4
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 51.5,
        "rasterMs": null,
        "untilOnScreenMs": 51.5
      }
    ],
    "verdict": {
      "missedOk": true,
      "p99Ok": true,
      "workOk": true,
      "operationsOk": true,
      "passed": true
    }
  }
}
```

### Full run, CanvasKit

`build/grid-bench/canvaskit-na.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "canvaskit",
  "renderer": "canvaskit",
  "threads": "na",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:44223/?bench=1&renderer=canvaskit&threads=na",
  "elapsedSeconds": 96.022,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": true
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "CanvasKit",
      "requestedRenderer": "canvaskit",
      "threadMode": "n/a",
      "wasm": false,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.67,
    "seedMs": 52.961,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1017,
        "missedFrames": 185,
        "missedRatio": 0.15391014975041598,
        "p50Ms": 16.665,
        "p90Ms": 33.33,
        "p99Ms": 33.335,
        "maxMs": 100,
        "work": {
          "samples": 1021,
          "p90Ms": 19.75
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 461,
        "missedFrames": 1341,
        "missedRatio": 0.744173140954495,
        "p50Ms": 66.665,
        "p90Ms": 66.67,
        "p99Ms": 83.335,
        "maxMs": 99.995,
        "work": {
          "samples": 462,
          "p90Ms": 63.065
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 457,
        "missedFrames": 1346,
        "missedRatio": 0.7465335551858014,
        "p50Ms": 66.665,
        "p90Ms": 66.67,
        "p99Ms": 83.335,
        "maxMs": 83.335,
        "work": {
          "samples": 458,
          "p90Ms": 63.056
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 285,
        "missedFrames": 16,
        "missedRatio": 0.053156146179401995,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.335,
        "maxMs": 50,
        "work": {
          "samples": 285,
          "p90Ms": 17.195
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 284,
        "missedFrames": 17,
        "missedRatio": 0.05647840531561462,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.335,
        "maxMs": 66.67,
        "work": {
          "samples": 280,
          "p90Ms": 16.959
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.916,
        "untilFrameMs": 70.576,
        "rasterMs": null,
        "untilOnScreenMs": 70.576
      },
      {
        "step": "category",
        "engineMs": 1.589,
        "untilFrameMs": 62.545,
        "rasterMs": 14.014,
        "untilOnScreenMs": 76.559
      },
      {
        "step": "sortText",
        "engineMs": 2.911,
        "untilFrameMs": 52.635,
        "rasterMs": null,
        "untilOnScreenMs": 52.635
      },
      {
        "step": "sortInteger",
        "engineMs": 2.769,
        "untilFrameMs": 54.664,
        "rasterMs": 14.956,
        "untilOnScreenMs": 69.62
      },
      {
        "step": "sortFloat",
        "engineMs": 2.956,
        "untilFrameMs": 49.426,
        "rasterMs": null,
        "untilOnScreenMs": 49.426
      },
      {
        "step": "groupFirst",
        "engineMs": 3.09,
        "untilFrameMs": 53.111,
        "rasterMs": 14.015,
        "untilOnScreenMs": 67.126
      },
      {
        "step": "groupSecond",
        "engineMs": 3.165,
        "untilFrameMs": 51.67,
        "rasterMs": null,
        "untilOnScreenMs": 51.67
      },
      {
        "step": "collapseAll",
        "engineMs": 0.06,
        "untilFrameMs": 48.26,
        "rasterMs": null,
        "untilOnScreenMs": 48.26
      },
      {
        "step": "expandAll",
        "engineMs": 0.014,
        "untilFrameMs": 59.986,
        "rasterMs": 24.81,
        "untilOnScreenMs": 84.79599999999999
      },
      {
        "step": "clear",
        "engineMs": 0.289,
        "untilFrameMs": 81.959,
        "rasterMs": null,
        "untilOnScreenMs": 81.959
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 78.81,
        "rasterMs": null,
        "untilOnScreenMs": 78.81
      }
    ],
    "verdict": {
      "missedOk": false,
      "p99Ok": false,
      "workOk": false,
      "operationsOk": true,
      "passed": false
    }
  }
}
```

### Full run, summary

`build/grid-bench/summary.json`

```json
{
  "runnerSchemaVersion": 1,
  "rows": [
    {
      "row": "skwasm-threaded",
      "file": "skwasm-multi.json",
      "status": "failed",
      "reason": "Page error: Evaluation failed: RuntimeError: memory access out of bounds\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[221]:0xb9ca\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[2500]:0x77e49\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[2529]:0x78bb6\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[4105]:0xe22a3\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[9209]:0x2267b7\n    at http://127.0.0.1:44265/canvaskit/skwasm.wasm:wasm-function[10232]:0x26d31d\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[3912]:0x1056ce)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[4128]:0x10d24e)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[11072]:0x1c7c5a)\n    at M (http://127.0.0.1:44265/main.dart.wasm:wasm-function[11735]:0x1e141b)",
      "smoke": false,
      "verdictPassed": null
    },
    {
      "row": "skwasm-single",
      "file": "skwasm-single.json",
      "status": "done",
      "reason": null,
      "smoke": false,
      "verdictPassed": true
    },
    {
      "row": "canvaskit",
      "file": "canvaskit-na.json",
      "status": "done",
      "reason": null,
      "smoke": false,
      "verdictPassed": false
    }
  ]
}
```

### Re-run 1, skwasm multi-threaded only

`build/grid-bench-retry1/skwasm-multi.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-threaded",
  "renderer": "skwasm",
  "threads": "multi",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:39109/?bench=1&renderer=skwasm&threads=multi",
  "elapsedSeconds": 94.974,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": true
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "skwasm",
      "requestedRenderer": "skwasm",
      "threadMode": "multi",
      "wasm": true,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.665,
    "seedMs": 44.06,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1198,
        "missedFrames": 3,
        "missedRatio": 0.002497918401332223,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 66.665,
        "work": {
          "samples": 1196,
          "p90Ms": 13.147
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 902,
        "missedFrames": 899,
        "missedRatio": 0.4991671293725708,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 66.67,
        "work": {
          "samples": 902,
          "p90Ms": 86.09
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 906,
        "missedFrames": 895,
        "missedRatio": 0.4969461410327596,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 906,
          "p90Ms": 84.15
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 299,
        "missedFrames": 2,
        "missedRatio": 0.006644518272425249,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 50,
        "work": {
          "samples": 296,
          "p90Ms": 13.98
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 300,
        "missedFrames": 1,
        "missedRatio": 0.0033222591362126247,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 33.33,
        "work": {
          "samples": 302,
          "p90Ms": 12.17
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.704,
        "untilFrameMs": 57.815,
        "rasterMs": null,
        "untilOnScreenMs": 57.815
      },
      {
        "step": "category",
        "engineMs": 2.151,
        "untilFrameMs": 47.83,
        "rasterMs": 9.716,
        "untilOnScreenMs": 57.546
      },
      {
        "step": "sortText",
        "engineMs": 3.541,
        "untilFrameMs": 28.781,
        "rasterMs": null,
        "untilOnScreenMs": 28.781
      },
      {
        "step": "sortInteger",
        "engineMs": 5.071,
        "untilFrameMs": 26.906,
        "rasterMs": null,
        "untilOnScreenMs": 26.906
      },
      {
        "step": "sortFloat",
        "engineMs": 3.271,
        "untilFrameMs": 24.695,
        "rasterMs": null,
        "untilOnScreenMs": 24.695
      },
      {
        "step": "groupFirst",
        "engineMs": 4.68,
        "untilFrameMs": 27.74,
        "rasterMs": 29.97,
        "untilOnScreenMs": 57.709999999999994
      },
      {
        "step": "groupSecond",
        "engineMs": 3.149,
        "untilFrameMs": 24.39,
        "rasterMs": null,
        "untilOnScreenMs": 24.39
      },
      {
        "step": "collapseAll",
        "engineMs": 0.005,
        "untilFrameMs": 11.485,
        "rasterMs": null,
        "untilOnScreenMs": 11.485
      },
      {
        "step": "expandAll",
        "engineMs": 0.035,
        "untilFrameMs": 19.59,
        "rasterMs": null,
        "untilOnScreenMs": 19.59
      },
      {
        "step": "clear",
        "engineMs": 0.235,
        "untilFrameMs": 62.445,
        "rasterMs": 20.94,
        "untilOnScreenMs": 83.385
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 40.84,
        "rasterMs": null,
        "untilOnScreenMs": 40.84
      }
    ],
    "verdict": {
      "missedOk": true,
      "p99Ok": true,
      "workOk": true,
      "operationsOk": true,
      "passed": true
    }
  }
}
```

### Re-run 2, skwasm multi-threaded only

`build/grid-bench-retry2/skwasm-multi.json`

```json
{
  "runnerSchemaVersion": 1,
  "row": "skwasm-threaded",
  "renderer": "skwasm",
  "threads": "multi",
  "status": "done",
  "reason": null,
  "smoke": false,
  "url": "http://127.0.0.1:42329/?bench=1&renderer=skwasm&threads=multi",
  "elapsedSeconds": 94.973,
  "environment": {
    "chromeExecutable": "build/chrome-for-testing/chrome-linux64/chrome",
    "chromeVersion": "Chrome/157.0.8103.78",
    "launchArgs": [
      "--enable-unsafe-swiftshader",
      "--disable-background-timer-throttling",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows"
    ],
    "viewport": {
      "width": 1600,
      "height": 900,
      "deviceScaleFactor": 1
    },
    "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "webglRenderer": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)",
    "crossOriginIsolated": true
  },
  "consoleErrors": [],
  "result": {
    "schemaVersion": 1,
    "config": {
      "name": "full",
      "plannedSeconds": {
        "calibrate": 2,
        "handSpeed": 20,
        "stressDown": 30,
        "stressUp": 30,
        "horizontalOut": 5,
        "horizontalBack": 5
      },
      "handSpeedPixelsPerSecond": 3000,
      "stepTimeoutSlackSeconds": 10
    },
    "environment": {
      "renderer": "skwasm",
      "requestedRenderer": "skwasm",
      "threadMode": "multi",
      "wasm": true,
      "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
      "window": {
        "width": 1600,
        "height": 900
      },
      "devicePixelRatio": 1
    },
    "refreshPeriodMs": 16.665,
    "seedMs": 45.384,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1198,
        "missedFrames": 3,
        "missedRatio": 0.002497918401332223,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 66.665,
        "work": {
          "samples": 1198,
          "p90Ms": 12.494
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 940,
        "missedFrames": 861,
        "missedRatio": 0.47806774014436426,
        "p50Ms": 33.33,
        "p90Ms": 33.335,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 939,
          "p90Ms": 82.452
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 936,
        "missedFrames": 866,
        "missedRatio": 0.48057713651498335,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 938,
          "p90Ms": 83.351
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 300,
        "missedFrames": 1,
        "missedRatio": 0.0033222591362126247,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 33.33,
        "work": {
          "samples": 299,
          "p90Ms": 13.52
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 300,
        "missedFrames": 1,
        "missedRatio": 0.0033222591362126247,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 33.33,
        "work": {
          "samples": 295,
          "p90Ms": 12.126999999999999
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.679,
        "untilFrameMs": 59.579,
        "rasterMs": null,
        "untilOnScreenMs": 59.579
      },
      {
        "step": "category",
        "engineMs": 2.02,
        "untilFrameMs": 46.299,
        "rasterMs": null,
        "untilOnScreenMs": 46.299
      },
      {
        "step": "sortText",
        "engineMs": 3.506,
        "untilFrameMs": 29.24,
        "rasterMs": 48.824,
        "untilOnScreenMs": 78.064
      },
      {
        "step": "sortInteger",
        "engineMs": 5.37,
        "untilFrameMs": 28.334,
        "rasterMs": null,
        "untilOnScreenMs": 28.334
      },
      {
        "step": "sortFloat",
        "engineMs": 3.32,
        "untilFrameMs": 25.93,
        "rasterMs": null,
        "untilOnScreenMs": 25.93
      },
      {
        "step": "groupFirst",
        "engineMs": 3.235,
        "untilFrameMs": 26.096,
        "rasterMs": null,
        "untilOnScreenMs": 26.096
      },
      {
        "step": "groupSecond",
        "engineMs": 4.755,
        "untilFrameMs": 25.525,
        "rasterMs": 25.31,
        "untilOnScreenMs": 50.834999999999994
      },
      {
        "step": "collapseAll",
        "engineMs": 0,
        "untilFrameMs": 10.325,
        "rasterMs": null,
        "untilOnScreenMs": 10.325
      },
      {
        "step": "expandAll",
        "engineMs": 0.036,
        "untilFrameMs": 20.665,
        "rasterMs": null,
        "untilOnScreenMs": 20.665
      },
      {
        "step": "clear",
        "engineMs": 0.349,
        "untilFrameMs": 62.75,
        "rasterMs": null,
        "untilOnScreenMs": 62.75
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 39.519,
        "rasterMs": null,
        "untilOnScreenMs": 39.519
      }
    ],
    "verdict": {
      "missedOk": true,
      "p99Ok": true,
      "workOk": true,
      "operationsOk": true,
      "passed": true
    }
  }
}
```
