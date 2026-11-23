# Proposal

## Why

M1 (Static data pipeline) is meant to end with nobody needing a shell to see or steer static data. The server already imports, switches, compares and announces SDE builds, and apps keep a bundle. But the state of all this sits in database records and development tasks: the loaded build versus CCP's latest, the last check and import, and the change report. Auto-update is always on (carried gap C3 of `sde-build-switch`). This change adds the settings page that ADR 0004 promises. It advances the M1 exit criterion "An admin and solo settings page shows loaded versus latest build, the last check, 'update now' and the last import's result; auto-update is on by default." It is the last M1 change.

It also gives the owner what the user-verified M1 criterion needs, "The owner takes a new SDE build while the server and an app run, sees the change report and the settings page, and searches types and systems offline": the change report and the settings page. That criterion is judged at the M1 close, not by a task here. It spans every M1 change, and close walks it with the owner on a running stack.

## What Changes

- **Server status read:** a new static-data status call that needs no sign-in. It returns the active and previous builds, a staged build if any, the held build, CCP's latest build from the last check, the last check (time, outcome, reason), the last import (build, outcome, reason, file counts), the last switch or rollback, the auto-update setting, and whether static-data work is running (busy). Failure reasons are mapped to a fixed public set. It holds no credentials, paths, URLs or host names.
- **Install admin key:** a new optional secret in the server's passwords file. When it is set, admin calls compare the key the app sends with it. When it is missing, admin calls are refused and the status says admin actions are not configured. The app holds the key in memory for the session only. After 10 rejected keys in one minute, every admin call is refused for one minute. This is an interim gate that M2's sign-in and roles replace.
- **Admin actions:** "update now" and "roll back" change build state, so they run on the compute worker and never through the main isolate's ORM (C7). "Update now" runs the build check at once against CCP's latest build: it imports and switches, or switches to a newer staged build. "Roll back" swaps the active and previous builds the admin confirmed, as the development task does. The auto-update toggle is not build state: the server stores it directly. It is on by default and never stops the first build from becoming active.
- **Auto-update off:** the daily and start-up checks import a newer build and leave it staged, recorded as `staged`. "Update now" switches to it without a second import.
- **Change report read:** the stored report for the active build against the build it replaced. Per file it gives added, removed and changed counts, changed fields with their counts (at most 200 per file), and keys up to the 1,000 cut-off per kind and 20,000 in all, each cut list marked.
- **App: Static data section in Settings**, between Server and About, for everyone:
  - this app's bundle: the build it holds, the build announced, the last download result and its reason, and "download now", which retries at once and skips the backoff wait;
  - the server's build status;
  - once an admin key is entered: update now, roll back and the auto-update toggle.

  The change report opens as its own page from the section. Status refreshes when the section opens, when the build-change stream announces a change and when the user asks. While an import, update or rollback runs, it refreshes every 5 seconds, and every 30 seconds otherwise; the server serves the status from a 1-second shared cache. Each admin action carries an operation id the app makes; the server stores it with the action's outcome, and the app follows its own action to its end. Admin key entry is offered only over https or to a server on this machine.
- **Out of scope:**
  - local-zip import for staging and production, and switching to a zip-imported build (carried gaps C4 and C10 move to a later change);
  - zip upload through the app;
  - on-device import and a real solo mode (M4);
  - sign-in and roles (M2);
  - an admin health page beyond static data.

## Capabilities

### New Capabilities

- `static-data-admin`: the server's static-data status and admin surface: the status read, the change report read, the install admin key, and the update-now, rollback and auto-update actions.
- `static-data-settings`: the app's Static data section and change-report page: this app's bundle status and "download now", the server's build status, admin key entry and the admin controls.

### Modified Capabilities

- `static-data-builds`: a stored auto-update setting, on by default. When it is off, a check stages a newer build instead of switching. A check can also be started by "update now". A rollback can also be started by the admin action, not only by the development task.
- `client-data-bundle`: a failed bundle build still never stops a forward switch, but stops an update now's restore of a held build; a successful import switches only when the check switches (auto-update on, or update now), else the build stays staged.
- `static-data-import`: an import whose commit landed keeps its build and its succeeded record when its acknowledgement was lost, even if the server stops; only an aborted import leaves no rows. A start-up pass that fails before its check is retried, so a fresh install still imports.
- `client-static-data`: a user's "download now" retries a failed download at once, without the backoff wait.
- `app-settings`: Settings has four sections: Appearance, Server, Static data and About.

## Impact

- **Server** (`server/kaname_server`): a new admin endpoint, new methods on `StaticDataEndpoint`, and a report web route beside the bundle route. One migration: a setting table, an admin-operation table, a build-state revision row, a trigger column on check records and a size column on stored change reports. The admin-key password entry and its docs. A new worker request for rollback and an update-now trigger on the check request; the setting is written on the main isolate. The check job reads the setting (`packages/kaname_static_data`, `TakeLatestBuildJob`). Generated client code.
- **App** (`app/lib/static_data`, `app/lib/settings`): the status data source, a notifier with sealed states (ADR 0010), the Static data section, the report page, admin-key storage, the "download now" hook into `static_data_sync`, l10n strings and widget tests.
- **Docs:** self-host docs for the admin key, and where the settings page sits.
- **Constraints:** ADR 0004 (settings page, auto-update on by default), ADR 0009 and 0012 (jobs on the compute worker; workers send typed replies), ADR 0010 (Riverpod in `logic/` only), ADR 0014 (only the main isolate publishes), ADR 0006 (the status read carries no personal or secret data), DESIGN.md and Ember UI.
- **No new dependency is expected.** If one is needed, it brings a THIRD_PARTY_NOTICES regeneration.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: Gate for admin actions before sign-in

- **Choice:** an install admin key in the server's passwords file, entered once in the app and checked on every admin call. The status stays readable by anyone. M2's roles replace it.
- **Rejected:** a read-only page until M2 (misses the exit criterion's "update now" and toggle); open to anyone (a public install could be abused).
- **Reversal cost:** medium
- **Important:** yes, because it binds future changes: it is a config key and an interim auth boundary that M2 must replace.
- **Chosen by:** user

### S2: Meaning of the solo half before solo mode exists

- **Choice:** every app shows its own bundle state (held versus announced build, last download result) and "download now". On-device import and solo auto-update come with M4.
- **Rejected:** a server-only page (the app's bundle state stays invisible); on-device import now (pulls M4 work forward).
- **Reversal cost:** low
- **Important:** yes, because it changes what users see.
- **Chosen by:** user

### S3: What "update now" does

- **Choice:** run the build check at once against CCP's latest build: import and switch, or switch to a newer staged build. Local-zip import and switching to a zip-imported build (C4, C10) move to a later change.
- **Rejected:** a local zip at a configured server path; a zip upload through the app (a large bounded-upload route).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see, and it moves two carried gaps.
- **Chosen by:** user

### S4: Daily check with auto-update off

- **Choice:** import the newer build and leave it staged, recorded `staged`. "Update now" switches to it without a second import.
- **Rejected:** record only CCP's build number and import on "update now" (a slower update when pressed).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see.
- **Chosen by:** user

### S5: Change report and rollback in the UI

- **Choice:** the app shows the stored report of the active build against the build it replaced: counts, changed fields and keys up to the cut-off. An admin "roll back" action sits behind the admin key.
- **Rejected:** the report only, with rollback left a development task; per-file counts only.
- **Reversal cost:** low
- **Important:** yes, because it changes what users see.
- **Chosen by:** user

### S6: Where the page lives

- **Choice:** a Static data section in Settings, between Server and About, with the report on its own page.
- **Rejected:** a separate shell destination.
- **Reversal cost:** low
- **Important:** yes, because it changes what users see (it modifies the Settings sections requirement).
- **Chosen by:** user

### S7: "Update now" on a held build

- **Choice:** "update now" switches to a held build and lifts its hold. It is the way to undo a rollback from the page.
- **Rejected:** respect the hold as the daily check does.
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see.
- **Chosen by:** user

### S8: Rejected admin keys

- **Choice:** compare keys in constant time. After 10 rejected keys in one minute, from any caller, every admin call is refused for one minute with "too many attempts". Each rejection is logged without the key.
- **Rejected:** rejection with no limit (leaves the key open to guessing on a public install).
- **Reversal cost:** low
- **Important:** yes, because it binds future changes (a security boundary).
- **Chosen by:** user

### S9: Where the app keeps the admin key

- **Choice:** in memory for the session only; it is entered again after a restart or reload.
- **Rejected:** plain device preferences (an unencrypted secret at rest); OS secure storage (a new plugin dependency, and web still has no secure store).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see.
- **Chosen by:** user

### S10: Status freshness

- **Choice:** read on open, on each build-change announcement and on "refresh". While an import, update or rollback runs, re-read every 5 seconds until it ends.
- **Rejected:** events and manual refresh only (a running import would look stuck).
- **Reversal cost:** low
- **Important:** yes, because it changes behaviour users see.
- **Chosen by:** user
