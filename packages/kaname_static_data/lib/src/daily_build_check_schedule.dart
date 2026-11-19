/// The schedule of the daily build check.
library;

/// When the server checks CCP for a new SDE build.
///
/// The daily schedule (cron and catch-up rule) is declared once in
/// `kaname_static_data`. The server and, later, solo desktop only adapt it to
/// their own scheduler (C8).
///
/// The check runs at 12:00 UTC, after EVE's daily downtime. A start also
/// checks when it finds that a run was missed ([catchUpDue]).
abstract final class DailyBuildCheckSchedule {
  /// The cron expression of the daily check, in UTC.
  static const String cron = '0 12 * * *';

  /// Whether a check must run now to catch up.
  ///
  /// It is due when no build is active ([hasActiveBuild] is `false`), or when
  /// no check has started since the most recent 12:00 UTC at or before [now].
  /// [lastCheckStartedAt] is `null` when no check is recorded, which is due.
  /// Every argument is read as an instant, so a value that is not in UTC
  /// gives the same answer as its UTC equivalent.
  static bool catchUpDue({
    required DateTime? lastCheckStartedAt,
    required bool hasActiveBuild,
    required DateTime now,
  }) {
    if (!hasActiveBuild || lastCheckStartedAt == null) return true;
    return lastCheckStartedAt.isBefore(_latestRunAtOrBefore(now));
  }

  static DateTime _latestRunAtOrBefore(DateTime now) {
    final utc = now.toUtc();
    final today = DateTime.utc(utc.year, utc.month, utc.day, 12);
    return utc.isBefore(today)
        ? DateTime.utc(utc.year, utc.month, utc.day - 1, 12)
        : today;
  }
}
