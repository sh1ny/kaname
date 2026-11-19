import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

void main() {
  group('DailyBuildCheckSchedule', () {
    test('the cron expression is 12:00 UTC every day', () {
      expect(DailyBuildCheckSchedule.cron, '0 12 * * *');
    });

    test('no check ever is due a catch-up', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: null,
          hasActiveBuild: true,
          now: DateTime.utc(2026, 3, 10, 15),
        ),
        isTrue,
      );
    });

    test('no active build is due a catch-up even after today\'s check', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: DateTime.utc(2026, 3, 10, 12),
          hasActiveBuild: false,
          now: DateTime.utc(2026, 3, 10, 15),
        ),
        isTrue,
      );
    });

    test('a restart across 12:00 UTC is due a catch-up', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: DateTime.utc(2026, 3, 9, 12, 20),
          hasActiveBuild: true,
          now: DateTime.utc(2026, 3, 10, 12, 5),
        ),
        isTrue,
      );
    });

    test('a check today at 12:00 with a restart at 15:00 is not due', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: DateTime.utc(2026, 3, 10, 12),
          hasActiveBuild: true,
          now: DateTime.utc(2026, 3, 10, 15),
        ),
        isFalse,
      );
    });

    test('before 12:00 the boundary is yesterday\'s 12:00', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: DateTime.utc(2026, 3, 9, 12, 20),
          hasActiveBuild: true,
          now: DateTime.utc(2026, 3, 10, 11, 58),
        ),
        isFalse,
      );
    });

    test('the boundary crosses a month start', () {
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: DateTime.utc(2026, 2, 28, 12),
          hasActiveBuild: true,
          now: DateTime.utc(2026, 3, 1, 9),
        ),
        isFalse,
      );
    });

    test('non-UTC inputs are compared as instants', () {
      // 13:30 at UTC+2 is 11:30 UTC, so the boundary is yesterday's 12:00.
      final localNow = DateTime.parse('2026-03-10T13:30:00+02:00');
      final lastUtc = DateTime.utc(2026, 3, 9, 12, 20);
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: lastUtc,
          hasActiveBuild: true,
          now: localNow,
        ),
        isFalse,
      );
      // 14:10 at UTC+2 is 12:10 UTC: the check at 12:20 yesterday is stale.
      expect(
        DailyBuildCheckSchedule.catchUpDue(
          lastCheckStartedAt: lastUtc,
          hasActiveBuild: true,
          now: DateTime.parse('2026-03-10T14:10:00+02:00'),
        ),
        isTrue,
      );
    });
  });
}
