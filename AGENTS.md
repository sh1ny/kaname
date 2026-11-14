# Kaname: agent instructions

Kaname (要, "linchpin") is an open-source EVE Online corporation/alliance suite: one Flutter app for web, desktop and mobile, backed by Serverpod 4.1, with a personal console for every pilot. Licence: AGPL-3.0, except separately licensed vendored assets. Status: M0 (walking skeleton). The root pub workspace holds `app/` (placeholder screen), `packages/kaname_core/` and `tools/kaname_tools/`; strategy, architecture and roadmap are in `openspec/`. No product features yet.

These instructions apply to Claude Code and OMP. Claude plans; OMP implements and launches Claude for cross-model review. This project does not install Codex skills or agents.

## Environment and tools

- Primary development and tests run in WSL Ubuntu on the Linux filesystem. A separate Windows clone is only for building/running the Windows desktop app; it receives commits through GitHub. Never edit or synchronize that clone from WSL tooling.
- `mise.toml` pins Flutter 3.47.9 (Dart 3.13.7), Node 24 and OpenSpec 1.16.0. Run `mise install`, then always `mise exec -- <command>` or `mise run <task>`. Check `mise exec -- which <tool>` is a Linux path: WSL's inherited PATH can silently select Windows tools.
- Tasks: `mise run resolve` (workspace `pub get`), then `mise run check` (workspace, purity, analyze, format:check, test, notices:check; stops at the first failure). Also `analyze`, `format:check`, `test`, `notices` (regenerate THIRD_PARTY_NOTICES after any dependency change), `build:web`, `spec:validate` (all, strict) and `spec:list`; `mise tasks` lists them. Package-local `serverpod_cli` arrives with `serverpod-skeleton`, never globally installed.
- `.mcp.json` and `.omp/mcp.json` configure Dart (`dart mcp-server --enable cli --enable flutter_app_lifecycle`) and Context7 (`npx -y @upstash/context7-mcp`) through mise. Claude enables and allow-lists only these two servers in `.claude/settings.json`. Never commit an API key.
- Prefer Dart MCP for analysis, formatting, tests and package operations when available; otherwise run the equivalent through mise.
- Use `find-docs` and Context7 for current library/API/CLI documentation, not recalled API signatures.
- **TODO for M0:** add the Serverpod MCP entry and Claude enable/allow-list once the server package exists. Serverpod 4.1's MCP bridge resolves a package containing a `serverpod` dependency before opening stdio; no such package exists here yet. Run the CLI as a pinned server-package dev dependency, not a global tool.
- `.omp/config.yml` uses the exact shared Hindsight bank `coding-agent::kaname`, empty prefix, global scoping. Do not put credentials or third-party research in committed memory exports.

## Scope, safety and clean-room rules

- Every scope, design and project-planning decision goes to the owner: both `decision_making` and `project.decision_making` are `all`. Ask when unclear; never attribute an agent choice to the owner.
- Product development is clean-room: never copy third-party product code, schemas or templates. Licensed tooling skills and the owner's Ember kit are explicit exceptions for tooling/assets, not permission to copy product implementations.
- Never commit research about other products, comparisons or findings. Local-only notes belong outside tracked files or in paths excluded through `.git/info/exclude`, never research entries in `.gitignore`.
- This repository is public. Never commit tokens, passwords files, private endpoints or unnecessary machine paths. Vendored skills require redistribution permission, intact licence files and exact upstream provenance in `.claude/skills/UPSTREAM.json`.
- EVE desktop integration may **only read log files and move or resize windows**. No input broadcasting or synthetic input, no memory reading, no client screen capture, no global keyboard hooks.

## Dart and Flutter code

These rules also apply to delegated agents. Before planning specs/design/tasks or writing Dart, load matching skills from `.claude/skills/<name>/SKILL.md`; pass their names and paths plus this section in every implementer/reviewer packet.

- Always: `dart-use-pattern-matching`, `dart-write-documentation`, `dart-run-static-analysis`.
- Unit tests: `dart-add-unit-test`; Serverpod tests: `serverpod-testing`; widget/integration tests: `flutter-add-widget-test`, `flutter-add-integration-test`.
- Server: `serverpod-overview`, then the matching models, database, migrations, endpoints, auth, configuration, streams, scheduling, deployment, webserver and other `serverpod-*` skills.
- Flutter: `serverpod-flutter-frontend`, `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`; routing, localisation and JSON use `flutter-setup-declarative-routing`, `flutter-setup-localization`, `flutter-implement-json-serialization`.
- CLI, native assets and FFI: matching `dart-build-cli-app`, `dart-setup-ffi-assets`, `dart-use-ffigen` skills. All upstream Dart and Flutter skills are available; consult the manifest rather than assuming this list is exhaustive.
- Prefer sealed domain states and exhaustive switches. No `dynamic` in domain code: use `Map<String, Object?>` only at external edges, validate and convert to typed values, and surface invalid input explicitly.
- Keep state ownership explicit, domain logic independent of widgets, dependencies constructor-injected, and behavior tested at the cheapest complete layer. Prefer deterministic hand-written fakes; no mocking package by default.
- Read `codebase-design`, `domain-modeling` and `improve-codebase-architecture` for their matching design/refactoring work; use `unslop` for focused cleanup, not unrelated rewrites.

## UI and brand

- `DESIGN.md` is Kaname's impeccable-readable design system, derived from the owner's Ember kit. `brand/BRAND.md` preserves the kit; `brand/tokens.json` is its token source of truth.
- Read `impeccable` for UI work, together with the matching Flutter skills. Read `diagram-design` for structured diagrams. Preserve dark/light tokens, typography, spacing, accessibility and responsive behavior; record deliberate product deviations in DESIGN.md's "What Kaname changes" section.
- `brand/tools/build.mjs` regenerates CSS and Dart token files through `mise exec -- node brand/tools/build.mjs`. Keep bundled font licences and `brand/fonts/OFL-NOTICE.md`. Do not create an application theme until M0; the kit's existing Flutter helpers are assets, not a bootstrapped app.

## Specwright

- Specwright 0.34.0 is installed for Claude Code and OMP only: shared skills in `.claude/skills/`, harness-specific agents in `.claude/agents/` and `.omp/agents/`, schema in `openspec/schemas/specwright/`. Existing OpenSpec skills/commands remain in both harness directories.
- `openspec/config.yaml` contains the mandatory branch/apply/archive/finish hooks. Project planning is reserved for `specwright-roadmap`; setup does not start a change or write planning documents. Default future paths are `openspec/strategy.md`, `architecture.md`, `roadmap.md`, and `docs/adr/`.
- Settings are in `openspec/specwright.yaml`: Git PR finish, KintsugiBot, owner merge, `@codex review` requests posted as `sh1ny`, Claude-only cross-model design/pre-ship reviews, group commits, strict pre-push OpenSpec validation. No packs, external planning store, cheap tier or automatic releases.
- `[user]` tasks are checked only by the owner. `[evidence]` tasks require their nonempty committed evidence. Never archive a deferred review or unticked user task; follow the installed workflow guards.
- **specwright#170 workaround:** `.omp/agents/specwright-implementer.md` uses `model: pi/task`, not upstream `pi/smol`. The light implementer stays `pi/smol`; reviewer stays `pi/slow`. Re-apply/check after every Specwright update until #170 is fixed.
- **specwright#140 workaround:** both `.claude/agents/specwright-implementer*.md` include `ToolSearch, mcp__dart__*` in `tools:`. Updates overwrite tools; re-apply after every update until #140 is fixed.
- **OMP tool compatibility:** OMP agent headers use `glob` in place of the removed `find` tool. Re-apply after updates while upstream still names `find`.
- Native `sw` is local-only. mise sets `SPECWRIGHT_HOME` to `.specwright-local/`; the resolver then uses `.specwright-local/.specwright/bin/0.34.0/sw`. Start harnesses through mise so this environment reaches the resolver. The binary and its third-party notice are ignored, not committed.
- Setup built `sw` from the exact v0.34.0 source using its locked Dart dependencies and upstream build/install helpers, with owner approval: the published release had no assets and `sw-install` returned `assets_not_uploaded`. For another clone, follow the upstream README installer with the same targets; if assets are still unavailable, obtain owner approval for the documented CONTRIBUTING.md source bootstrap. Run all bootstrap commands through mise, preserving `SPECWRIGHT_HOME`, and use the pinned Dart 3.13.7.
- After install/update, start a fresh agent session before relying on changed skills or agent definitions. User-level Claude skills can override project copies; update or remove conflicting user-level copies only with owner authorization.

## Git and GitHub

- Use Git, never jj. `main` is protected: branch, push and open a PR; never force-push or bypass protections. Owner merges; **do not merge automatically**, even when reviewers approve.
- Commits explicitly set both author and committer to `Nikolay Bochev <309868+sh1ny@users.noreply.github.com>`. End the message after a blank line with one final trailer block: any `Specwright-*` trailers, then the owner's `Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>` line (Developer Certificate of Origin, see CONTRIBUTING.md), then exactly one `Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>` trailer. Write the `Signed-off-by` line explicitly in the message file; never use `git commit -s`, which appends it after `Co-authored-by`. KintsugiBot never signs off. Preserve other contributors' trailers.
- Every authenticated `gh` operation and `git push` uses KintsugiBot's process-scoped credential: in one disposable shell unset `GH_TOKEN` and `GITHUB_TOKEN`, privately capture `gh auth token --hostname github.com --user KintsugiBot`, export as `GH_TOKEN`, require `gh api --hostname github.com user --jq .login` equals `KintsugiBot`, then act in that process. For pushes, use gh's credential helper in that fenced process. Never print/store credentials or run `gh auth switch`.
- Codex reviews are requested with `@codex review`, posted as `sh1ny` through the same fenced credential pattern (Specwright posts it on ship). Review feedback: react +1 when accepted or -1 when rejected; explain with the quoted finding, fix commit and verification or evidence for rejection. Resolve only after reaction/reply are verified visible; leave waiting findings unresolved.
