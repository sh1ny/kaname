# CI run on the pull request (task 8.2)

PR: https://github.com/sh1ny/kaname/pull/7, head `cba260f8fcf949840b4df1675f64ecdcfe8298f7`.
Read through the fenced KintsugiBot credential (`as.sh KintsugiBot`); output
below is verbatim. Every job, `server` and `stack` included, concluded
`success`; `server` and `stack` ran on `ubuntu-24.04` only.

The first run, on `2517e24`, failed `check (windows)` in
`dockerfile_test.dart` (a `\`-separated path); `cba260f` fixed it and this
run is the result.

```text
$ gh api repos/sh1ny/kaname/actions/runs/43731560566 --jq "{url: .html_url, head_sha, event, conclusion}"
{"conclusion":"success","event":"pull_request","head_sha":"cba260f8fcf949840b4df1675f64ecdcfe8298f7","url":"https://github.com/sh1ny/kaname/actions/runs/43731560566"}

$ gh api repos/sh1ny/kaname/actions/runs/43731560566/jobs --jq ".jobs[] | [.name, (.labels|join(\",\")), .conclusion] | @tsv" | sort
build (android)	ubuntu-24.04	success
build (ios)	macos-15	success
build (linux)	ubuntu-24.04	success
build (macos)	macos-15	success
build (web)	ubuntu-24.04	success
build (windows)	windows-2025	success
check (linux)	ubuntu-24.04	success
check (macos)	macos-15	success
check (windows)	windows-2025	success
licences	ubuntu-24.04	success
server	ubuntu-24.04	success
signoff	ubuntu-24.04	success
spec	ubuntu-24.04	success
stack	ubuntu-24.04	success
```
