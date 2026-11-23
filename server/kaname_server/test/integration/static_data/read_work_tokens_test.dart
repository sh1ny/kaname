import 'dart:async';

import 'package:kaname_server/src/static_data/read_work_tokens.dart';
import 'package:test/test.dart';

import '../support/announcer_support.dart';

void main() {
  test('tokens are status 2, report 2, operation 4 and admin 2, and a '
      'token returns only when its session future completes', () async {
    final clock = FakeClock();
    final tokens = ReadWorkTokens(clock: clock);
    const limits = {
      ReadWorkKind.status: 2,
      ReadWorkKind.report: 2,
      ReadWorkKind.operation: 4,
      ReadWorkKind.admin: 2,
    };
    final sessions = <ReadWorkKind, List<Completer<int>>>{};
    final runs = <ReadWorkKind, List<Future<int>>>{};
    for (final MapEntry(:key, :value) in limits.entries) {
      final active = sessions[key] = List.generate(value, (_) => Completer());
      runs[key] = [
        for (final work in active)
          tokens.tryRun(key, (sent) {
            sent();
            return work.future;
          })!,
      ];
    }
    for (final kind in limits.keys) {
      expect(
        tokens.tryRun(kind, (_) async => fail('capacity exceeded')),
        isNull,
      );
    }
    // The statement grace has already elapsed. The capacity stays reserved
    // while each database future (including session cleanup) is outstanding.
    clock.elapse(const Duration(seconds: 30));
    for (final kind in limits.keys) {
      expect(
        tokens.tryRun(kind, (_) async => fail('cleanup outstanding')),
        isNull,
      );
      sessions[kind]!.first.complete(42);
      expect(await runs[kind]!.first, 42);
      expect(await tokens.tryRun(kind, (_) async => 7), 7);
      for (final work in sessions[kind]!.skip(1)) {
        work.complete(42);
      }
      await Future.wait(runs[kind]!);
    }
  });

  test(
    'statement grace is measured from the last dispatch, not completion',
    () async {
      final clock = FakeClock();
      final tokens = ReadWorkTokens(clock: clock);
      final active = Completer<void>();
      final other = tokens.tryRun(ReadWorkKind.report, (_) => active.future)!;
      late void Function() sent;
      final statement = Completer<void>();
      final read = tokens.tryRun(ReadWorkKind.report, (mark) {
        sent = mark;
        return statement.future;
      })!;
      sent();
      clock.elapse(const Duration(seconds: 6));
      sent();
      clock.elapse(const Duration(seconds: 8));
      statement.complete();
      await read;
      expect(tokens.tryRun(ReadWorkKind.report, (_) async {}), isNull);
      clock.elapse(const Duration(seconds: 2));
      expect(tokens.tryRun(ReadWorkKind.report, (_) async {}), isNotNull);
      active.complete();
      await other;
    },
  );
}
