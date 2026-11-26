## Summary

<!-- What changed and why, in two or three sentences. Add screenshots for UI changes. -->

## Linked

<!-- "Fixes #123", an openspec/changes/<name> path, or "none". -->

## Testing

<!-- The commands you ran and what passed. If you couldn't test something, say what and why. -->

## Review focus

<!-- Optional: the files or areas to look at first. -->

## Risk

<!-- Optional: tick any that apply. -->

- [ ] Changes permissions or agent tool lists
- [ ] Changes CI workflows
- [ ] Changes migrations or stored data
- [ ] Deletes files
- [ ] Changes a public API, CLI or protocol
- [ ] Changes network access, sensitive data handling or security defaults

## Skip

<!-- Optional: generated or vendored files reviewers can skip. -->

## User-visible changes

<!-- Optional: what changes for users (renamed commands, settings, version pins), and the docs you updated, or why none needed it. -->

## Project checks

See [CONTRIBUTING.md](https://github.com/sh1ny/kaname/blob/main/CONTRIBUTING.md) for each rule.

- [ ] **No-copy rule:** this change copies no third-party product code, schemas or templates; any copied data file was approved and is listed in THIRD_PARTY_NOTICES.
- [ ] **EULA boundary:** this change adds no input broadcasting, synthetic input, focus cycling on keys, memory reading, screen capture or OCR of the client, packet inspection or global keyboard hooks.
- [ ] **DCO sign-off:** every commit has a `Signed-off-by` line matching its author (`git commit -s`).
