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
