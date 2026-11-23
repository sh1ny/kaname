## ADDED Requirements

### Requirement: The stack's server trusts only Caddy as proxy
The stack SHALL run its internal network on a fixed subnet whose dynamic address range excludes Caddy's fixed IPv4 address, and SHALL pass Caddy's address, and nothing else, to the server as its trusted proxies, so that the server identifies each client by the address Caddy forwards. Caddy SHALL NOT trust any forwarded-address header sent to it by a client. The deploy guide SHALL require any proxy an operator trusts to append the address it received the connection from.

#### Scenario: Two clients through Caddy
- **WHEN** a client on the stack host, reaching Caddy through the loopback port, holds 16 open announcement streams, and a client in a container on the stack's internal network, with its own address, subscribes through Caddy
- **THEN** the second client's subscription is admitted and receives the current announcement, because the server counts each client for its own address and never for Caddy's

#### Scenario: Client sends its own forwarded header
- **WHEN** a client on the stack host opens 17 announcement streams through Caddy, each on its own WebSocket connection whose upgrade request sends a different `X-Forwarded-For` value
- **THEN** the first 16 receive the current announcement and are still open after the refusal, the 17th completes normally with no event and no error, and a client in a container on the stack network still receives the announcement, because Caddy replaces the client's header and the server counts every stream for the address the connection to Caddy came from

#### Scenario: Configuration check
- **WHEN** the stack's Compose configuration is checked
- **THEN** the internal network has a fixed subnet and a dynamic address range inside it, Caddy has a fixed IPv4 address in the subnet but outside that range, and the server's `KANAME_TRUSTED_PROXIES` is exactly Caddy's address

#### Scenario: Local client through Docker's gateway
- **WHEN** a browser on the stack host reaches Caddy through the loopback port, and the connection arrives from the network's gateway address
- **THEN** the server counts the browser's streams for the gateway's address and logs no warning about the forwarded header
