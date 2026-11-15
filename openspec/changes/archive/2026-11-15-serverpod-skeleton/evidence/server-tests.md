# Server tests from a fresh clone (task 3.6)

Linux (WSL Ubuntu), toolchain through mise. The group's work was uncommitted
when this was captured, so the fresh clone was simulated: `git clone` of the
repository (branch `feat/serverpod-skeleton`, group 2 commit), then the working
tree changes copied in (`git diff HEAD` applied with `git apply`, plus the
untracked files listed by `git ls-files -o --exclude-standard`). The ignored
secret files were never copied; the clone generated its own. The main
checkout's development Redis was stopped first, since only one runs at a time
(the Compose project name was the directory's, `kaname_server`, so no `-p`).

## Setup, Redis, tests

```text
$ mise run resolve
Got dependencies!
$ mise run server:setup
[server:setup] $ dart run tool/setup.dart
Created config/passwords.yaml and wrote .env.
$ (cd server/kaname_server && docker compose up -d)
 Container kaname_server-redis-1 Started
$ docker inspect -f '{{.State.Health.Status}}' kaname_server-redis-1
healthy
$ mise run test:server        # exit 0
[test:server:server] $ dart test --exclude-tags stack
00:00 +6: All tests passed!
[test:server:client] $ dart test --exclude-tags stack
00:00 +1: All tests passed!
```

## Planted failing test

`server/kaname_server/test/unit/planted_test.dart` with
`test('planted failure', () => expect(1, 2))`:

```text
$ mise run test:server        # exit 1
[test:server:server] $ dart test --exclude-tags stack
00:00 +0 -1: test/unit/planted_test.dart: planted failure [E]
  test/unit/planted_test.dart 4:33  main.<fn>
00:00 +6 -1: Some tests failed.
  test/unit/planted_test.dart: planted failure
[test:server:server] ERROR task failed
```

## Setup again, nothing secret in git status

The plant was removed, then `mise run server:setup` ran again:

```text
Kept config/passwords.yaml and rewrote .env.
```

`config/passwords.yaml` was byte-identical to before (`cmp`). `git status
--short` listed only the group's own files (modified `mise.toml`, pubspecs,
configs, README; new tests, tool and Compose file) and neither
`server/kaname_server/config/passwords.yaml` nor `server/kaname_server/.env`;
`git status --short --ignored` shows both as ignored (`!!`).

The clone's Redis was stopped with `docker compose down` and the clone deleted.
