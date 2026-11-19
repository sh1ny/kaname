# Self-host stack

One Docker Compose file runs the whole Kaname stack: `postgres` (16), `redis`
(8), the `server`, and `caddy`, plus a one-shot `migrate` step that applies the
database migrations before the server starts. Caddy serves the web app at `/`,
routes `/api/` to the server with the prefix removed, and passes `/livez` and
`/readyz` through. Locally the stack serves plain HTTP at `http://localhost/`,
published on `127.0.0.1` only, so it is not reachable from the network. There
is no TLS yet; a deployment guide will add it.

## Supported platforms

The server is supported only as a `linux/amd64` container, which is how this
stack runs it, and on Linux for development and tests.

- On Windows and macOS, run the stack through a Linux container runtime such as
  Docker Desktop.
- On arm64 hosts, the image builds and runs under `linux/amd64` emulation,
  because Flutter's Linux toolchain archive is x64 only.
- Running the server natively on Windows or macOS is **unsupported**, and CI
  does not run its tests there.

## Run it

You need Docker with Compose, and [mise](https://mise.jdx.dev/) to build the
web app.

```sh
cp deploy/.env.example deploy/.env      # then replace every placeholder
mise run stack:up                       # builds the web app, then docker compose up
```

`stack:up` builds the web app first, because Caddy serves `app/build/web`; a
missing build gives a 404 at `/`. Then open `http://localhost/`. The first run
builds the server image from scratch (the Flutter toolchain and a Dart AOT
compile), which takes several minutes.

`deploy/.env` holds the three secrets: `POSTGRES_PASSWORD`, `REDIS_PASSWORD`
and `SERVERPOD_SERVICE_SECRET`. Compose stops before starting any service and
names the variable when one is missing or empty. The file is ignored by git;
only `deploy/.env.example`, with placeholders, is committed.

```sh
mise run stack:down                     # stop and delete the data volumes
(cd deploy && docker compose down)     # stop, keep the data
```

`docker compose down` keeps the named volumes `pgdata` and `redisdata`, so the
next `up` starts on the existing database and applies no migration twice.
`mise run stack:down` removes them as well.

## Static data

On a start with no active static-data build, the server queues an import of
CCP's latest SDE build on its compute worker. It reads
`https://developers.eveonline.com/static-data/tranquility/latest.jsonl` and
downloads the build's JSONL zip (about 95 MiB; about 560 MiB unpacked into the
container's temporary directory while it imports), so the server needs
outbound HTTPS to `developers.eveonline.com` on first start. The import runs in
the background: the server serves requests meanwhile, and the import takes
about half a minute once the download is done.

When the download fails (no internet access, a firewall, CCP unreachable), the
import is recorded as failed with its reason in the `sde_import` table, the
server keeps running with no active build, and the next start tries again.
There is no import from a local zip for self-hosted installs yet; a later
change adds one.

## Web app

The web app is one `--wasm` build that holds two builds of the same code, and
Flutter's loader picks one per browser:

- **Chromium-based browsers** (Chrome, Edge and others) with WasmGC and WebGL
  get the app compiled to WebAssembly with the skwasm renderer, single-threaded.
- **Firefox, Safari and browsers without WasmGC or WebGL** get the app compiled
  to JavaScript with the CanvasKit renderer. Flutter's default allow list keeps
  skwasm to Chromium, and Kaname keeps that default until skwasm has been
  measured on the other browsers.

The stack sends no `Cross-Origin-Opener-Policy` or
`Cross-Origin-Embedder-Policy` header, and the app's bootstrap
(`app/web/flutter_bootstrap.js`) sets `forceSingleThreadedSkwasm: true`. In the
grid spike, multi-threaded skwasm crashed intermittently inside the engine,
while single-threaded skwasm met the same performance budget and never crashed
(`docs/spikes/web-grid.md`). Because the bootstrap forces single-threaded
mode, the app stays single-threaded even if your own proxy adds those headers.
`mise run build:web` checks the setting with
`kaname_tools webbuild --check --single-threaded`.

To turn on multi-threaded skwasm later, make three changes together: remove
the setting from the bootstrap, drop `--single-threaded` from the
`webbuild:check` task, and add both headers to `deploy/Caddyfile`. Do this only
after the crash has been reproduced and fixed upstream.

Caddy serves the web files uncompressed for now, so the first load downloads
the full `.wasm` and `.js` files.

## Checks

`mise run stack:test` runs the stack tests in `server/kaname_client/test/stack/`
against a running stack (`mise run stack:up` first, in the background with
`docker compose up --detach --wait`). They need Docker and are not part of
`mise run check`.
