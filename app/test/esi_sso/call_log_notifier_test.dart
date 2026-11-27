import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/esi_sso/data/call_log_client.dart';
import 'package:kaname_app/esi_sso/logic/call_log.dart';
import 'package:kaname_app/esi_sso/ui/call_log_panel.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

final _fixture = NotifierProvider<_Access, CallLogAccess?>(_Access.new);

final class _Access extends Notifier<CallLogAccess?> {
  @override
  CallLogAccess? build() => null;
  void use(CallLogAccess? source) => state = source;
}

final class _Reader implements CallLogAccess {
  final reply = Completer<EsiCallLogPage>();

  @override
  bool get admin => false;

  @override
  Future<EsiCallLogPage> own(EsiCallLogCursor? after) => reply.future;

  @override
  Future<EsiRouteCountPage> totals() async =>
      fail('member may not read aggregates');
}

void main() {
  test('A reply arrives after sign-out or server change', () async {
    final old = _Reader();
    final current = _Reader();
    final container = ProviderContainer(
      overrides: [
        serverTargetProvider.overrideWithValue(const NoServer()),
        callLogAccessProvider.overrideWith((ref) => ref.watch(_fixture)),
      ],
    );
    addTearDown(container.dispose);
    final access = container.read(_fixture.notifier);
    access.use(old);
    final listener = container.listen(callLogProvider, (_, _) {});
    addTearDown(listener.close);
    final pending = container.read(callLogProvider.notifier).own();
    access.use(null);
    expect(container.read(callLogProvider), isA<CallLogHidden>());
    access.use(current);
    container.read(callLogProvider);
    old.reply.complete(EsiCallLogPage(status: 'ok', rows: []));
    await pending;
    expect(container.read(callLogProvider), isA<CallLogIdle>());
    final newLoad = container.read(callLogProvider.notifier).own();
    current.reply.complete(EsiCallLogPage(status: 'ok', rows: []));
    await newLoad;
    expect(container.read(callLogProvider), isA<CallLogOwn>());
  });

  testWidgets(
    'Member receipts and admin totals are separate and clear at sign-out',
    (tester) async {
      final reader = _Reader();
      final container = ProviderContainer.test(
        overrides: [
          serverTargetProvider.overrideWithValue(const NoServer()),
          callLogAccessProvider.overrideWith((ref) => ref.watch(_fixture)),
        ],
      );
      final access = container.read(_fixture.notifier);
      access.use(reader);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: EmberTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CallLogPanel()),
          ),
        ),
      );
      expect(find.text('Server totals by route'), findsNothing);
      await tester.tap(find.text('My calls'));
      final time = DateTime.utc(2026, 11, 25);
      reader.reply.complete(
        EsiCallLogPage(
          status: 'ok',
          rows: [
            EsiCallLogReceipt(
              cursor: EsiCallLogCursor(recordedAt: time, id: '1'),
              recordedAt: time,
              characterId: '42',
              operation: 'SyntheticOwnOperation',
              outcome: 'success',
              latencyMicros: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SyntheticOwnOperation'), findsOneWidget);
      access.use(_AdminReader());
      await tester.pumpAndSettle();
      expect(find.text('SyntheticOwnOperation'), findsNothing);
      await tester.tap(find.text('Server totals by route'));
      await tester.pumpAndSettle();
      expect(find.text('SyntheticAggregateOperation'), findsOneWidget);
      expect(find.text('Calls: 5 · Errors: 1'), findsOneWidget);
      access.use(null);
      await tester.pumpAndSettle();
      expect(find.text('SyntheticAggregateOperation'), findsNothing);
      expect(find.text('ESI call log'), findsNothing);
    },
  );
}

final class _AdminReader implements CallLogAccess {
  @override
  bool get admin => true;

  @override
  Future<EsiCallLogPage> own(EsiCallLogCursor? after) async =>
      fail('admin only asked to read aggregates');

  @override
  Future<EsiRouteCountPage> totals() async => EsiRouteCountPage(
    status: 'ok',
    rows: [
      EsiRouteCount(
        operation: 'SyntheticAggregateOperation',
        total: 5,
        errors: 1,
      ),
    ],
  );
}
