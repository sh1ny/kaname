# Benchmark evidence: development machine

- **Machine:** the owner's development PC, Intel Core i7-13700K, through WSL2 (Linux 6.18, 6 logical CPUs and 23 GB visible to WSL).
- **Browser:** Chrome for Testing 157.0.8103.78, headless, viewport 1600×900 at device pixel ratio 1.
- **GPU path:** software. WebGL reports `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)`. This is Chrome's own WebGL renderer string, recorded by the runner, not a copy of the `chrome://gpu` page. The runner launches Chrome with `--enable-unsafe-swiftshader` because WSL exposes no GPU to headless Chrome (A3).
- **Load state:** the owner confirmed the machine idle ("i am done gaming", 2026-11-17); load average 0.05 before the earlier run and 0.58 before the current one (the preceding build).
- **Serving:** `kaname_tools serve` on loopback with COOP/COEP.

The JSON below is the runner's output as written, except that the Chrome executable's absolute path is shortened to its path under the spike.

## Current run (2026-11-18, about 01:01 local time)

`mise run bench:spike` after pre-ship review round 2: frame timings matched to their frames by frame number, calibration on an empty animation, and the full-set sort and group steps. The report quotes this run.

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
  "url": "http://127.0.0.1:44793/?bench=1&renderer=skwasm&threads=multi",
  "elapsedSeconds": 96.105,
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
    "seedMs": 43.885,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1200,
        "missedFrames": 1,
        "missedRatio": 0.0008326394671107411,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 33.33,
        "work": {
          "samples": 1200,
          "p90Ms": 12.845
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 940,
        "missedFrames": 863,
        "missedRatio": 0.4786466999445369,
        "p50Ms": 33.33,
        "p90Ms": 33.34,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 940,
          "p90Ms": 81.125
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 934,
        "missedFrames": 868,
        "missedRatio": 0.4816870144284129,
        "p50Ms": 33.33,
        "p90Ms": 49.995,
        "p99Ms": 50,
        "maxMs": 66.665,
        "work": {
          "samples": 935,
          "p90Ms": 84.83
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 301,
        "missedFrames": 0,
        "missedRatio": 0,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 16.67,
        "maxMs": 16.67,
        "work": {
          "samples": 301,
          "p90Ms": 11.82
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
        "maxMs": 33.335,
        "work": {
          "samples": 297,
          "p90Ms": 13.2
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.64,
        "untilFrameMs": 53.83,
        "rasterMs": 47.9,
        "untilOnScreenMs": 101.72999999999999
      },
      {
        "step": "category",
        "engineMs": 5.67,
        "untilFrameMs": 49.38,
        "rasterMs": 32.805,
        "untilOnScreenMs": 82.185
      },
      {
        "step": "sortText",
        "engineMs": 3.845,
        "untilFrameMs": 32.75,
        "rasterMs": 25.54,
        "untilOnScreenMs": 58.29
      },
      {
        "step": "sortInteger",
        "engineMs": 3.07,
        "untilFrameMs": 24.62,
        "rasterMs": 24.12,
        "untilOnScreenMs": 48.74
      },
      {
        "step": "sortFloat",
        "engineMs": 5.11,
        "untilFrameMs": 26.7,
        "rasterMs": 26.36,
        "untilOnScreenMs": 53.06
      },
      {
        "step": "groupFirst",
        "engineMs": 3.18,
        "untilFrameMs": 26.346,
        "rasterMs": 21.13,
        "untilOnScreenMs": 47.476
      },
      {
        "step": "groupSecond",
        "engineMs": 3.49,
        "untilFrameMs": 25.059,
        "rasterMs": 10.12,
        "untilOnScreenMs": 35.179
      },
      {
        "step": "collapseAll",
        "engineMs": 0.005,
        "untilFrameMs": 10.57,
        "rasterMs": 22.79,
        "untilOnScreenMs": 33.36
      },
      {
        "step": "expandAll",
        "engineMs": 0.035,
        "untilFrameMs": 22.705,
        "rasterMs": 133.855,
        "untilOnScreenMs": 156.56
      },
      {
        "step": "clear",
        "engineMs": 0.23,
        "untilFrameMs": 66.745,
        "rasterMs": 120.365,
        "untilOnScreenMs": 187.11
      },
      {
        "step": "sortTextFull",
        "engineMs": 66.625,
        "untilFrameMs": 121.965,
        "rasterMs": 130.141,
        "untilOnScreenMs": 252.106
      },
      {
        "step": "sortIntegerFull",
        "engineMs": 64.65,
        "untilFrameMs": 127.1,
        "rasterMs": 125.35,
        "untilOnScreenMs": 252.45
      },
      {
        "step": "sortFloatFull",
        "engineMs": 68.695,
        "untilFrameMs": 117.03,
        "rasterMs": 132.59,
        "untilOnScreenMs": 249.62
      },
      {
        "step": "groupFirstFull",
        "engineMs": 77.62,
        "untilFrameMs": 129.77,
        "rasterMs": null,
        "untilOnScreenMs": 129.77
      },
      {
        "step": "groupSecondFull",
        "engineMs": 80.845,
        "untilFrameMs": 135.395,
        "rasterMs": null,
        "untilOnScreenMs": 135.395
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 46.445,
        "rasterMs": null,
        "untilOnScreenMs": 46.445
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
  "url": "http://127.0.0.1:40177/?bench=1&renderer=skwasm&threads=single",
  "elapsedSeconds": 96.271,
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
    "seedMs": 43,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1199,
        "missedFrames": 2,
        "missedRatio": 0.0016652789342214821,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 16.8,
        "maxMs": 50,
        "work": {
          "samples": 1200,
          "p90Ms": 12.6
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 771,
        "missedFrames": 1030,
        "missedRatio": 0.5719044975013882,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.6,
        "maxMs": 66.7,
        "work": {
          "samples": 772,
          "p90Ms": 37
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 756,
        "missedFrames": 1046,
        "missedRatio": 0.5804661487236404,
        "p50Ms": 33.4,
        "p90Ms": 50,
        "p99Ms": 66.6,
        "maxMs": 66.7,
        "work": {
          "samples": 757,
          "p90Ms": 37.299
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 288,
        "missedFrames": 13,
        "missedRatio": 0.04318936877076412,
        "p50Ms": 16.7,
        "p90Ms": 16.7,
        "p99Ms": 33.4,
        "maxMs": 33.5,
        "work": {
          "samples": 289,
          "p90Ms": 11.401000000000002
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
        "maxMs": 50.1,
        "work": {
          "samples": 300,
          "p90Ms": 11.7
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.8,
        "untilFrameMs": 65.6,
        "rasterMs": 9.8,
        "untilOnScreenMs": 75.39999999999999
      },
      {
        "step": "category",
        "engineMs": 2.1,
        "untilFrameMs": 53.801,
        "rasterMs": 9.9,
        "untilOnScreenMs": 63.701
      },
      {
        "step": "sortText",
        "engineMs": 7.1,
        "untilFrameMs": 42.801,
        "rasterMs": 9.3,
        "untilOnScreenMs": 52.101
      },
      {
        "step": "sortInteger",
        "engineMs": 3.4,
        "untilFrameMs": 36.801,
        "rasterMs": 9.6,
        "untilOnScreenMs": 46.401
      },
      {
        "step": "sortFloat",
        "engineMs": 3.6,
        "untilFrameMs": 36.1,
        "rasterMs": 8.401,
        "untilOnScreenMs": 44.501000000000005
      },
      {
        "step": "groupFirst",
        "engineMs": 5.8,
        "untilFrameMs": 37,
        "rasterMs": 9.5,
        "untilOnScreenMs": 46.5
      },
      {
        "step": "groupSecond",
        "engineMs": 3.4,
        "untilFrameMs": 35.3,
        "rasterMs": 9,
        "untilOnScreenMs": 44.3
      },
      {
        "step": "collapseAll",
        "engineMs": 0,
        "untilFrameMs": 19.201,
        "rasterMs": 7.401,
        "untilOnScreenMs": 26.602
      },
      {
        "step": "expandAll",
        "engineMs": 0,
        "untilFrameMs": 28.7,
        "rasterMs": 9.1,
        "untilOnScreenMs": 37.8
      },
      {
        "step": "clear",
        "engineMs": 0.199,
        "untilFrameMs": 80.4,
        "rasterMs": 10,
        "untilOnScreenMs": 90.4
      },
      {
        "step": "sortTextFull",
        "engineMs": 74.4,
        "untilFrameMs": 137.5,
        "rasterMs": 9.3,
        "untilOnScreenMs": 146.8
      },
      {
        "step": "sortIntegerFull",
        "engineMs": 72,
        "untilFrameMs": 146.2,
        "rasterMs": 9.6,
        "untilOnScreenMs": 155.79999999999998
      },
      {
        "step": "sortFloatFull",
        "engineMs": 72.9,
        "untilFrameMs": 139.4,
        "rasterMs": 8.799,
        "untilOnScreenMs": 148.199
      },
      {
        "step": "groupFirstFull",
        "engineMs": 82.6,
        "untilFrameMs": 155.8,
        "rasterMs": 9.9,
        "untilOnScreenMs": 165.70000000000002
      },
      {
        "step": "groupSecondFull",
        "engineMs": 80.1,
        "untilFrameMs": 156.6,
        "rasterMs": null,
        "untilOnScreenMs": 156.6
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 50.699,
        "rasterMs": null,
        "untilOnScreenMs": 50.699
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
  "url": "http://127.0.0.1:43799/?bench=1&renderer=canvaskit&threads=na",
  "elapsedSeconds": 96.088,
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
    "seedMs": 54.074,
    "droppedSamples": 0,
    "segments": {
      "handSpeed": {
        "judged": true,
        "plannedSeconds": 20,
        "intervals": 1074,
        "missedFrames": 127,
        "missedRatio": 0.10574521232306411,
        "p50Ms": 16.665,
        "p90Ms": 33.33,
        "p99Ms": 33.335,
        "maxMs": 50,
        "work": {
          "samples": 1075,
          "p90Ms": 19.802
        }
      },
      "stressDown": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 456,
        "missedFrames": 1346,
        "missedRatio": 0.7469478357380688,
        "p50Ms": 66.665,
        "p90Ms": 66.67,
        "p99Ms": 83.335,
        "maxMs": 83.335,
        "work": {
          "samples": 457,
          "p90Ms": 64.865
        }
      },
      "stressUp": {
        "judged": false,
        "plannedSeconds": 30,
        "intervals": 473,
        "missedFrames": 1329,
        "missedRatio": 0.7375138734739178,
        "p50Ms": 66.665,
        "p90Ms": 66.67,
        "p99Ms": 83.33,
        "maxMs": 99.995,
        "work": {
          "samples": 474,
          "p90Ms": 61.55
        }
      },
      "horizontalOut": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 294,
        "missedFrames": 7,
        "missedRatio": 0.023255813953488372,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.33,
        "maxMs": 49.995,
        "work": {
          "samples": 295,
          "p90Ms": 16.326
        }
      },
      "horizontalBack": {
        "judged": false,
        "plannedSeconds": 5,
        "intervals": 291,
        "missedFrames": 10,
        "missedRatio": 0.03322259136212625,
        "p50Ms": 16.665,
        "p90Ms": 16.67,
        "p99Ms": 33.33,
        "maxMs": 66.665,
        "work": {
          "samples": 292,
          "p90Ms": 16.325
        }
      }
    },
    "operations": [
      {
        "step": "filter",
        "engineMs": 1.885,
        "untilFrameMs": 69.095,
        "rasterMs": 13.985,
        "untilOnScreenMs": 83.08
      },
      {
        "step": "category",
        "engineMs": 1.49,
        "untilFrameMs": 63.945,
        "rasterMs": 14.051,
        "untilOnScreenMs": 77.996
      },
      {
        "step": "sortText",
        "engineMs": 2.685,
        "untilFrameMs": 52.535,
        "rasterMs": 14.545,
        "untilOnScreenMs": 67.08
      },
      {
        "step": "sortInteger",
        "engineMs": 3.029,
        "untilFrameMs": 50.765,
        "rasterMs": 14.3,
        "untilOnScreenMs": 65.065
      },
      {
        "step": "sortFloat",
        "engineMs": 3.174,
        "untilFrameMs": 57.366,
        "rasterMs": 14.406,
        "untilOnScreenMs": 71.772
      },
      {
        "step": "groupFirst",
        "engineMs": 3.06,
        "untilFrameMs": 52.884,
        "rasterMs": 14.985,
        "untilOnScreenMs": 67.869
      },
      {
        "step": "groupSecond",
        "engineMs": 3.164,
        "untilFrameMs": 54.81,
        "rasterMs": 25.55,
        "untilOnScreenMs": 80.36
      },
      {
        "step": "collapseAll",
        "engineMs": 0.059,
        "untilFrameMs": 50.67,
        "rasterMs": 10.776,
        "untilOnScreenMs": 61.446
      },
      {
        "step": "expandAll",
        "engineMs": 0.01,
        "untilFrameMs": 60.981,
        "rasterMs": 11.62,
        "untilOnScreenMs": 72.601
      },
      {
        "step": "clear",
        "engineMs": 0.324,
        "untilFrameMs": 79.656,
        "rasterMs": 60.96,
        "untilOnScreenMs": 140.616
      },
      {
        "step": "sortTextFull",
        "engineMs": 48.245,
        "untilFrameMs": 140.169,
        "rasterMs": 52.41,
        "untilOnScreenMs": 192.579
      },
      {
        "step": "sortIntegerFull",
        "engineMs": 40.275,
        "untilFrameMs": 133.255,
        "rasterMs": 54.93,
        "untilOnScreenMs": 188.185
      },
      {
        "step": "sortFloatFull",
        "engineMs": 44.215,
        "untilFrameMs": 116.8,
        "rasterMs": 60.72,
        "untilOnScreenMs": 177.51999999999998
      },
      {
        "step": "groupFirstFull",
        "engineMs": 50.506,
        "untilFrameMs": 126.595,
        "rasterMs": 56.75,
        "untilOnScreenMs": 183.345
      },
      {
        "step": "groupSecondFull",
        "engineMs": 44.975,
        "untilFrameMs": 125.195,
        "rasterMs": null,
        "untilOnScreenMs": 125.195
      },
      {
        "step": "resize",
        "engineMs": null,
        "untilFrameMs": 52.995,
        "rasterMs": null,
        "untilOnScreenMs": 52.995
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

The first `mise run bench:spike`, before the pre-ship review fixes: raster times could be credited to the wrong frame, and work timings that arrived late were counted to the step running when they arrived. The multi-threaded row crashed; `mise run bench:spike:run -- --row skwasm-threaded --out build/grid-bench-retry<n>` re-ran it twice. Kept for the crash record.

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
