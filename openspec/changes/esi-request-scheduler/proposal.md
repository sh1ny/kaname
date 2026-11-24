# Proposal

## Why

ESI's budgets are shared, so independent module throttles cannot prevent one caller from exhausting capacity for the rest. M2 change 2 builds on the archived `esi-client-generator` and advances the agent-verified shared-scheduler exit criterion: atomic server and solo reservations, response-header correction, four governor tiers, priorities, shared negative caching and conditional polling with downtime handling. The owner's sign-in demo remains an M2 close criterion after `esi-sso`.

## What Changes

- Route every production ESI operation through the generated client's scheduled transport. Reserve a rolling bucket budget and protect the shared connection error budget before dispatch; reconcile from response headers.
- Use Redis for the server across isolates and one in-process store in native solo. Apply the same four-tier governor and five priorities in both.
- Share bounded 403/404 suppression and honor conditional GET validators, expiry, per-install jitter and Tranquility downtime. Coalesce equivalent in-flight corporation polls across server isolates without sharing response bodies or credentials.
- Return a distinct not-sent result rather than reporting a scheduler refusal as a wire error. Verify through generated calls and synthetic exchanges; no live CCP credentials required.

Out of scope: call logging, token vault, SSO, issues #25–#29, role discovery, periodic product recipes, pagination traversal, solo engine or store setup, and UI.

## Capabilities

### New Capabilities

- `esi-request-scheduling`: shared admission, rate and error budgets, governor, and conditional polling.

### Modified Capabilities

- `esi-client`: expose scheduler refusal as a distinct typed result; preserve the injected transport and dependency-free client.

## Impact

Generated ESI client runtime, shared Dart scheduling policy, native/server HTTP composition, server Redis adapter and integration tests. No new endpoint or database migration. ADRs 0001, 0002, 0003, 0005, 0006, 0007, 0009 and 0012 constrain the change.

Manual branch gate (owner-approved Orca workaround): OpenSpec root is repo-local; the checkout was clean at `371f24789e19bef1cb00f009b9b8c71b174808f2`, verified as the GitHub `main` tip. The generator archive existed and the scheduler archive and target branch did not. The local `main` ref was behind and checked out elsewhere; the feature branch was created from the verified `origin/main` tip without changing that checkout. Specwright 0.39.1, interface 3, was bootstrapped only in this worktree.

## Decision Making

DECISION_MAKING: all
- **Source:** setting. The owner delegated inner design details to the author for this change; scope decisions still require the owner.

### S1: Corporation polling

- **Choice:** coalesce equivalent in-flight corporation polls using a supplied qualified character; the recipe owns role selection and recurrence.
- **Rejected:** leave cross-isolate coalescing to each future recipe, duplicating coordination.
- **Reversal cost:** medium.
- **Important:** yes, binds future recipe callers.
- **Chosen by:** user.

### S2: Pagination

- **Choice:** schedule each page or cursor independently and retain distinct conditional identities. The M5 Character Data and Member Audit ingestion-recipes change (not yet individually named in the roadmap) owns traversal, consistency and writes. This supersedes the generator proposal's allocation of traversal to this change.
- **Rejected:** generic traversal now, without a recipe to own cursor recovery or partial results.
- **Reversal cost:** low.
- **Important:** yes, binds future recipe callers.
- **Chosen by:** user.

### S3: Runtime scope

- **Choice:** production server composition and a reusable native-solo factory; prove both through synthetic upstream exchanges. No production consumer solely to demonstrate the scheduler.
- **Rejected:** add a public status product endpoint before a product change needs one. Internal recovery probes are part of the scheduler, not product consumers.
- **Reversal cost:** low.
- **Important:** yes, changes scope.
- **Chosen by:** user.
