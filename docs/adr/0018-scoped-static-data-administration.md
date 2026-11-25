# 0018. Scoped static-data administration

- Status: accepted (2026-11-25)
- Date: 2026-11-25
- Supersedes: [ADR 0015](0015-interim-install-admin-key.md).
- Chosen by: user for the cutover; agent for the session mechanism (`esi-sso` S4 and D2).

## Decision

Static-data mutations require a live Kaname session with admin scope. The server maps a CCP-verified character and its verified owner to a Kaname identity. It derives admin scope from the operator allowlist and the current identity, not the client's claims or the character's ESI scopes. Revoked sessions and blocked identities cannot authorize a mutation.

Status, operation and report reads stay public. The app uses the current session to decide whether to show mutation controls, but the server checks authority on each mutation. The existing job, revision and recovery guards still apply. Losing session authority does not cancel an admitted job.

Remove the install-wide key, its settings and the wrong-key pause. Authenticated traffic requires HTTPS outside the explicitly enabled local stack at `http://localhost/`. A remote HTTP connection remains usable for public reads only.
