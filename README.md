# Kaname (要)

Kaname ("linchpin") is an open-source EVE Online corporation and alliance suite: one Flutter app for web, desktop and mobile, backed by Serverpod, with a personal console for every pilot.

**Status:** M0, walking skeleton. The pub workspace, a placeholder app and the repository checks exist; there are no product features yet.

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
| `app_packages/kaname_<name>/` | (none yet) | Shared Flutter packages |
| `server/` | (none yet) | Serverpod server and client |
| `tools/kaname_<name>/` | `kaname_tools` | Repository checks and the notices generator |

Read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing (no-copy rule, EULA boundary, DCO sign-off) and report vulnerabilities as [SECURITY.md](SECURITY.md) describes. Agent instructions are in [AGENTS.md](AGENTS.md); UI guidance is in [DESIGN.md](DESIGN.md).

## Licence and attribution

Kaname is licensed under [AGPL-3.0](LICENSE). Vendored tooling skills retain their own licences, recorded in [.claude/skills/UPSTREAM.json](.claude/skills/UPSTREAM.json). In particular, the unmodified Serverpod skills are a separate SSPL-licensed aggregate, not AGPL; their package licence and repository copyright notice are included. Bundled fonts retain their [SIL OFL notices](brand/fonts/OFL-NOTICE.md). [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) lists every bundled asset and pub dependency with its licence.

Kaname is not affiliated with or endorsed by CCP Games. EVE Online and its assets are the property of CCP Games and are used under CCP's developer licence.
