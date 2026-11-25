# Kaname (要)

Kaname ("linchpin") is an open-source EVE Online corporation and alliance suite: one Flutter app for web, desktop and mobile, backed by Serverpod, with a personal console for every pilot.

**Status:** M0 (walking skeleton) and M1 (static data pipeline) are complete;
M2 (ESI platform and SSO) is in progress. The app has a responsive shell,
static-data settings and offline type/system search, backed by the
[self-host stack](deploy/README.md). The generated ESI client, shared request
scheduler, privacy-scoped server call history and encrypted token vault are
implemented; product sign-in and server/device token handoff remain in
`esi-sso`. See the [roadmap](openspec/roadmap.md) for milestone scope.

## Development

Use the Linux toolchain through mise. Development is WSL-first; a separate Windows clone builds and runs the Windows desktop app.

```sh
mise install          # install the pinned Flutter, Dart, Node and OpenSpec
mise run resolve      # resolve the pub workspace into the root pubspec.lock
mise run check        # analysis, format, tests, workspace, purity and notices checks
```

`mise tasks` lists the individual tasks (`analyze`, `format:check`, `test`, `notices`, `build:web`, `spec:validate` and others).

The repository is one pub workspace:

| Path | Package | Kind |
|---|---|---|
| `app/` | `kaname_app` | Flutter app for web, Windows, Linux, macOS, Android and iOS |
| `packages/kaname_<name>/` | `kaname_core`, … | Pure-Dart shared packages: no Flutter or Serverpod |
| `app_packages/kaname_<name>/` | `kaname_ember_ui` | Shared Flutter UI and Ember themes |
| `server/kaname_server/` | `kaname_server` | Serverpod server, ESI runtime and static-data workers |
| `server/kaname_client/` | `kaname_client` | Generated Serverpod client and client-side stack tests |
| `tools/kaname_<name>/` | `kaname_tools` | Repository checks and the notices generator |
| `spikes/kaname_<name>/` | `kaname_grid_spike` | Disposable harnesses outside the product (not purity-checked) |

Read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing (no-copy rule, EULA boundary, DCO sign-off) and report vulnerabilities as [SECURITY.md](SECURITY.md) describes. Agent instructions are in [AGENTS.md](AGENTS.md); UI guidance is in [DESIGN.md](DESIGN.md).

For ESI work, use the generated client from the server's `ServerEsiRuntime` or
`NativeEsiRuntime.solo`; product modules do not open ESI connections directly.
Bind the caller's priority and validated authorization, and pass an ETag only
while retaining its matching representation. Scheduler refusals are not ESI
responses. The scheduler does not replay application calls.

`mise run test:esi_scheduler` covers solo policy and loopback HTTP;
`mise run test:server` also exercises the scheduler with real development
Redis and independent isolates. Neither needs EVE credentials.

## Licence and attribution

Kaname is licensed under [AGPL-3.0](LICENSE). Vendored tooling skills retain their own licences, recorded in [.claude/skills/UPSTREAM.json](.claude/skills/UPSTREAM.json). In particular, the unmodified Serverpod skills are a separate SSPL-licensed aggregate, not AGPL; their package licence and repository copyright notice are included. Bundled fonts retain their [SIL OFL notices](brand/fonts/OFL-NOTICE.md). [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) lists every bundled asset and pub dependency with its licence.

Kaname is not affiliated with or endorsed by CCP Games. EVE Online and its assets are the property of CCP Games and are used under CCP's developer licence.
