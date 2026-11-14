# Contributing to Kaname

Thank you for helping. Kaname is an open-source EVE Online corporation and alliance suite under the [AGPL-3.0](LICENSE). Every contribution must meet the rules below: they keep the code our own and the project inside CCP's developer licence and the EVE Online EULA.

Report security problems privately, as [SECURITY.md](SECURITY.md) describes, not in an issue or a pull request.

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

then force-push your branch (`git push --force-with-lease`). Pull requests with unsigned commits are not merged. There is no automated sign-off check yet: reviewers check it by hand until CI adds one.

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

The repository is one pub workspace: the Flutter app in `app/`, pure-Dart shared packages in `packages/kaname_<name>/`, shared Flutter packages in `app_packages/kaname_<name>/`, tooling in `tools/kaname_<name>/`. Packages under `packages/` and `tools/` must not depend on Flutter or Serverpod.

## Branches and pull requests

1. Fork the repository (or branch, if you have access) from `main`; `main` is protected.
2. Keep each pull request to one change, with signed-off commits.
3. Open the pull request against `main` and fill in its checklist: the no-copy rule, the EULA boundary and the DCO sign-off.
4. A maintainer reviews it. The owner merges; nobody else merges into `main`.
