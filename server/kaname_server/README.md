# kaname_server

Kaname's Serverpod server. The Serverpod CLI is a dev dependency of this
package; run it from this directory through mise:

    mise exec -C server/kaname_server -- dart run serverpod_cli <command>

## Development Redis and tests

Development and test run modes need Redis. Create the ignored secrets, then
start the Redis container:

    mise run server:setup
    docker compose up -d   # in server/kaname_server

`mise run server:setup` writes `config/passwords.yaml` once (it never
overwrites it) and derives the ignored `.env` for Compose from it. Then
`mise run test:server` runs the server packages' tests; it starts nothing.

Only one checkout at a time runs the development Redis: the Compose project is
named after the directory, so two checkouts share one container and port 8091.

## ESI call log

The server runtime stores ESI outcomes in PostgreSQL through a separate,
bounded write path. Storage failures do not change ESI results or replay
requests. `esi-call-log: append failed` means some diagnostic rows may be
missing. The log records catalogue routes and buckets, not expanded URLs,
credentials, headers, payloads, or exceptions. Not-sent refusals are not errors.

Reads exclude rows at the seven-day UTC cutoff, even before the recurring
prune runs. The trusted server viewer sees only their calls for characters they
currently own. Admins get route totals and error counts for five complete UTC
days, released at 00:01 UTC. Private routes require at least five distinct
members; unattributed private calls are excluded. There is no client RPC until
`esi-sso` can supply validated viewer identity.
