# 0003. Pub workspace and vertical, compiled-in modules

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-14)

## Context
The server, the app and the desktop solo engine share domain logic. Serverpod 4.1 projects are Dart pub workspaces: each package declares `resolution: workspace` and one `dart pub get` at the root resolves them all (Serverpod's documentation, "Your Serverpod project", checked through Context7 on 2026-11-14; no installed skill states it, so `repo-scaffold` confirms it against the scaffold the pinned CLI generates). The suite has 19 feature modules.

## Decision
- One root pub workspace holding:
  - `server/` (Serverpod), its generated client package, and `app/` (Flutter);
  - pure-Dart shared packages for the domain model and rules, static data, the ESI client, SSO, sync, and the `FitEngine` interface;
  - `ember_ui` (Flutter) for the Ember theme and components;
  - `tools/` (generators and seeders) and `deploy/`.
- Exact package names are set by `repo-scaffold`.
- Modules are **vertical**: `server/lib/modules/<module>/` and `app/lib/modules/<module>/`. Each declares its capabilities, ESI needs and feature toggle.
- Modules are **compiled in**. There is no runtime plugin loading in 1.0; third parties contribute modules by pull request. Signed webhooks and a read-only API are the extension points.
- Tasks run through mise; no melos.

## Consequences
- Pure-Dart packages must not import Flutter or Serverpod, so the solo engine can reuse them; an analysis rule or test guards this.
- One lockfile and one dependency resolution for the whole repo.
- **Rejected:** melos on top of the workspace (one more tool for what pub and mise already do); runtime plugins (overlapping features and unstable APIs).
- **Reversal cost:** medium. Moving packages is mechanical but touches every import.
