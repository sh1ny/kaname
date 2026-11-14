# 0006. Privacy enforced in the data-access layer

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (policy D7 2026-11-13; enforcement, outbound paths, offline cache, scopes and call log 2026-11-14)

## Context
Each org publishes a sharing policy per data class (required, optional or never requested; who may see it; retention). Personal data is private by default. Org dashboards may use non-shared data only in aggregate. Character-derived data leaves the server through reads, realtime streams, Discord, push, exports and later an API. Endpoint-by-endpoint checks drift as the suite grows.

## Decision
- Every row of character-derived data belongs to a **data class**.
- **Every outbound path** goes through a **privacy scope for the delivering viewer**, which applies the policy predicate. This covers repository reads, stream and bus delivery to subscribers, Discord messages, push, exports and the later API. Endpoints and workers never deliver character-derived data that has not passed the scope.
- An architecture test fails on any bypass, on every one of those paths.
- **Aggregates** over non-shared data require a minimum group size (k ≥ 5 by default, configurable upward) and allow no drill-down.
- **Consent** is per member, character, org and policy version. A policy change needs re-consent within a grace period, and revoking consent hides the data on the server immediately and from every viewer on their next fetch or stream update.
- **Offline cache:** clients persist only the viewer's own data and org records. Other members' policy-governed data is held in memory only, so a revoke takes effect for every viewer on their next fetch and nothing remains on disk.
- **ESI scopes follow the policy.** A login asks for the scopes the enabled modules need, limited to the data classes the org's policy requires, plus the optional classes the member opts into. Never-requested classes get no scope. A policy or opt-in change prompts a re-authorisation.
- **Audit:** viewing another member's data is audited, and members can see the audit of their own data.
- **Admins are not exempt:**
  - per-character rows of the ESI call log are privacy-classed data;
  - admins see route-level totals and errors, and their own characters, without other members' per-character rows unless the policy shares them;
  - corp data from role tokens is org data, governed by capabilities, not personal policy.

## Consequences
- Repositories, stream publishers and delivery workers take a viewer or audience, and test fakes do too.
- The assistant's tools (D11) read through the same scope.
- **Rejected:**
  - Checks in each endpoint: one forgotten check leaks data.
  - Caching other members' data on disk: a revoke cannot reach an offline device.
  - Requesting every enabled module's scopes: the server would hold access members never chose to give.
- **Reversal cost:** high. Every module's data access is built on it.
