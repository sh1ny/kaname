# Contributing to Kaname

Thank you for helping. Kaname is an open-source EVE Online corporation and alliance suite under the [AGPL-3.0](LICENSE). Every contribution must meet the rules below: they keep the code our own and the project inside CCP's developer licence and the EVE Online EULA.

Report security problems privately, as [SECURITY.md](SECURITY.md) describes, not in an issue or a pull request.

## Ways to help

- **Report a bug or suggest an idea.** Open an [issue](https://github.com/sh1ny/kaname/issues/new/choose). The forms say what helps; only the first box is required.
- **Fix something small** (a typo, a doc, an obvious bug): send a pull request straight away, with signed-off commits.
- **Anything bigger** (a new feature, a new dependency, a server or protocol change): open an issue first, so we can agree on the approach before you spend time on it.

## How the project is planned

Maintainers plan work with [OpenSpec](https://github.com/Fission-AI/OpenSpec) and [Specwright](https://github.com/sh1ny/specwright): milestones live in [`openspec/roadmap.md`](openspec/roadmap.md) and each larger change gets a folder under `openspec/changes/`. You don't need either tool to contribute. If your change is larger, a maintainer may write it up as an OpenSpec change and ask you a question or two. Please don't edit `openspec/changes/` in your pull request unless you're asked to.

Much of the maintainers' own work is done with AI coding agents, and an automated reviewer may comment on your pull request. A person makes every decision. AI-assisted contributions are welcome too, as long as you understand and have tested what you send, and they follow the no-copy rule below like any other change.

## No-copy rule (clean room)

Kaname is built from concepts, never from other products' implementations ([ADR 0002](docs/adr/0002-licence-clean-room-and-eula-boundary.md)).

- Do not copy third-party product code, schemas or templates into Kaname, in whole or in part, and do not translate them line by line from another language. Describe the behaviour you want and write it yourself.
- A pinned, unmodified, credited dependency is use, not copying: adding a package through `pubspec.yaml` is fine, subject to its licence being compatible with the AGPL-3.0.
- Copying any data file (for example a static data export or a lookup table) needs the owner's approval first, in an issue, and a licence notice in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
- Code adapted from the owner's own projects carries a provenance note (a comment or the commit message naming the source project).

A pull request that copies code, a schema or a template from another product is declined, however useful the change. If you are unsure whether something counts as copying, ask in the pull request before writing it.

## EULA boundary

Kaname runs next to the EVE client and must never automate it. Desktop integration only:

- reads game and chat log files, and
- moves or resizes windows.

These techniques are never accepted, in any form:

- input broadcasting (sending one input to several clients);
- synthetic input (simulated keystrokes, clicks or mouse movement);
- focus cycling on keys;
- memory reading of the client;
- screen capture or OCR of the client;
- packet inspection;
- global keyboard hooks. Hotkeys work only while Kaname's own window is focused.

A feature that needs any of these is not accepted, whatever its configuration or default: an option that is off by default, hidden or "advanced" does not change the answer.

## Developer Certificate of Origin

Kaname uses the [Developer Certificate of Origin 1.1](https://developercertificate.org/) (DCO) instead of a contributor licence agreement. By signing off you certify that you wrote the change, or otherwise have the right to submit it under the project's licence, as the DCO text at that link sets out.

Every commit must carry a sign-off line that matches the commit author, in the final trailer block of the message:

```text
Signed-off-by: Your Name <you@example.com>
```

Git adds it for you with `git commit -s` (or `--signoff`). Use the same name and email as the commit author; a GitHub noreply address is fine.

If you forgot to sign off:

- for the last commit: `git commit --amend --signoff --no-edit`;
- for every commit on your branch: `git rebase --signoff main`;

then force-push your branch (`git push --force-with-lease`). Pull requests with unsigned commits are not merged.

CI checks every non-merge commit of a pull request in its `signoff` check, which fails and names each commit's short hash, subject and what is missing or mismatched. The check reads the `Signed-off-by` trailers the way git does and requires one that equals the commit author's `Name <email>`. You can run the same check on your branch before you push, with your upstream remote's `main` as the base (there is no default base, because the right one depends on your remote):

```sh
mise run signoff -- --base <upstream remote>/main
```

The only exemption is Dependabot's own commits: a commit whose author is exactly `dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>`, in a pull request opened by `dependabot[bot]`, is skipped and listed as skipped. The same identity in a pull request opened by anyone else is checked like any other commit.

## Toolchain

Development happens on Linux (WSL on Windows is the primary setup). Install [mise](https://mise.jdx.dev/) 2026.11.1 or newer (`mise.toml` sets this `min_version`, the oldest mise that reads the committed `mise.lock`) and let it provide the pinned Flutter, Dart, Java (Temurin 17) and Node versions; never use a Flutter, Dart or JDK from elsewhere on your `PATH`. A local Android build also needs an Android SDK, which mise does not install; CI uses the one on its Ubuntu runner.

```sh
mise install          # install the pinned toolchain
mise run resolve      # resolve the pub workspace (one root pubspec.lock)
mise run check        # analysis, format, tests, workspace, purity and notices checks
```

`mise.lock` records the checksum of every tool download for Linux, Windows and macOS, and CI installs only what it records. If you change a pin in `mise.toml`, regenerate the lockfile and the dependency-graph sidecars under `.mise/locks/` in the same commit:

```sh
mise lock --platform linux-x64,windows-x64,macos-arm64
mise install --force npm:@fission-ai/openspec   # once per npm: tool, to record its provenance pin
```

Commit `mise.toml`, `mise.lock` and `.mise/locks/` together.

Run `mise run check` before you push. If you change dependencies, run `mise run notices` to regenerate the dependency section of `THIRD_PARTY_NOTICES` and commit the result.

The repository is one pub workspace: the Flutter app in `app/`, pure-Dart shared packages in `packages/kaname_<name>/`, shared Flutter packages in `app_packages/kaname_<name>/`, tooling in `tools/kaname_<name>/`, and disposable spikes in `spikes/kaname_<name>/`, which nothing else may import. Packages under `packages/` and `tools/` must not depend on Flutter or Serverpod.

## Branches and pull requests

1. Fork the repository (or branch, if you have access) from `main`; `main` is protected.
2. Keep each pull request to one change, with signed-off commits.
3. Open the pull request against `main` and fill in the template: a short **Summary**, what it's **Linked** to, how you **tested** it, and the three **Project checks** (no-copy rule, EULA boundary, DCO sign-off). The other sections are optional.
4. A maintainer reviews it. The owner merges; nobody else merges into `main`.

Tests must never fail because a machine is slow: wait for an event or a result, never sleep for a fixed time.
