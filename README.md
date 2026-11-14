# Kaname (要)

Kaname ("linchpin") is an open-source EVE Online corporation and alliance suite: one Flutter app for web, desktop and mobile, backed by Serverpod, with a personal console for every pilot.

**Status:** planning. This repository currently contains tooling, agent configuration and the Ember design system, not a working application.

## Development

Use the Linux toolchain through mise: `mise install`, then `mise run spec:validate` or `mise run spec:list`. Development is WSL-first; a separate Windows clone builds and runs the Windows desktop app. Agent instructions are in [AGENTS.md](AGENTS.md); UI guidance is in [DESIGN.md](DESIGN.md).

## Licence and attribution

Kaname is licensed under [AGPL-3.0](LICENSE). Vendored tooling skills retain their own licences, recorded in [.claude/skills/UPSTREAM.json](.claude/skills/UPSTREAM.json). In particular, the unmodified Serverpod skills are a separate SSPL-licensed aggregate, not AGPL; their package licence and repository copyright notice are included. Bundled fonts retain their [SIL OFL notices](brand/fonts/OFL-NOTICE.md).

Kaname is not affiliated with or endorsed by CCP Games. EVE Online and its assets are the property of CCP Games and are used under CCP's developer licence.
