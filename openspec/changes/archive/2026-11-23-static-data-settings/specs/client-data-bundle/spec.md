# Spec Delta

## MODIFIED Requirements

### Requirement: Every stored build has its bundle
The server SHALL build a bundle for a staged build before switching to it, and for the active build when it has none, on the compute worker. Each bundle SHALL be stored with its build, size and SHA-256, and removed with its build. A first build SHALL have its bundle built in the same check right after it becomes active, else by the next repair. A failed bundle build SHALL be recorded with its reason and SHALL NOT stop a forward switch; it SHALL stop an update now's restore of a held build.

#### Scenario: Switch to a new build
- **WHEN** an import of build N+1 succeeds while build N is active and the check switches to it (auto-update on and N+1 not held, or an update now)
- **THEN** when the bundle build succeeds, build N+1's bundle is stored before build N+1 becomes active, and build N's bundle stays stored

#### Scenario: New build staged
- **WHEN** a daily or start-up check's import of build N+1 succeeds while build N is active and auto-update is off
- **THEN** build N+1 stays staged and build N stays active

#### Scenario: First import
- **WHEN** the first build ever imported becomes active and the check's bundle build for it succeeds
- **THEN** its bundle is stored in the same check, and it is announced when a refresh selects it, loads its bytes and finds the announcement changed

#### Scenario: Worker exits after the first activation
- **WHEN** the first build becomes active and the worker exits before its bundle is stored
- **THEN** the build stays active and its bundle stays owed: while the build is active and has none, each eligible repair (a 60-second tick or server start that the announcer dispatches, finding the bundle owed in its state read) tries again, a repair that cannot take the lock building nothing, and once a repair stores it, it is announced when a refresh selects it, loads its bytes and finds the announcement changed

#### Scenario: Bundle build fails
- **WHEN** the bundle build for build N+1 fails before a forward switch
- **THEN** the switch to build N+1 still happens, the failure is recorded with its reason for build N+1, the same check makes no second attempt, and later eligible repairs, server starts or build checks try again until one stores it

#### Scenario: Held restore needs its bundle
- **WHEN** an update now restores held build N and building build N's missing bundle fails
- **THEN** no swap happens, the job ends "update failed" with the bundle's public reason, and build N stays held

#### Scenario: Build removed
- **WHEN** a switch removes the old previous build N-1
- **THEN** build N-1's bundle is removed in the same step

### Requirement: A missing active bundle is repaired
Every monolith start in a development, staging or production run mode that reaches its repair dispatch, every lock-holding build check, and every 60-second tick the announcer dispatches while the bundle is owed SHALL attempt to build the active build's bundle when it is missing, failed or of another format version; an attempt without the lock, or a start ending before that dispatch, leaves it owed. Missing hash, size or bytes count as missing. No check SHALL rebuild what it attempted.

#### Scenario: Restart after an interrupted bundle build
- **WHEN** the server stops while it builds the active build's bundle, and starts again the same day after the daily check
- **THEN** a repair is attempted during start-up, with no build check; when it takes the lock it stores the bundle, which is announced when a refresh selects it, loads its bytes and finds the announcement changed

#### Scenario: Lock held at start
- **WHEN** the server starts with no check due while another process holds the static-data lock, and that process exits without building the active build's missing bundle
- **THEN** a later 60-second tick at which no repair is outstanding attempts the repair, and once a repair stores the bundle it is announced when a refresh selects it and loads its bytes

#### Scenario: Start-up ends before the repair
- **WHEN** the server starts with the active build's bundle missing, and its start-up sweep fails before the repair is dispatched
- **THEN** no repair runs in that pass, the bundle stays owed, and a later start-up pass or a 60-second tick at which no repair is outstanding attempts it

#### Scenario: Start-up repair hangs before its job
- **WHEN** the start-up check is not due, the active build's bundle is missing, and the start-up repair request reaches a worker that fails before running the job and hangs without replying
- **THEN** after 30 minutes the status says worker stuck, no second repair is sent while it is unanswered, the bundle stays owed, and a server restart recovers

#### Scenario: Tick repair hangs after start-up
- **WHEN** start-up has ended, the active build's bundle becomes owed, and the repair a 60-second tick sends hangs without replying
- **THEN** after 30 minutes the status says worker stuck, no other repair is sent while it is outstanding, and the bundle stays owed

#### Scenario: Repair replies while a check stays stuck
- **WHEN** a start-up catch-up check has had no reply for 30 minutes and shows worker stuck, and a tick repair then replies
- **THEN** the status still says worker stuck until the check itself replies or its worker exits

#### Scenario: Admin reply while a repair stays stuck
- **WHEN** a bundle repair is stuck and shows worker stuck, and an admin job's unanswered request then replies
- **THEN** the status still says worker stuck until the repair itself replies or its worker exits

#### Scenario: Format version changed
- **WHEN** a server whose bundle format is 2.0 starts and the active build's stored bundle is format 1.0
- **THEN** an eligible repair that takes the lock builds a format 2.0 bundle for the active build, which is announced when a refresh selects it and loads its bytes

#### Scenario: Bundle bytes lost
- **WHEN** the active build's bundle metadata is stored but its bytes are not
- **THEN** the announcer and the repair count it as missing: the announcer does not announce it and owes its repair, and the next build check that holds the lock rebuilds it, after which a refresh that selects it and loads its bytes announces it

