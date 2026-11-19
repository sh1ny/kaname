# Proposal

## Why

`sde-import` stores SDE builds side by side, but only the first build ever becomes active. A newer build stays staged, and the server never looks for one. ADR 0004 requires the server to check daily, switch atomically while requests run, keep one previous build for rollback and diffs, and report what changed. This change is the third of five in **M1 - Static data pipeline** (prerequisite `sde-import`, done). It advances this agent-verified exit criterion:

- The build switch is atomic: requests in flight finish on the old build, with no restart, and one previous build is kept for rollback and diffs. A report lists what changed between two builds. A daily check finds new builds.

It also prepares the user-verified criterion "the owner takes a new SDE build while the server and an app run, sees the change report and the settings page, and searches types and systems offline". That criterion is judged when M1 closes, because the settings page and the app's offline search come with `client-data-bundle` and `static-data-settings`. This change adds no `[user]` task.

Constraining ADRs: 0004 (static data is data, swapped live), 0009 (one process, compute worker isolate, jobs behind a runner with future calls as the server adapter), 0012 (workers reach Postgres through their own per-job connections; the static-data advisory lock).

## What Changes

- **Previous build state:** a stored build is `active`, `previous` or `staged`. At rest there is one active build, at most one previous and at most one staged. A new import replaces the staged build, so at most three builds exist while an import runs (ADR 0004).
- **Atomic switch:** after an import of a build newer than the active one succeeds, the server switches to it at once (auto-update is always on in this change). In one transaction the new build becomes active, the old active becomes previous and the old previous is removed. There is no restart.
- **Pinned reads:** a server-side static-data reader resolves the active build once per request and reads only that build. A request that started before a switch finishes on the old build, which stays stored as the previous build. No client endpoint is added.
- **Rollback:** a rollback job swaps the active and previous builds atomically, run through a mise development task. The rolled-back build is held: the daily check does not switch back to it, and only a build newer than it lifts the hold.
- **Diff report:** before each switch, the compute worker compares the new build with the active one. For each file the report holds the added, removed and changed record counts and their keys (capped per file); for typed files it also lists which fields changed and how often. It is stored with the build. A development task diffs any two stored builds.
- **Daily check:** a recurring Serverpod future call, the job adapter from ADR 0009, runs once a day after EVE's 11:00 UTC downtime. On start, a check also runs when no build is active or no check has started since the most recent 12:00 UTC. A check reads CCP's latest build number and imports and switches when it is newer than the active build and not held. A build older than the active one is not imported. Each check is recorded.
- **Import changes:** "only the first build is activated by the importer" gives way to the switch, and the storage bound grows from one staged build to one previous plus one staged.

Out of scope: the server notice to apps and the client data bundle (`client-data-bundle`); the settings page, "update now", the auto-update toggle, and a UI for the diff report and rollback (`static-data-settings`).

## Capabilities

### New Capabilities
- `static-data-builds`: the lifecycle of stored SDE builds after import. It covers build states, the atomic switch, reads pinned to one build per request, the previous build and rollback with its hold, the diff report between two builds, and the daily check.

### Modified Capabilities
- `static-data-import`: the storage bound now counts a previous build next to the active and staged ones, and a staged build is removed before an import writes. Activation of a later build moves from "stays staged" to the switch in `static-data-builds`. The start-time import becomes a start-time build check, which can also import a newer build on a server that already has one.
- `server-workers`: the compute worker runs every static-data job the server runs (build checks, imports, comparisons and switches), not only the import.

## Impact

- `packages/kaname_static_data`: build-state model with `previous`, the switch, rollback and daily-check job logic, the diff computation, the pinned reader interface, and in-memory fakes for all of them.
- `server/kaname_server`: `SdeBuildState` gains `previous`; new tables for the diff report, the check record and the rollback hold, with a migration; the Postgres implementations; the first recurring future call; new mise development tasks for rollback and diff.
- `openspec/architecture.md`: state-ownership rows for static-data builds (states and switch owner) checked against the code.
- Postgres storage: up to three builds at once, as before; diff reports add a few rows per build.
- Outbound HTTPS to `developers.eveonline.com` once a day.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: How a switch starts

- **Choice:** after an import of a build newer than the active one succeeds, the server switches to it at once. Auto-update is always on in this change; the on/off setting arrives with `static-data-settings`.
- **Rejected:** a server config key to turn auto-update off now (the settings page will store the setting in the database instead, so the key would be replaced); a manual switch only (no new build would go live without someone acting until `static-data-settings`).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see: a new build goes live without anyone acting.
- **Chosen by:** user

### S2: Rollback

- **Choice:** a rollback job swaps the active and previous builds atomically, run through a mise development task; the UI comes with `static-data-settings`. The rolled-back build is held: the daily check does not take it back until a newer build appears.
- **Rejected:** rollback with no hold (the next daily check would switch straight back to the build that was rolled back); keeping the previous build without a rollback action (ADR 0004 keeps it for rollback, and nothing could use it).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: the settings page drives the same job and shows the hold.
- **Chosen by:** user

### S3: Diff report content

- **Choice:** for each file, the added, removed and changed record counts and their keys (capped per file); for typed files, which fields changed and how often. Before each switch, the build being switched to is compared with the active build and the report is stored. A build that stays staged, such as one imported by the development task, gets its report when it is switched to. A development task diffs any two stored builds.
- **Rejected:** counts only (says little about what moved); full record diffs (large storage for each build); comparing every import, including development-task imports (review round 1: the switch is where the report matters, and the diff task covers any pair on demand).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: `static-data-settings` shows this stored format.
- **Chosen by:** user

### S4: Daily check timing

- **Choice:** a check once a day at 12:00 UTC, after EVE's 11:00 UTC downtime, run by a recurring Serverpod future call. On start, a check also runs when no check has started since the most recent 12:00 UTC.
- **Rejected:** every 24 hours from server start (a check can fall just before the day's patch); a configurable time of day (a config key nobody needs yet); a catch-up only when the last check is more than 24 hours old (review round 1: a restart just after 12:00 UTC would skip that day).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes: it is the first recurring future call and sets the job-adapter pattern.
- **Chosen by:** user

### S5: Read path

- **Choice:** a server-side static-data reader resolves the active build once per request and reads only that build. Tests prove that a request started before a switch finishes on the old build. No client endpoint is added.
- **Rejected:** also adding an "active build" endpoint for the app now (`client-data-bundle` designs what the app needs).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: every server-side static-data reader goes through it.
- **Chosen by:** user

### S6: Storage bound

- **Choice:** at rest there is one active build, at most one previous and at most one staged. A new import replaces the staged build, so at most three builds exist while an import runs (ADR 0004). The daily check does not import a build older than the active one.
- **Rejected:** at most two builds at rest, with no staged build (an imported build whose switch failed would be lost).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: it is a storage bound in the architecture.
- **Chosen by:** user

### S7: Non-goals

- **Choice:** the server notice to apps and the bundle go to `client-data-bundle`. The settings page, "update now", the auto-update toggle, and a UI for the diff report and rollback go to `static-data-settings`. This change exposes the switch, rollback and diff only through stored records and development tasks.
- **Rejected:** pulling an "update now" development task in now (the daily check and the start check already cover it).
- **Reversal cost:** low
- **Important:** no
- **Chosen by:** user
