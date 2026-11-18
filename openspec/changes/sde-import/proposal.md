# Proposal

## Why

Kaname needs EVE's static data (types, groups, dogma, the map) before any product feature works. CCP ships new SDE builds with game updates, and ADR 0004 requires taking them as data, never as code. This change is the second of five in **M1 - Static data pipeline**. It advances two exit criteria:

- **Import:** the server imports an SDE build side by side with the active one. Known columns are typed and every row keeps its full record as JSON. A new field or file is kept and reported. Only a missing file Kaname depends on stops the import, and a failed import leaves the active build untouched. No code is generated from SDE content, and the known-ids table is checked against each build.
- **R38 report:** a report records whether the SDE has every field industry and logistics need right after a patch.

It also settles the Postgres part of strategy row R56, which asks how a worker isolate reaches Postgres, Redis, the token vault, the privacy scope and the bus; the rest stays open for the first worker that needs it. The importer is the first job on the compute worker isolate (ADR 0009). The atomic switch, the diff report and the daily check come next, in `sde-build-switch`. This change advances no user-verified exit criterion: the owner's check of taking a new build while the server and an app run is judged when M1 closes, after `sde-build-switch`, `client-data-bundle` and `static-data-settings` have landed.

## What Changes

- **Compute worker isolate:** the server starts its first worker isolate. How a worker reaches Postgres is decided here and recorded as ADR 0012, which fills that part of ADR 0009's open item. Redis, the vault, the privacy scope and the bus stay open in R56 until the first worker that needs them.
- **Static-data importer:** a pure-Dart job behind the job-runner interface, run on the compute worker.
  - It reads CCP's build-numbered JSONL SDE, either downloaded from CCP (build number from `latest.jsonl`) or from a local zip.
  - It imports into Postgres side by side with any active build.
  - The typed set gets typed known columns, and every row also keeps its full record as JSON. The typed set is categories, groups, types, market groups, meta groups, dogma (attributes, attribute categories, effects, units, type dogma), regions, constellations and solar systems.
  - Other files CCP already ships are stored record by record as raw JSON. A file new in a build is stored raw and reported, and so is a new field in a typed file.
  - Only the loss of a required file stops an import: a file of the typed set, or the build's `_sde` record that carries its build number. A bad record is skipped and reported. A failed import leaves the active build and its data untouched.
- **Import record:** each import records its build number, its outcome and what it reported: new files, new fields, known-ids check results and the R38 field check.
- **Known-ids table:** one small table of the ids code must know, checked against every build. A missing id is reported; the importer does not crash on it.
- **R38 field check:** a declared list of the fields industry and logistics need, checked on every import. A committed report for the current build serves as the exit-criterion evidence.
- **Starting an import:** on server start, when no build is active, the import is queued for CCP's latest build. A mise development task runs the same job against a local zip.
- **Bootstrap activation:** the importer activates a build only when none is active. Later builds are imported side by side and stay staged until `sde-build-switch`.
- No Dart code, enum or constant is generated from SDE content.

## Capabilities

### New Capabilities
- `static-data-import`: importing SDE builds into the server side by side. Covers the source, the typed and raw storage, drift tolerance and reporting, required files, the known-ids check, the R38 field check, the import record, how an import starts, and bootstrap activation.
- `server-workers`: the server's worker isolates. Covers the compute worker's lifecycle and how a worker isolate reaches Postgres (the Postgres part of R56).

### Modified Capabilities
- None.

## Impact

- `server/kaname_server`: new Serverpod models, tables and a migration for builds, typed static-data rows, raw records and import records; the compute worker's start and supervision; the start-time import trigger.
- `packages/`: pure-Dart importer and job logic, so solo desktop can reuse the importer later (ADR 0003, ADR 0009).
- New dependencies for zip reading and HTTP download (licence and notices checks apply; `THIRD_PARTY_NOTICES` regenerated).
- `server/kaname_client`: gains a dependency on `kaname_core`, which holds the `SdeJson` wrapper the generated code needs.
- `docs/adr/0012-*.md` (new); `openspec/architecture.md` index; strategy rows R56 and R38.
- Postgres storage: at most three builds exist at once (ADR 0004). Each holds the full SDE.
- Outbound HTTPS from the server to `developers.eveonline.com`.

## Decision Making

DECISION_MAKING: all
- **Source:** setting

### S1: How an import starts in this change

- **Choice:** on server start, when no build is active, the import is queued for CCP's latest build and runs on the compute worker. A mise development task runs the same job against a local zip.
- **Rejected:** an operator command in a separate one-shot process (it would not run on the compute worker, contradicting ADR 0009); importing only from tests and a dev task (a running server would hold no static data until `sde-build-switch`).
- **Reversal cost:** low
- **Important:** yes - changes behaviour users see: the server downloads the SDE on first start.
- **Chosen by:** user

### S2: Bootstrap activation only

- **Choice:** the importer activates a build only when none is active. Later builds stay staged until `sde-build-switch`.
- **Rejected:** staging only (nothing could read static data until the next change lands).
- **Reversal cost:** low
- **Important:** yes - binds future changes: `sde-build-switch` takes over activation from this rule.
- **Chosen by:** user

### S3: Typed set (required files)

- **Choice:** categories, groups, types, market groups, meta groups, dogma (attributes, attribute categories, effects, units, type dogma), regions, constellations and solar systems are typed and required. Other files are stored raw, and files new in a build are stored raw and reported.
- **Rejected:** typing every current file (more schema, and more files whose loss would stop an import); types and systems only (dogma would stay untyped although `client-data-bundle` needs it).
- **Reversal cost:** medium
- **Important:** yes - binds future changes: storage format and the required-file list.
- **Chosen by:** user

### S4: R38 field check

- **Choice:** a declared list of industry and logistics fields is checked on every import, and the result goes into the import record. A committed report for the current build is the evidence.
- **Rejected:** a one-off report (blind to later patches); a per-import check only (no durable evidence for the exit criterion).
- **Reversal cost:** low
- **Important:** yes - chosen on weak evidence: which fields industry and logistics will need is only estimated before M18 and M22.
- **Chosen by:** user

### S5: Where R56's settlement is recorded

- **Choice:** a new ADR 0012, "Worker isolate access", fills the Postgres part of ADR 0009's open item without superseding it; the rest of R56 stays open. It is reviewed with this change's design and accepted with it; the architecture index and strategy row R56 are updated.
- **Rejected:** recording it only in design.md and row R56 (later workers would have to find it in an archived change); superseding ADR 0009 (rewrites the whole process model for one open item).
- **Reversal cost:** medium
- **Important:** yes - binds future changes: every later worker isolate follows it.
- **Chosen by:** user

### S6: SDE source

- **Choice:** download the build's JSONL zip from CCP (build number from `latest.jsonl`), or read a local zip. In this change the local zip serves tests and the dev task; a local-zip import for staging and production installs without internet access comes with `static-data-settings`.
- **Rejected:** CCP download only (tests would need a fake HTTP server for every case, and offline installs would have no path).
- **Reversal cost:** low
- **Important:** yes - binds future changes: the importer's source interface.
- **Chosen by:** user
