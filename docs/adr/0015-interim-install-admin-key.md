# 0015. Interim install admin key

- Status: accepted (2026-11-23)
- Date: 2026-11-23
- Supersedes: none
- Chosen by: user (`static-data-settings` proposal S1, S8 and S9; design D1, D6, D12, D24 and D29)

## Decision

Use one install-wide key to authorize static-data admin calls until M2 adds sign-in and roles. The server reads the `adminKey` password from `SERVERPOD_PASSWORD_adminKey` in the self-hosted stack. A missing key or one shorter than 32 characters leaves admin actions disabled. Admin methods receive the key as a parameter and compare it in constant time; neither supplied nor configured keys are logged, stored in operation records or returned. The app holds the key in memory for the session only.

After 10 rejected keys in any rolling 60 seconds, pause all admin calls for 60 seconds across the install, including calls with the right key. Public status stays readable. Any caller can cause the pause; this favors limiting guesses over keeping the admin controls continuously available. Operators can block an abusive source at the proxy (C10).

A non-loopback install must terminate TLS in front of the stack before enabling the key. The app offers key entry only over HTTPS or loopback HTTP (C10). In Compose, the optional `KANAME_ADMIN_KEY` reaches only the server service as `SERVERPOD_PASSWORD_adminKey`, never the image, migration service or a committed file (C29).

## Rejected alternative

A custom Serverpod authentication handler could map the shared key to an admin scope, but it would not identify individual users. The pinned Serverpod 4.1.2 constructor exposes one `authenticationHandler` parameter per server (A5); the shared-key handler would have to be combined with or replaced by M2's SSO handler. Keeping the interim gate in `StaticDataAdminEndpoint` gives M2 one place to replace the key check with sign-in and `requiredScopes` (C1).
