# Self-host stack

One Docker Compose file runs the whole Kaname stack: `postgres` (16), `redis`
(8), the `server`, and `caddy`, plus a one-shot `migrate` step that applies the
database migrations before the server starts. Caddy serves the web app at `/`,
routes `/api/` to the server with the prefix removed, and passes `/livez`,
`/readyz` and `/v1/websocket` through unchanged. The generated client always
opens its WebSocket at `/v1/websocket` on the origin, whatever path the app's
API is configured under, and the static-data announcements arrive over it; a
proxy in front of the server must forward that path unchanged, or apps never
learn of a new bundle while every HTTP route still works. Locally the stack serves plain HTTP at `http://localhost/`,
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

To enable static-data admin actions, set the optional `KANAME_ADMIN_KEY` to
a random value of at least 32 characters. With no key, or with a shorter key,
admin actions stay disabled and the public status remains readable. Compose
passes the key to the server only as `SERVERPOD_PASSWORD_adminKey`; the image
and migration service do not receive it. Do not enable it on a non-loopback
deployment until a TLS reverse proxy is in front of the stack. The app only
offers key entry over HTTPS or loopback HTTP and keeps the key in memory until
the app closes or reloads (ADR 0015).

```sh
mise run stack:down                     # stop and delete the data volumes
(cd deploy && docker compose down)     # stop, keep the data
```

`docker compose down` keeps the named volumes `pgdata` and `redisdata`, so the
next `up` starts on the existing database and applies no migration twice.
`mise run stack:down` removes them as well.

## Clients and proxies

The server holds at most 16 open announcement streams per client, and 2,000
in all. A client is the address its connection comes from; IPv6 clients in
the same `/64` count as one. A refused subscription ends at once with no
event, and the app tries again later.

When a connection comes from a trusted proxy, the server takes the client's
address from the proxy's `X-Forwarded-For` header instead: the rightmost
address in it that is not itself a trusted proxy. The server's
`KANAME_TRUSTED_PROXIES` setting lists the trusted proxies, as IP addresses
and CIDR ranges separated by commas. Unset or empty trusts nobody, and an
invalid entry stops the server at start-up, naming the entry.

### The shipped stack

`compose.yaml` pins the stack's internal network to `172.30.0.0/24`, with
gateway `172.30.0.1`, and lets Docker hand out addresses only from
`172.30.0.128/25`. Caddy has the fixed address `172.30.0.10`, outside that
range, and the server trusts exactly that address. Caddy replaces any
`X-Forwarded-For` a client sends with the address the connection came from,
so a client cannot choose its own bucket.

Locally, the stack publishes Caddy on `127.0.0.1` only. A browser on the
stack host reaches Caddy through Docker's gateway, so all local clients count
as one client, the gateway's address. That is expected for a loopback stack.

If `172.30.0.0/24` overlaps a network you already use (another Docker
network, a VPN), change the subnet, the gateway, the dynamic range, Caddy's
`ipv4_address` and `KANAME_TRUSTED_PROXIES` together. Caddy's address must
stay inside the subnet and outside the dynamic range, and the server must
trust only that address, never the whole subnet.

A stack started before the subnet was pinned keeps its old network until the
network is recreated. Run `(cd deploy && docker compose down)`, which keeps
the data volumes, then start the stack again. Do not use `mise run
stack:down` for this: it deletes the database.

### A public deployment

Caddy is meant to be the edge of a public deployment: the client's
connection reaches it directly, and it writes the real client address. A
proxy, CDN or tunnel you put in front of Caddy changes that. Caddy then sees
the front proxy as every client's address, and every user shares one bucket
of 16 streams, unless you configure both trust lists:

1. The front proxy must append the address it received the connection from
   to `X-Forwarded-For`. A proxy that passes a caller's header through
   unchanged lets the caller choose its bucket; never trust one.
2. The front proxy must reach Caddy over a route Caddy can tell apart from
   other callers: give it a fixed address on the stack network, outside the
   dynamic range and distinct from Caddy's and the gateway's. A separate
   Caddy port is not enough, because Caddy's trust list applies to every
   listener. Never trust the Docker gateway: it would trust every local
   caller.
3. Add the front proxy's address to Caddy's `trusted_proxies` and to
   `KANAME_TRUSTED_PROXIES`, beside Caddy's address. The server then reads
   the chain `client, front proxy` and counts the client.

Check the route twice, in this order, and again after any change to the
network or the addresses:

- **Before trusting the front proxy**, check that Caddy sees the proxy's own
  address as its peer, not the Docker gateway's.
- **With both trust lists set, before the route goes public**, check end to
  end: after one real client fills its 16 places through the front proxy, a
  second client still receives announcements, and a forwarded header sent by
  either client changes neither client's bucket.

The project ships no such topology, so these checks are yours.

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

Open **Settings → Static data** to see the bundle this device is using, the
builds on the server and the latest check, import and switch. **View change
report** compares the active and previous builds. Record counts cover the
whole comparison; a cut-off mark means some record keys are not shown.

With a session admin key, **Update now** asks the server to check for a newer
build. Turn **Auto-update** off to stage a newer build without switching.
**Roll back** switches to the previous build after confirmation and holds the
build it replaced so it is not immediately reactivated.

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
