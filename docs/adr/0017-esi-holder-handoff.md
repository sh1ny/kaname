# 0017. ESI holder handoff and desktop credential storage

- Status: accepted (2026-11-25)
- Date: 2026-11-25
- Supersedes: none; applies ADR 0005 to installs that coordinate an ESI handoff.
- Chosen by: agent for the mechanism; owner for lost-device recovery (`esi-sso` S5, D4 and D5).

## Decision

The source stops admitting calls, drains admitted work and durably parks its credential before the destination activates. Each destination obtains a fresh grant using its own CCP registration. It never receives the other holder's CCP credential. The server fences the assignment by generation and a digest of the original device's proof. A known device assignment blocks ordinary server sign-in from enabling server ESI. An unrelated offline installation cannot observe this assignment until it joins the protocol.

The in-process gate covers only its calling runtime. M2 allows authenticated server ESI dispatch only through the main isolate's gate. A worker or second server process must not bypass it. Revisit dispatch coordination before enabling either.

Desktop keeps an exclusively held SQLite database for encrypted ESI credentials, the narrow ESI policy and the holder journal. OS secure storage holds the install key and device proof. Without those keys an existing vault cannot dispatch or release an assignment. This does not choose the general solo store or the shared native client ID.

## Recovery

A timeout, lost device or restored backup does not prove that the source stopped. M2 keeps the server blocked until the original device proves it parked. A transfer interrupted after assignment can resume or return on that device. Verified reclaim belongs to [M7 Solo to join](../../openspec/roadmap.md).

Before enabling ESI on a restored server, operators must stop ESI dispatch on linked devices and resolve their assignments. A restored row or missing holder record cannot prove that another holder stopped.
