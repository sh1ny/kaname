import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_app/static_data/logic/admin_setting_tracker.dart';
import 'package:kaname_client/kaname_client.dart';

/// Registers the auto-update tracker cases in the admin session suite.
void adminSettingCases() {
  group('auto-update writes', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.tracker.dispose());

    test(
      'setting not saved restores the switch and shows Setting not saved',
      () async {
        h.write(false);
        h.calls.single.complete(_answer(AdminAnswerOutcome.settingNotSaved));
        await _flush();
        expect(h.tracker.view!.value, isTrue);
        expect(h.tracker.view!.notice, AdminAnswerOutcome.settingNotSaved);
      },
    );

    test(
      'a status read begun before the toggle answer leaves the switch off',
      () async {
        h.write(false);
        h.calls.single.complete(
          _answer(
            AdminAnswerOutcome.settingConfirmed,
            value: false,
            revision: 2,
          ),
        );
        await _flush();
        h.tracker.observe(true, WriteRevision(id: 1));
        expect(h.tracker.view!.value, isFalse);
        expect((h.tracker.view!.revision as WriteRevision).id, 2);
      },
    );

    test(
      'a late W1 answer after W2 started only offers its revision',
      () async {
        h.write(false);
        h.calls.single.completeUnanswered();
        await _flush();
        h.retry();
        final oldRetry = h.calls.last;
        h.tracker.observe(false, WriteRevision(id: 2));
        h.write(true);
        h.calls.last.completeUnanswered();
        await _flush();
        oldRetry.complete(
          _answer(
            AdminAnswerOutcome.settingConfirmed,
            value: false,
            revision: 3,
          ),
        );
        await _flush();
        expect(h.tracker.view!.value, isTrue);
        expect(h.tracker.view!.notConfirmed, isTrue);
        expect(h.tracker.view!.canRetry, isTrue);
        expect(h.tracker.view!.notice, isNull);
        expect((h.tracker.view!.revision as WriteRevision).id, 3);
      },
    );

    test(
      'a refused Retry keeps Not confirmed with the refusal beside it',
      () async {
        h.write(false);
        h.calls.single.completeUnanswered();
        await _flush();
        h.retry();
        h.calls.last.complete(_answer(AdminAnswerOutcome.adminBusy));
        await _flush();
        expect(h.tracker.view!.value, isFalse);
        expect(h.tracker.view!.notConfirmed, isTrue);
        expect(h.tracker.view!.canRetry, isTrue);
        expect(h.tracker.view!.notice, AdminAnswerOutcome.adminBusy);
        h.retry();
        h.calls.last.complete(
          _answer(
            AdminAnswerOutcome.settingConfirmed,
            value: false,
            revision: 2,
          ),
        );
        await _flush();
        expect(h.tracker.view!.notConfirmed, isFalse);
        expect(h.tracker.view!.value, isFalse);
      },
    );

    test('a status read at revision R shows the stored value and keeps Not confirmed', () async {
      h.write(false);
      h.calls.single.completeUnanswered();
      await _flush();
      h.retry();
      h.calls.last.complete(_answer(AdminAnswerOutcome.adminBusy));
      await _flush();
      h.tracker.observe(true, WriteRevision(id: 1));
      expect(h.tracker.view!.value, isTrue);
      expect(h.tracker.view!.notConfirmed, isTrue);
      expect(h.tracker.view!.canRetry, isTrue);
      h.tracker.observe(false, WriteRevision(id: 2));
      expect(h.tracker.view!.notConfirmed, isFalse);
      expect(h.tracker.view!.value, isFalse);
    });

    test('setting changed shows the stored value and its message', () async {
      h.write(false);
      h.calls.single.complete(
        _answer(AdminAnswerOutcome.settingChanged, value: true, revision: 2),
      );
      await _flush();
      expect(h.tracker.view!.value, isTrue);
      expect(h.tracker.view!.notice, AdminAnswerOutcome.settingChanged);
      expect((h.tracker.view!.revision as WriteRevision).id, 2);
    });

    test('admin busy on a first toggle restores the switch', () async {
      h.write(false);
      h.calls.single.complete(_answer(AdminAnswerOutcome.adminBusy));
      await _flush();
      expect(h.tracker.view!.value, isTrue);
      expect(h.tracker.view!.notice, AdminAnswerOutcome.adminBusy);
      expect(h.tracker.view!.canRetry, isFalse);
    });

    test('a lost or not-confirmed toggle shows Not confirmed with Retry resending the same write', () async {
      for (final lost in [true, false]) {
        final fixture = _Harness();
        fixture.write(false);
        if (lost) {
          fixture.calls.single.completeUnanswered();
        } else {
          fixture.calls.single.complete(
            _answer(AdminAnswerOutcome.settingNotConfirmed),
          );
        }
        await _flush();
        expect(fixture.tracker.view!.notConfirmed, isTrue);
        expect(fixture.tracker.view!.value, isFalse);
        fixture.retry();
        expect(fixture.calls, hasLength(2));
        expect(fixture.calls.last.id, fixture.calls.first.id);
        expect(fixture.calls.last.value, fixture.calls.first.value);
        expect((fixture.calls.last.revision as WriteRevision).id, 1);
        fixture.calls.last.complete(
          _answer(
            AdminAnswerOutcome.settingConfirmed,
            value: false,
            revision: 2,
          ),
        );
        await _flush();
        fixture.tracker.dispose();
      }
    });

    test('retry waits for transport settlement and late settlement updates the view', () async {
      h.write(false);
      h.calls.single.answerOnlyUnanswered();
      await _flush();
      expect(h.tracker.view!.notConfirmed, isTrue);
      expect(h.tracker.view!.canRetry, isFalse);
      h.retry();
      expect(h.calls, hasLength(1));
      final changes = h.changes;
      h.calls.single.settleUnanswered();
      await _flush();
      expect(h.tracker.view!.canRetry, isTrue);
      expect(h.changes, greaterThan(changes));
    });

    test(
      'disposed trackers neither notify nor send on outstanding completion',
      () async {
        h.write(false);
        final changes = h.changes;
        h.tracker.dispose();
        h.calls.single.complete(_answer(AdminAnswerOutcome.notAuthorized));
        await _flush();
        h.retry();
        h.write(true);
        expect(h.changes, changes);
        expect(h.refusals, isEmpty);
        expect(h.calls, hasLength(1));
      },
    );

    test(
      'a late refused retry does not disturb a replacement write or key',
      () async {
        h.write(false);
        h.calls.single.completeUnanswered();
        await _flush();
        h.retry();
        final oldRetry = h.calls.last;
        h.tracker.observe(false, WriteRevision(id: 2));
        h.write(true);
        h.calls.last.completeUnanswered();
        await _flush();
        oldRetry.complete(_answer(AdminAnswerOutcome.notAuthorized));
        await _flush();
        expect(h.tracker.view!.value, isTrue);
        expect(h.tracker.view!.notConfirmed, isTrue);
        expect(h.tracker.view!.canRetry, isTrue);
        expect(h.tracker.view!.notice, isNull);
        expect(h.refusals, isEmpty);
      },
    );

    test(
      'a current authentication refusal carries the sending key session',
      () async {
        h.write(false);
        h.calls.single.complete(_answer(AdminAnswerOutcome.notAuthorized));
        await _flush();
        expect(h.refusals, [(AdminAnswerOutcome.notAuthorized, 7)]);
        expect(h.tracker.view!.value, isTrue);
      },
    );

    test(
      'an old busy refusal leaves a newer uncertain write unchanged',
      () async {
        h.write(false);
        h.calls.single.completeUnanswered();
        await _flush();
        h.retry();
        final oldRetry = h.calls.last;
        h.tracker.observe(false, WriteRevision(id: 2));
        h.write(true);
        h.calls.last.completeUnanswered();
        await _flush();
        oldRetry.complete(_answer(AdminAnswerOutcome.adminBusy));
        await _flush();
        expect(h.tracker.view!.value, isTrue);
        expect(h.tracker.view!.notConfirmed, isTrue);
        expect(h.tracker.view!.canRetry, isTrue);
        expect(h.tracker.view!.notice, isNull);
      },
    );

    test('NoWrites is fenced by the first committed revision', () async {
      final tracker = AdminSettingTracker(
        newId: () => 'first',
        onChanged: () {},
        onRefusal: (_, _) {},
      );
      final calls = <_Call>[];
      tracker.observe(true, NoWrites());
      tracker.write(
        false,
        authorityEpoch: 1,
        send: (value, revision, id) {
          final call = _Call(value, revision, id);
          calls.add(call);
          return (answer: call.answer.future, settled: call.settled.future);
        },
      );
      expect(calls.single.revision, isA<NoWrites>());
      calls.single.completeUnanswered();
      await _flush();
      tracker.observe(false, WriteRevision(id: 1));
      expect(tracker.view!.notConfirmed, isFalse);
      expect(tracker.view!.value, isFalse);
      tracker.dispose();
    });

    test('a late confirmed transport settles an unanswered write', () async {
      h.write(false);
      h.calls.single.answerOnlyUnanswered();
      await _flush();
      h.calls.single.settled.complete(
        RpcAnswered(
          _answer(
            AdminAnswerOutcome.settingConfirmed,
            value: false,
            revision: 2,
          ),
        ),
      );
      await _flush();
      expect(h.tracker.view!.notConfirmed, isFalse);
      expect(h.tracker.view!.value, isFalse);
      expect((h.tracker.view!.revision as WriteRevision).id, 2);
    });
  });
}

AdminAnswer _answer(AdminAnswerOutcome outcome, {bool? value, int? revision}) =>
    AdminAnswer(
      outcome: outcome,
      autoUpdate: value,
      settingRevision: revision == null ? null : WriteRevision(id: revision),
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _Harness {
  _Harness() {
    tracker = AdminSettingTracker(
      newId: () => 'write-${++ids}',
      onChanged: () => changes++,
      onRefusal: (answer, session) => refusals.add((answer.outcome, session)),
    );
    tracker.observe(true, WriteRevision(id: 1));
  }

  late final AdminSettingTracker tracker;
  final calls = <_Call>[];
  final refusals = <(AdminAnswerOutcome, int)>[];
  int ids = 0;
  int changes = 0;

  RpcCall<AdminAnswer> send(bool value, SettingRevision revision, String id) {
    final call = _Call(value, revision, id);
    calls.add(call);
    return (answer: call.answer.future, settled: call.settled.future);
  }

  void write(bool value) => tracker.write(value, authorityEpoch: 7, send: send);
  void retry() => tracker.retry(authorityEpoch: 7, send: send);
}

final class _Call {
  _Call(this.value, this.revision, this.id);

  final bool value;
  final SettingRevision revision;
  final String id;
  final answer = Completer<RpcResult<AdminAnswer>>();
  final settled = Completer<RpcResult<AdminAnswer>>();

  void complete(AdminAnswer value) {
    answer.complete(RpcAnswered(value));
    settled.complete(RpcAnswered(value));
  }

  void completeUnanswered() {
    answerOnlyUnanswered();
    settleUnanswered();
  }

  void answerOnlyUnanswered() => answer.complete(const RpcUnanswered());
  void settleUnanswered() => settled.complete(const RpcUnanswered());
}
