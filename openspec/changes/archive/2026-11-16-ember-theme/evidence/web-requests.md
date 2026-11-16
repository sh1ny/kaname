# Web requests of the served app (A5, S4)

Date: 2026-11-16. Flutter 3.47.9 (Dart 3.13.7), engine revision 89c39edfdf.
Browser: Playwright Chromium headless shell 159.0.8154.6 (software GL).

## How the glyph was shown

The app's placeholder screen was changed for this run only, from
`Text('Kaname')` to `Text('Kaname 要')` (uncommitted; reverted afterwards,
`git diff app/lib` is empty). The app was built with `mise run build:web`
(`--no-web-resources-cdn` and the `webbuild:check` step), served through the
real stack with `mise run stack:up` (Caddy on `http://localhost/`), and loaded
in the headless browser. 要 is covered by neither Geist nor Literata.

## Requests

The capture listened at browser-context level, which includes requests made by
service workers (none appeared). All 19 requests, of one origin:

### http://localhost (19 requests)
200  page  /
200  page  /flutter_bootstrap.js
200  page  /canvaskit/chromium/canvaskit.wasm
200  page  /canvaskit/chromium/canvaskit.js
200  page  /main.dart.js
200  page  /assets/FontManifest.json
200  page  /assets/fonts/MaterialIcons-Regular.otf
200  page  /assets/packages/kaname_ember_ui/fonts/Geist%255Bwght%255D.ttf
200  page  /assets/packages/kaname_ember_ui/fonts/Literata%255Bopsz,wght%255D.ttf
200  page  /assets/packages/kaname_ember_ui/fonts/Literata-Italic%255Bopsz,wght%255D.ttf
200  page  /assets/packages/cupertino_icons/assets/CupertinoIcons.ttf
200  page  /assets/fonts/fallback/Roboto-Regular.ttf
200  page  /assets/packages/kaname_ember_ui/fonts/OFL-geist.txt
200  page  /assets/packages/kaname_ember_ui/fonts/OFL-literata.txt
404  page  /font-fallback/notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYkldv7JjxkkgFsFSSOPMOkySAZ73y9ViAt3acb8NexQ2w.118.woff2
404  page  /font-fallback/notosanstc/v36/-nFuOG829Oofr2wohFbTp9ifNAn722rq0MXz76Cy_C8mrWSt1KeqzFVoizG-KdWhyhvKuGOf8EUcrq3YKp7nxxk.118.woff2
404  page  /font-fallback/notosanshk/v32/nKKF-GM_FYFRJvXzVXaAPe97P1KHynJFP716qHB--oD7kYrUzT7-NvA3pTohjc3XVtNXX8A7gG1LO2KAPAw.118.woff2
404  page  /font-fallback/notosansjp/v53/-F6jfjtqLzI2JPCgQBnw7HFyzSD-AsregP8VFBEj756wwr4v0qHnANADNsISRDl2PRkiiWsg.116.woff2
404  page  /font-fallback/notosanskr/v36/PbyxFmXiEBPT4ITbgNA5Cgms3VYcOA-vvnIzzuoyeLGC5nwuDo-KBTUm6CryotyJROlrnQ.70.woff2


Origins seen: `http://localhost` only. No request to any other host, no failed
request other than the HTTP 404s listed above.

### Font-fallback requests

Five requests under `/font-fallback/`, all answered `404` by Caddy with the
plain-text body `Not Found` (the engine asked for Noto Sans SC, TC, HK, JP and
KR to cover 要). Engine console output (`console.warn`) for each:
`Permanent HTTP failure (status 404) for Noto Sans SC ...`, then
`Could not find a set of Noto fonts to display all missing characters. Please
add a font asset for the missing characters.`

### Finding against design A5

A5 expected every start-up to request Roboto from `/font-fallback/` and get a
404. In Flutter 3.47.9 that does not happen: Roboto is bundled by the build as
`/assets/fonts/fallback/Roboto-Regular.ttf` and served from the app's own
origin (`200`). Only characters it does not cover trigger `/font-fallback/`
requests (here the five CJK families). The requirement holds (nothing is
requested from another host); only the A5 sentence about a Roboto 404 on every
start-up is inaccurate for this Flutter version. The owner chose to amend A5
and task 7.9 to the observed behaviour, re-checked in design review round 5.

## Observation

The screenshot shows `Kaname` in Geist followed by the engine's missing-glyph
box (a hollow rectangle) in place of 要. Nothing was fetched from another host
to draw it.

## Conclusion

With the engine bundled and `fontFallbackBaseUrl` set to `/font-fallback/`, the
served web app contacts only its own origin. A glyph no bundled font covers
makes the engine request the fallback families at `/font-fallback/`, Caddy
answers 404, and the character shows as an empty box.

## Capture script

Run from a scratch directory with `npm i playwright` and
`npx playwright install chromium` (not part of the repository):
`node capture.mjs shot.png`.

```js
import { chromium } from 'playwright';

const origin = 'http://localhost';
const shot = process.argv[2];
const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const context = await browser.newContext({
  viewport: { width: 800, height: 400 },
  deviceScaleFactor: 2,
});
const requests = new Map(); // request -> {url, status, failure, via}
const log = [];
function track(req, via) {
  requests.set(req, { url: req.url(), via, status: null, failure: null });
}
// Context-level events include requests made by service workers.
context.on('request', (req) => track(req, req.serviceWorker() ? 'service-worker' : 'page'));
context.on('response', (res) => {
  const r = requests.get(res.request());
  if (r) r.status = res.status();
});
context.on('requestfailed', (req) => {
  const r = requests.get(req);
  if (r) r.failure = req.failure()?.errorText ?? 'failed';
});
const page = await context.newPage();
page.on('console', (m) => log.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => log.push(`[pageerror] ${e.message}`));
await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 30000 });
await page.waitForTimeout(8000);
await page.screenshot({ path: shot });
await context.close();
await browser.close();

const byOrigin = {};
for (const r of requests.values()) {
  const o = new URL(r.url).origin;
  (byOrigin[o] ??= []).push(r);
}
for (const [o, list] of Object.entries(byOrigin)) {
  console.log(`\n## ${o} (${list.length} requests)`);
  for (const r of list) {
    console.log(`${r.status ?? 'n/a'}${r.failure ? ' FAILED ' + r.failure : ''}  ${r.via}  ${new URL(r.url).pathname}${new URL(r.url).search}`);
  }
}
console.log('\n## console');
for (const l of log) console.log(l);
```
