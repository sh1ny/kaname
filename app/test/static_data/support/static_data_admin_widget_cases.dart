import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_app/settings/ui/static_data_admin_controls.dart';
import 'package:kaname_app/settings/ui/static_data_public_reason.dart';
import 'package:kaname_app/settings/ui/static_data_section.dart';
import 'package:kaname_app/static_data/data/admin_client.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_app/static_data/logic/admin_session_notifier.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../server_static_data_status_notifier_test.dart'
    show FakeStaticDataNotifier, FakeStatusClient, snapshot;

class _FakeAdmin implements StaticDataAdminClient {
  final keys = <Completer<RpcResult<AdminAnswer>>>[];
  final updates = <Completer<RpcResult<AdminAnswer>>>[];
  final rollbacks = <Completer<RpcResult<AdminAnswer>>>[];
  final reads = <Completer<RpcResult<AdminOperationAnswer>>>[];
  final revisions = <int>[];

  RpcCall<T> _pending<T>(List<Completer<RpcResult<T>>> calls) {
    final pending = Completer<RpcResult<T>>();
    calls.add(pending);
    return (answer: pending.future, settled: pending.future);
  }

  @override
  RpcCall<AdminAnswer> checkKey(String key) => _pending(keys);
  @override
  RpcCall<AdminAnswer> updateNow(String key, String operationId) =>
      _pending(updates);
  @override
  RpcCall<AdminAnswer> rollBack(
    String key,
    String operationId,
    int expectedRevision,
  ) {
    revisions.add(expectedRevision);
    return _pending(rollbacks);
  }

  @override
  RpcCall<AdminAnswer> setAutoUpdate(
    String key,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) => _pending(<Completer<RpcResult<AdminAnswer>>>[]);
  @override
  RpcCall<AdminOperationAnswer> operation(String operationId) =>
      _pending(reads);
}

class _Harness {
  _Harness({this.address = 'http://localhost:8080/', bool configured = true})
    : status = snapshot(build: 20).copyWith(
        previousBuild: 19,
        buildRevision: 4,
        adminConfigured: configured,
      );
  final String address;
  final StaticDataStatus status;
  final api = _FakeAdmin();
  final statusClient = FakeStatusClient();
  late ProviderContainer container;

  Future<void> mount(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        serverTargetProvider.overrideWithValue(
          ConfiguredServer(Uri.parse(address)),
        ),
        staticDataStatusClientProvider.overrideWithValue(statusClient),
        staticDataAdminClientProvider.overrideWithValue(api),
        staticDataProvider.overrideWith(FakeStaticDataNotifier.new),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: EmberTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: StaticDataSection()),
          ),
        ),
      ),
    );
    container.read(staticDataSettingsVisibleProvider.notifier).setVisible(true);
    await tester.pump();
    statusClient.complete(status);
    await tester.pumpAndSettle();
  }

  Future<void> accept(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'secret sentinel');
    await tester.ensureVisible(find.text('Check key'));
    await tester.tap(find.text('Check key'));
    await tester.pump();
    api.keys.last.complete(
      RpcAnswered(AdminAnswer(outcome: AdminAnswerOutcome.keyAccepted)),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pump();
  }

  void dispose() => container.dispose();
}

/// Registers administrator-control widget regressions with the section suite.
void staticDataAdminWidgetCases() {
  testWidgets(
    'an accepted key shows the admin controls and the field shows no characters of it',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
      expect(field.autofillHints, isNull);
      await h.accept(tester);
      expect(find.text('secret sentinel'), findsNothing);
      expect(find.text('Update now'), findsOneWidget);
      h.dispose();
    },
  );
  testWidgets('not configured shows the message and no key field', (
    tester,
  ) async {
    final h = _Harness(configured: false);
    await h.mount(tester);
    expect(
      find.text('Admin actions are not configured on this server.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    h.dispose();
  });
  testWidgets(
    'plain http to another host shows Admin actions need a secure connection and still shows the status',
    (tester) async {
      final h = _Harness(address: 'http://example.com/');
      await h.mount(tester);
      expect(
        find.text('Admin actions need a secure connection.'),
        findsOneWidget,
      );
      expect(find.text('Server status'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      h.dispose();
    },
  );
  testWidgets('http://localhost:8080/ offers the key field', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    expect(find.byType(TextField), findsOneWidget);
    h.dispose();
  });
  testWidgets('an unanswered press hides Update now and Roll back', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.accept(tester);
    await h.tap(tester, 'Update now');
    expect(h.api.updates, hasLength(1));
    expect(find.text('Update now'), findsNothing);
    expect(find.text('Roll back'), findsNothing);
    h.dispose();
  });
  for (final outcome in [
    AdminAnswerOutcome.started,
    AdminAnswerOutcome.noAnswerYet,
  ]) {
    testWidgets(
      outcome == AdminAnswerOutcome.started
          ? 'Update now answered started shows work running, hides the actions and follows'
          : 'no answer yet shows watching the server and follows the job',
      (tester) async {
        final h = _Harness();
        await h.mount(tester);
        await h.accept(tester);
        await h.tap(tester, 'Update now');
        h.api.updates.single.complete(
          RpcAnswered(AdminAnswer(outcome: outcome)),
        );
        await tester.pump();
        expect(
          find.text(
            outcome == AdminAnswerOutcome.started
                ? 'Work running.'
                : 'No answer yet, watching the server',
          ),
          findsOneWidget,
        );
        expect(find.text('Update now'), findsNothing);
        expect(h.api.reads, hasLength(1));
        h.dispose();
      },
    );
  }
  testWidgets(
    'while following, Update now and Roll back are hidden and Waiting for the last action shows',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await h.accept(tester);
      await h.tap(tester, 'Update now');
      h.api.updates.single.complete(
        RpcAnswered(AdminAnswer(outcome: AdminAnswerOutcome.started)),
      );
      await tester.pump();
      expect(find.text('Waiting for the last action.'), findsOneWidget);
      expect(find.text('Roll back'), findsNothing);
      await h.tap(tester, 'Forget key');
      expect(find.text('Waiting for the last action.'), findsOneWidget);
      h.dispose();
    },
  );
  testWidgets('cancelling the rollback confirmation makes no call', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.accept(tester);
    await h.tap(tester, 'Roll back');
    await tester.pumpAndSettle();
    expect(find.textContaining('build 19'), findsOneWidget);
    expect(find.textContaining('build 20'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.api.rollbacks, isEmpty);
    h.dispose();
  });
  testWidgets(
    'a confirmed rollback sends the shown revision and shows N active and N+1 held',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await h.accept(tester);
      await h.tap(tester, 'Roll back');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll back').last);
      await tester.pump();
      expect(h.api.revisions, [4]);
      h.api.rollbacks.single.complete(
        RpcAnswered(
          AdminAnswer(outcome: AdminAnswerOutcome.rolledBack, activeBuild: 19),
        ),
      );
      await tester.pump();
      h.statusClient.complete(
        h.status.copyWith(
          activeBuild: 19,
          previousBuild: 20,
          heldBuild: 20,
          buildRevision: 5,
        ),
      );
      await tester.pump();
      expect(find.text('Active build'), findsOneWidget);
      expect(find.text('Held build'), findsOneWidget);
      expect(find.text('Build 19'), findsOneWidget);
      expect(find.text('Build 20'), findsNWidgets(2));
      expect(find.text('Rolled back.'), findsOneWidget);
      h.dispose();
    },
  );
  testWidgets(
    'rollback failed shows the reason in text and the builds unchanged',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await h.accept(tester);
      await h.tap(tester, 'Roll back');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll back').last);
      await tester.pump();
      h.api.rollbacks.single.complete(
        RpcAnswered(
          AdminAnswer(
            outcome: AdminAnswerOutcome.rollbackFailed,
            reason: PublicReason.switchFailed,
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StaticDataAdminControls)),
      );
      expect(
        find.text(
          'Rollback failed. ${staticDataPublicReason(l10n, PublicReason.switchFailed)}',
        ),
        findsOneWidget,
      );
      expect(find.text('Build 20'), findsOneWidget);
      expect(find.text('Build 19'), findsOneWidget);
      h.dispose();
    },
  );
  testWidgets('rollback shows uncertainty while its outcome is still watched', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.accept(tester);
    await h.tap(tester, 'Roll back');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roll back').last);
    await tester.pump();
    h.api.rollbacks.single.complete(
      RpcAnswered(AdminAnswer(outcome: AdminAnswerOutcome.outcomeUnknown)),
    );
    await tester.pump();
    expect(find.text('Outcome unknown, watching the server'), findsOneWidget);
    expect(find.text('Outcome unknown, check the builds'), findsNothing);
    expect(find.text('Update now'), findsNothing);
    expect(h.api.reads, hasLength(1));
    h.dispose();
  });
  testWidgets(
    'import running, worker not running and update failed show in text and the actions return when idle',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await h.accept(tester);
      for (final (outcome, reason, text) in [
        (AdminAnswerOutcome.importRunning, null, 'An import is running.'),
        (
          AdminAnswerOutcome.workerNotRunning,
          null,
          'The worker is not running.',
        ),
        (
          AdminAnswerOutcome.updateFailed,
          PublicReason.other,
          'Update failed. Failed, see the server log',
        ),
      ]) {
        await h.tap(tester, 'Update now');
        h.api.updates.last.complete(
          RpcAnswered(AdminAnswer(outcome: outcome, reason: reason)),
        );
        await tester.pump();
        expect(find.text(text), findsOneWidget);
        expect(find.text('Update now'), findsOneWidget);
      }
      h.dispose();
    },
  );
}
