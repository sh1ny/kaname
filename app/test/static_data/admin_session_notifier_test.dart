import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_app/static_data/data/admin_client.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_app/static_data/logic/admin_session_notifier.dart';
import 'package:kaname_app/static_data/logic/admin_session_state.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_client/kaname_client.dart';

import 'server_static_data_status_notifier_test.dart'
    show FakeStaticDataNotifier, FakeStatusClient, snapshot;
import 'support/admin_bearer.dart';
import 'support/admin_setting_cases.dart';
import 'support/static_data_fakes.dart' show FakeClock;

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _Pending<T> {
  final _answer = Completer<RpcResult<T>>();
  final _settled = Completer<RpcResult<T>>();

  RpcCall<T> get call => (answer: _answer.future, settled: _settled.future);

  void reply(T value) {
    final result = RpcAnswered(value);
    if (!_answer.isCompleted) _answer.complete(result);
    _settled.complete(result);
  }

  void lose({bool stillOut = false}) {
    final result = RpcUnanswered<T>();
    _answer.complete(result);
    if (!stillOut) _settled.complete(result);
  }
}

final class _Command {
  _Command(this.key, {this.id, this.revision, this.value, this.expected});

  final String key;
  final String? id;
  final int? revision;
  final bool? value;
  final SettingRevision? expected;
  final result = _Pending<AdminAnswer>();

  void answer(AdminAnswerOutcome outcome, {AdminOperationView? operation}) =>
      result.reply(AdminAnswer(outcome: outcome, operation: operation));
}

final class _AdminApi implements StaticDataAdminClient {
  final updates = <_Command>[];
  final rollbacks = <_Command>[];
  final toggles = <_Command>[];
  final reads = <({String id, _Pending<AdminOperationAnswer> result})>[];

  @override
  RpcCall<AdminAnswer> updateNow(String key, String operationId) {
    final command = _Command(key, id: operationId);
    updates.add(command);
    return command.result.call;
  }

  @override
  RpcCall<AdminAnswer> rollBack(
    String key,
    String operationId,
    int expectedRevision,
  ) {
    final command = _Command(key, id: operationId, revision: expectedRevision);
    rollbacks.add(command);
    return command.result.call;
  }

  @override
  RpcCall<AdminAnswer> setAutoUpdate(
    String key,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) {
    final command = _Command(
      key,
      id: writeId,
      value: value,
      expected: expectedRevision,
    );
    toggles.add(command);
    return command.result.call;
  }

  @override
  RpcCall<AdminOperationAnswer> operation(String operationId) {
    final result = _Pending<AdminOperationAnswer>();
    reads.add((id: operationId, result: result));
    return result.call;
  }
}

final class _Fixture {
  _Fixture() {
    var next = 0;
    container = ProviderContainer.test(
      overrides: [
        serverTargetProvider.overrideWithValue(
          ConfiguredServer(Uri.parse('http://localhost:8080/')),
        ),
        staticDataStatusClientProvider.overrideWithValue(status),
        staticDataAdminClientProvider.overrideWithValue(api),
        staticDataProvider.overrideWith(FakeStaticDataNotifier.new),
        staticDataTimersProvider.overrideWithValue(clock.start),
        adminSessionElapsedProvider.overrideWithValue(
          () => clock.now().difference(DateTime.utc(2026)),
        ),
        staticDataAdminBearerProvider.overrideWith(
          (ref) => ref.watch(testBearerProvider),
        ),
        adminRequestIdProvider.overrideWithValue(() => 'operation-${++next}'),
      ],
    );
  }

  final clock = FakeClock();
  final status = FakeStatusClient();
  final api = _AdminApi();
  late final ProviderContainer container;

  AdminSessionNotifier get controller =>
      container.read(adminSessionProvider.notifier);
  AdminSessionState get state => container.read(adminSessionProvider);
  AdminSessionView get view => state.view;

  void setVisible(bool visible) => container
      .read(staticDataSettingsVisibleProvider.notifier)
      .setVisible(visible);

  Future<void> start({bool withKey = true}) async {
    container.read(adminSessionProvider);
    setVisible(true);
    await _flush();
    status.complete(
      snapshot(build: 20).copyWith(previousBuild: 19, buildRevision: 4),
    );
    await _flush();
    if (withKey) await accept('key A');
  }

  Future<void> accept(String key) async {
    container.read(testBearerProvider.notifier).set(key);
    await _flush();
    expect(state, isA<Admin>());
  }

  Future<String> follow({
    bool rollback = false,
    AdminAnswerOutcome outcome = AdminAnswerOutcome.noAnswerYet,
  }) async {
    if (rollback) {
      controller.rollBack(4);
    } else {
      controller.updateNow();
    }
    final send = (rollback ? api.rollbacks : api.updates).last;
    send.answer(outcome);
    await _flush();
    expect(view.job?.following, isTrue);
    return send.id!;
  }

  Future<void> record(
    AdminOperationReadState state, {
    SdeAdminOperationOutcome? outcome,
  }) async {
    api.reads.last.result.reply(
      AdminOperationAnswer(
        state: state,
        operation: outcome == null ? null : _operation(outcome),
      ),
    );
    await _flush();
  }

  Future<void> noRecordYet() async {
    for (var i = 0; i <= 6; i++) {
      await record(AdminOperationReadState.unknownOperation);
      if (i < 6) await clock.elapse(const Duration(seconds: 5));
    }
    expect(view.job?.canRetry, isTrue);
  }
}

AdminOperationView _operation(SdeAdminOperationOutcome outcome) =>
    AdminOperationView(outcome: outcome, changedBuilds: false);

AdminAnswerOutcome? _answer(_Fixture fixture) => switch (fixture.view.message) {
  AdminJobAnswered(:final answer) => answer.outcome,
  _ => null,
};

void main() {
  adminSettingCases();

  test('no answer yet keeps following X until it ends up to date', () async {
    final f = _Fixture();
    await f.start();
    final id = await f.follow();
    expect(_answer(f), AdminAnswerOutcome.noAnswerYet);
    for (var i = 0; i < 4; i++) {
      await f.record(AdminOperationReadState.waiting);
      await f.clock.elapse(const Duration(seconds: 5));
    }
    expect(f.api.reads.map((read) => read.id), everyElement(id));
    await f.record(
      AdminOperationReadState.ended,
      outcome: SdeAdminOperationOutcome.upToDate,
    );
    expect(
      (f.view.message! as AdminJobEnded).operation.outcome,
      SdeAdminOperationOutcome.upToDate,
    );
    expect(f.view.job, isNull);
  });

  for (final unrelatedRollback in [false, true]) {
    test(
      unrelatedRollback
          ? 'X own outcome switched is shown after another admin rollback'
          : 'a repair ending first does not end following X',
      () async {
        final f = _Fixture();
        await f.start();
        final id = await f.follow();
        f.container.read(serverStaticDataStatusProvider.notifier).refresh();
        f.status.complete(
          snapshot(busy: false, build: unrelatedRollback ? 19 : 20).copyWith(
            previousBuild: unrelatedRollback ? 20 : 19,
            buildRevision: 9,
          ),
        );
        await _flush();
        expect(f.view.job?.id, id);
        await f.record(
          AdminOperationReadState.ended,
          outcome: SdeAdminOperationOutcome.switched,
        );
        expect(
          (f.view.message! as AdminJobEnded).operation.outcome,
          SdeAdminOperationOutcome.switched,
        );
      },
    );
  }

  test('an 8 s operation read starts no second read', () async {
    final f = _Fixture();
    await f.start();
    await f.follow();
    await f.clock.elapse(const Duration(seconds: 8));
    expect(f.api.reads, hasLength(1));
    await f.record(AdminOperationReadState.running);
    await f.clock.elapse(const Duration(seconds: 5));
    expect(f.api.reads, hasLength(2));
  });

  test(
    'returning with a read out starts none and uses its answer for X',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow();
      f.api.reads.single.result.lose(stillOut: true);
      f.setVisible(false);
      await f.clock.elapse(const Duration(seconds: 60));
      f.setVisible(true);
      expect(f.api.reads, hasLength(1));
      expect(f.api.reads.single.id, id);
      await f.record(
        AdminOperationReadState.ended,
        outcome: SdeAdminOperationOutcome.upToDate,
      );
      expect(f.view.message, isA<AdminJobEnded>());
      expect(f.view.job, isNull);
    },
  );

  test(
    'the report child suspends operation reads until Settings returns',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow();
      await f.record(AdminOperationReadState.running);
      f.setVisible(false);
      await f.clock.elapse(const Duration(minutes: 1));
      expect(f.api.reads, hasLength(1));
      f.setVisible(true);
      expect(f.api.reads, hasLength(2));
      expect(f.api.reads.last.id, id);
    },
  );

  test('a running answer on return schedules the next read 5 s later inside the limit', () async {
    final f = _Fixture();
    await f.start();
    await f.follow();
    f.setVisible(false);
    await f.clock.elapse(const Duration(minutes: 2));
    f.setVisible(true);
    expect(f.api.reads, hasLength(1));
    await f.record(AdminOperationReadState.running);
    await f.clock.elapse(const Duration(seconds: 4));
    expect(f.api.reads, hasLength(1));
    await f.clock.elapse(const Duration(seconds: 1));
    expect(f.api.reads, hasLength(2));
  });

  test('a running answer 3 s before the limit starts no read and shows outcome unknown at 10 min', () async {
    final f = _Fixture();
    await f.start();
    await f.follow();
    await f.clock.elapse(const Duration(seconds: 597));
    await f.record(AdminOperationReadState.running);
    await f.clock.elapse(const Duration(seconds: 2));
    expect(f.view.job, isNotNull);
    await f.clock.elapse(const Duration(seconds: 1));
    expect(f.api.reads, hasLength(1));
    expect(f.view.message, isA<AdminJobUnknown>());
    expect(f.view.job, isNull);
  });

  for (final ended in [true, false]) {
    test(
      'a read answering after the limit shows ${ended ? 'its ended outcome' : 'outcome unknown'}',
      () async {
        final f = _Fixture();
        await f.start();
        await f.follow();
        f.setVisible(false);
        await f.clock.elapse(const Duration(minutes: 11));
        f.setVisible(true);
        expect(f.view.job, isNotNull);
        expect(f.api.reads, hasLength(1));
        await f.record(
          ended
              ? AdminOperationReadState.ended
              : AdminOperationReadState.running,
          outcome: ended ? SdeAdminOperationOutcome.upToDate : null,
        );
        expect(f.view.job, isNull);
        expect(
          f.view.message,
          ended ? isA<AdminJobEnded>() : isA<AdminJobUnknown>(),
        );
      },
    );
  }

  test('a rollback with no answer before the timeout shows no answer yet and follows X', () async {
    final f = _Fixture();
    await f.start();
    f.controller.rollBack(4);
    f.api.rollbacks.single.result.lose(stillOut: true);
    await _flush();
    expect(_answer(f), AdminAnswerOutcome.noAnswerYet);
    expect(f.view.job?.following, isTrue);
    expect(f.api.reads.single.id, f.api.rollbacks.single.id);
  });

  test(
    'unknown operation for 30 s shows no record yet with Try again resending X',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow();
      expect(f.view.job?.canRetry, isFalse);
      await f.noRecordYet();
      expect(f.view.job?.noRecord, isTrue);
      f.controller.retryJob();
      expect(f.api.updates, hasLength(2));
      expect(f.api.updates.last.id, id);
      expect(f.view.job?.canRetry, isFalse);
    },
  );

  test('following stops at 10 min with outcome unknown', () async {
    final f = _Fixture();
    await f.start();
    await f.follow();
    await f.record(AdminOperationReadState.running);
    f.setVisible(false);
    await f.clock.elapse(const Duration(minutes: 10));
    f.setVisible(true);
    expect(f.view.job, isNull);
    expect(f.view.message, isA<AdminJobUnknown>());
    expect(f.api.reads, hasLength(1));
  });

  test(
    'a resend answered ended rolled back is final and releases the job',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow(rollback: true);
      await f.noRecordYet();
      f.controller.retryJob();
      final resend = f.api.rollbacks.last;
      expect(resend.id, id);
      expect(resend.revision, 4);
      resend.answer(
        AdminAnswerOutcome.ended,
        operation: _operation(SdeAdminOperationOutcome.rolledBack),
      );
      await _flush();
      expect(f.view.job, isNull);
      expect(
        (f.view.message! as AdminJobEnded).operation.outcome,
        SdeAdminOperationOutcome.rolledBack,
      );
    },
  );

  test(
    'builds changed shows its message and reads the status at once',
    () async {
      final f = _Fixture();
      await f.start();
      f.controller.rollBack(4);
      f.api.rollbacks.single.answer(AdminAnswerOutcome.buildsChanged);
      await _flush();
      expect(_answer(f), AdminAnswerOutcome.buildsChanged);
      expect(f.view.job, isNull);
      expect(f.status.calls, hasLength(2));
    },
  );

  test(
    'rollback outcome unknown follows X until it ends or 10 min pass',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow(
        rollback: true,
        outcome: AdminAnswerOutcome.outcomeUnknown,
      );
      expect(_answer(f), AdminAnswerOutcome.outcomeUnknown);
      expect(f.api.reads.single.id, id);
      await f.record(
        AdminOperationReadState.ended,
        outcome: SdeAdminOperationOutcome.rolledBack,
      );
      expect(f.view.job, isNull);
    },
  );

  test('admin busy on a first press releases it and follows nothing', () async {
    final f = _Fixture();
    await f.start();
    f.controller.updateNow();
    f.controller.updateNow();
    expect(f.api.updates, hasLength(1));
    expect(f.view.job?.sending, isTrue);
    f.api.updates.single.answer(AdminAnswerOutcome.adminBusy);
    await _flush();
    expect(_answer(f), AdminAnswerOutcome.adminBusy);
    expect(f.view.job, isNull);
    expect(f.api.reads, isEmpty);
  });

  for (final outcome in [
    AdminAnswerOutcome.ended,
    AdminAnswerOutcome.noAnswerYet,
  ]) {
    test(
      'a late resend answer ${outcome.name} for X after Y was pressed is dropped',
      () async {
        final f = _Fixture();
        await f.start();
        final x = await f.follow();
        await f.noRecordYet();
        f.controller.retryJob();
        final resend = f.api.updates.last;
        await f.clock.elapse(const Duration(seconds: 5));
        await f.record(
          AdminOperationReadState.ended,
          outcome: SdeAdminOperationOutcome.upToDate,
        );
        f.controller.updateNow();
        final y = f.api.updates.last.id;
        expect(y, isNot(x));
        resend.answer(
          outcome,
          operation: _operation(SdeAdminOperationOutcome.upToDate),
        );
        await _flush();
        expect(f.view.job?.id, y);
        expect(f.view.message, isA<AdminJobSending>());
      },
    );
  }

  test(
    'a refused resend shows the refusal beside waiting and does not release X',
    () async {
      final f = _Fixture();
      await f.start();
      final id = await f.follow();
      await f.noRecordYet();
      f.controller.retryJob();
      f.api.updates.last.answer(AdminAnswerOutcome.adminBusy);
      await _flush();
      expect(_answer(f), AdminAnswerOutcome.adminBusy);
      expect(f.view.job?.id, id);
      expect(f.view.job?.following, isTrue);
      f.controller.updateNow();
      expect(f.api.updates, hasLength(2));
      await f.clock.elapse(const Duration(seconds: 5));
      expect(f.api.reads.last.id, id);
    },
  );

  test(
    'a denied admin call drops mutation authority and hides the admin controls',
    () async {
      final f = _Fixture();
      await f.start();
      f.controller.updateNow();
      f.api.updates.single.answer(AdminAnswerOutcome.notAuthorized);
      await _flush();
      expect(f.state, isA<ReadOnlyAdmin>());
      f.controller.updateNow();
      expect(f.api.updates, hasLength(1));
    },
  );

  test(
    'Delayed denial from an older session leaves the new admin authorized',
    () async {
      final f = _Fixture();
      await f.start();
      f.controller.updateNow();
      f.controller.setAutoUpdate(false);
      f.api.updates.single.answer(AdminAnswerOutcome.notAuthorized);
      await _flush();
      expect(f.state, isA<ReadOnlyAdmin>());
      await f.accept('key B');
      f.api.toggles.single.answer(AdminAnswerOutcome.notAuthorized);
      await _flush();
      expect(f.state, isA<Admin>());
      expect(f.view.setting?.saving, isFalse);
      f.controller.updateNow();
      expect(f.api.updates.last.key, 'key B');
    },
  );

  test('a new app session is read-only until signed in', () async {
    final first = _Fixture();
    await first.start();
    final restarted = _Fixture();
    await restarted.start(withKey: false);
    expect(restarted.state, isA<ReadOnlyAdmin>());
  });

  test('a denied setting write drops mutation authority but keeps following the job', () async {
    final f = _Fixture();
    await f.start();
    final id = await f.follow();
    f.controller.setAutoUpdate(false);
    f.api.toggles.single.answer(AdminAnswerOutcome.notAuthorized);
    await _flush();
    expect(f.state, isA<ReadOnlyAdmin>());
    expect(f.view.job?.id, id);
    await f.record(AdminOperationReadState.running);
    await f.clock.elapse(const Duration(seconds: 5));
    expect(f.api.reads.last.id, id);
  });
}
