# Stack proof: the web app reaches the server through /api/ (D8, A2)

Recorded on 2026-11-17 at commit 34dfd3d on `feat/app-shell`, in WSL Ubuntu with Docker.

## Commands

1. `deploy/.env` created from `deploy/.env.example` with fresh random values (not committed; deleted afterwards).
2. `mise run stack:up`: built the web app (`build:web`, including `webbuild:check`), then `docker compose --file deploy/compose.yaml up --detach --wait --build`. Exit 0; postgres, redis, server and caddy reported Healthy, migrate Exited (done).
3. Opened `http://127.0.0.1/settings` directly, as a fresh page load, in Orca's built-in browser (Chromium), with network capture on and a 1280x800 viewport.
4. Read the rendered text from Flutter's semantics tree (accessibility enabled on the page), because the browser window was hidden and could not take screenshots.
5. `mise run stack:down` afterwards.

## Request seen by the browser

| Method | URL | Status |
|---|---|---|
| GET | `http://127.0.0.1/settings` | 200 (text/html, Caddy's single-page-app fallback) |
| POST | `http://127.0.0.1/api/health/check` | 200 (application/json) |

The health request goes to `/api/` on the page's own origin and returns. The Serverpod web client needed no other host form (A2 holds).

## Text shown

- Status bar: "Server connected".
- Settings → Server: Version "0.1.0", Postgres "Up", Redis "Up", and the "Check again" button.
- Settings → Appearance: Theme, with the options System, Dark and Light.
- Settings → About: Version "0.0.1+1", Licences "View licences".
- Frame: "Kaname", "Open inspector", the main navigation (Home, Personal, Organisation, Settings) with Settings selected.

## Deep link

Loading `/settings` as the first request served `index.html` with 200, and the app opened on the Settings destination inside the shell (path URLs, D2).
