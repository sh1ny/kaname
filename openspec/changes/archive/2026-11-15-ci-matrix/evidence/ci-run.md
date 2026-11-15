# Evidence: this change's pull request CI run (task 6.2)

- Pull request: https://github.com/sh1ny/kaname/pull/4
- Run: https://github.com/sh1ny/kaname/actions/runs/43659239596 (event `pull_request`, conclusion `success`)
- Head: `45fae585f0f173e164374ad0df91845bb14b8a62`
- Read on 2026-11-15 with `gh run view 43659239596 --repo sh1ny/kaname --json jobs` and `gh api repos/sh1ny/kaname/actions/runs/43659239596/jobs`, through the fenced KintsugiBot credential.

## Jobs

| Job | Runner label | Conclusion | Started (UTC) | Completed (UTC) |
|---|---|---|---|---|
| `build (android)` | `ubuntu-24.04` | success | 00:39:33Z | 00:42:51Z |
| `build (ios)` | `macos-15` | success | 00:39:34Z | 00:42:26Z |
| `build (linux)` | `ubuntu-24.04` | success | 00:39:34Z | 00:41:31Z |
| `build (macos)` | `macos-15` | success | 00:39:33Z | 00:42:23Z |
| `build (web)` | `ubuntu-24.04` | success | 00:39:33Z | 00:40:48Z |
| `build (windows)` | `windows-2025` | success | 00:39:34Z | 00:44:07Z |
| `check (linux)` | `ubuntu-24.04` | success | 00:39:33Z | 00:40:45Z |
| `check (macos)` | `macos-15` | success | 00:39:33Z | 00:41:24Z |
| `check (windows)` | `windows-2025` | success | 00:39:32Z | 00:43:06Z |
| `licences` | `ubuntu-24.04` | success | 00:39:33Z | 00:40:45Z |
| `signoff` | `ubuntu-24.04` | success | 00:39:33Z | 00:40:24Z |
| `spec` | `ubuntu-24.04` | success | 00:39:33Z | 00:40:11Z |

All twelve jobs concluded `success`. The longest was `build (windows)` at about 4.5 minutes, so no job approaches its timeout. `build (android)` took about 3.3 minutes.

## iOS build without signing

From the `build (ios)` job log:

```text
Run mise exec -- flutter build ios --release --no-codesign
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Building io.github.sh1ny.kaname for device (ios-release)...
✓ Built build/ios/iphoneos/Runner.app (14.1MB)
```

## SBOM artifact

From `gh api repos/sh1ny/kaname/actions/runs/43659239596/artifacts`:

| Name | Size (bytes, zipped) | Expires | Expired |
|---|---|---|---|
| `sbom-cyclonedx` | 4498 | 2027-02-13T00:39:14Z | false |

The expiry is 90 days after the run started, matching `retention-days: 90`.

## Superseded run

Head `21a6ce5` (run 43659168740) was `cancelled` when `45fae58` was pushed 53 seconds later. This is the workflow's `concurrency` group with `cancel-in-progress: true`.

## Earlier failure on this pull request

The first run (43658427848, head `9c4f6d9`) failed only in `signoff`: the job ran `dart run kaname_tools` before `mise run resolve`. This was fixed in `21a6ce5` (`fix(ci): resolve the workspace before the signoff check`), with a structure test that requires `mise run resolve` before any kaname_tools task in every job.
