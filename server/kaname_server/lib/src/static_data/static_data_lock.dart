/// The advisory lock key of the static-data import.
library;

/// The one Postgres advisory-lock key that guards static-data writers.
///
/// The import job holds `pg_try_advisory_lock(staticDataAdvisoryLockKey)` for
/// the whole job (a session lock, released with the connection). The start
/// hook and the worker supervisor probe the same key with
/// `pg_try_advisory_xact_lock(staticDataAdvisoryLockKey)` inside a short
/// transaction: session and transaction locks on one key conflict, so a probe
/// succeeds only while no import is live. Nothing else may use this key.
///
/// The value is the ASCII bytes of `KANAME` read as one integer.
const int staticDataAdvisoryLockKey = 0x4B414E414D45;

/// The separate D21 lock: shared for inserts and exclusive for recovery.
const int staticDataAdmissionLockKey = 0x4B414E414D46;
