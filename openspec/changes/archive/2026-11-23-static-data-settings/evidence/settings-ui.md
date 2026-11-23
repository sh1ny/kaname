# Static data Settings: live stack evidence

Captured on 2026-11-23 in Chromium at a 390 × 1080 CSS-pixel viewport, using the
release WebAssembly build and local Compose stack (`mise run stack:up`). The
isolated database was seeded with CCP build `3714173`; the stack fetched build
`3720952` from CCP. Themes were selected through Appearance. The unavailable
screens were captured after stopping only the API container, with Caddy still
serving the app and a bundle retained on the device.

| Surface | Light | Dark |
|---|---|---|
| Settings: connected, bundle in use | [PNG](settings-connected-light.png) | [PNG](settings-connected-dark.png) |
| Settings: work in progress | [PNG](settings-busy-light.png) (start-up import) | [PNG](settings-busy-dark.png) (admin update being followed) |
| Settings: accepted admin session | [PNG](settings-admin-light.png) | [PNG](settings-admin-dark.png) |
| Settings: server status unavailable, cached bundle retained | [PNG](settings-unavailable-light.png) | [PNG](settings-unavailable-dark.png) |
| Change report: both builds and per-file counts | [PNG](report-light.png) | [PNG](report-dark.png) |

The Settings link changed the real browser URL to `/settings/static-data/report`.
Browser Back returned to `/settings`. Loading the report directly and pressing
**Back to Settings** also returned to `/settings`.

## Admin action log

From the same container, after pressing **Roll back** and then **Update now** in
Settings. The excerpts are the server's timestamp and message fields:

```text
2026-11-23T13:40:53.886599Z static data: rollback 9d8f66c2-4c34-4eb0-9962-9c4791586745 settled rolledBack
2026-11-23T13:41:05.242945Z worker "compute": switched to build 3720952 (replaced 3714173)
2026-11-23T13:41:05.263617Z static data: updateNow c0b09cc5-0295-4fb5-8829-cc9450c5cb1a settled switched
```

The operation rows ended as `rolledBack` to `3714173` and `switched` to `3720952`.
A fixed-string search of the complete API container stdout and stderr captured
after both actions found no occurrence of the ephemeral admin key. The key was
not printed by the check. The Compose smoke test separately verified
`adminConfigured` is true with a key and false without one.

This evidence does not mark the owner's visual sign-off (task 12.5).
