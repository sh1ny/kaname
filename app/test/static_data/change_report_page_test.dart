import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/settings/logic/change_report_source.dart';
import 'package:kaname_app/settings/ui/change_report_page.dart';
import 'package:kaname_app/shell/logic/router.dart';
import 'package:kaname_app/static_data/data/report_client.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../server/fake_server_health.dart';
import '../support/fake_browser_history.dart';
import '../support/pump_shell.dart';

class _Client implements StaticDataReportClient {
  _Client(this.answers);
  final List<ReportRead> answers;
  int reads = 0;
  @override
  Future<ReportRead> read() async =>
      answers[(reads++).clamp(0, answers.length - 1)];
}

class _StallingClient implements StaticDataReportClient {
  final first = Completer<ReportRead>();
  int reads = 0;

  @override
  Future<ReportRead> read() {
    reads++;
    return reads == 1 ? first.future : Future.value(_ready(_file()));
  }
}

StaticDataReportChanges _changes(
  int count,
  List<String> keys, {
  bool cutOff = false,
}) => StaticDataReportChanges(count: count, keys: keys, cutOff: cutOff);

StaticDataReportFile _file({
  String name = 'types',
  List<String> keys = const ['key-1'],
  int count = 3,
  bool cutOff = false,
  String field = 'volume',
  bool fieldsCutOff = false,
}) => StaticDataReportFile(
  file: name,
  status: StaticDataReportFileStatus.both,
  added: _changes(2, ['added-1', 'added-2']),
  removed: _changes(1, ['removed-1']),
  changed: _changes(count, keys, cutOff: cutOff),
  changedFields: {field: 3},
  changedFieldCount: 1,
  changedFieldsCutOff: fieldsCutOff,
);

ReportRead _ready(StaticDataReportFile file) => ReportReceived(
  StaticDataChangeReport(
    outcome: StaticDataReportOutcome.reportReady,
    activeBuild: 12,
    fromBuild: 11,
    toBuild: 12,
    files: [file],
  ),
);

Future<void> _pump(
  WidgetTester tester,
  StaticDataReportClient client, {
  Size size = const Size(800, 900),
}) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [changeReportClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: EmberTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ChangeReportPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 300,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Report shown', (tester) async {
    final client = _Client([_ready(_file())]);
    await _pump(tester, client);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('types'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    await _scrollTo(tester, find.text('volume'));
    expect(find.text('volume'), findsOneWidget);
    await _scrollTo(tester, find.text('key-1'));
    expect(find.text('key-1'), findsOneWidget);
    expect(client.reads, 1);
  });

  testWidgets('Keys cut off', (tester) async {
    final keys = List.generate(1000, (i) => 'changed-key-$i');
    await _pump(
      tester,
      _Client([
        _ready(
          _file(keys: keys, count: 5000, cutOff: true, fieldsCutOff: true),
        ),
      ]),
    );
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('List cut off'), findsWidgets);
    await _scrollTo(tester, find.text('Changed keys (5000)'));
    expect(find.text('List cut off'), findsWidgets);
    await _scrollTo(tester, find.text('changed-key-999'));
    expect(find.text('changed-key-999'), findsOneWidget);
  });

  testWidgets('No report', (tester) async {
    for (final (outcome, message) in [
      (StaticDataReportOutcome.noPreviousBuild, 'No previous build to compare'),
      (StaticDataReportOutcome.reportMissing, 'No report was stored'),
      (StaticDataReportOutcome.comparisonFailed, 'The comparison failed'),
      (
        StaticDataReportOutcome.reportTooLarge,
        'The report is too large to show',
      ),
    ]) {
      await _pump(
        tester,
        _Client([
          ReportReceived(
            StaticDataChangeReport(
              outcome: outcome,
              reason: PublicReason.timedOut,
            ),
          ),
        ]),
      );
      expect(find.text(message), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Server unreachable', (tester) async {
    for (final answer in [
      const ReportUnavailable(),
      ReportReceived(
        StaticDataChangeReport(outcome: StaticDataReportOutcome.reportBusy),
      ),
    ]) {
      final client = _Client([answer, _ready(_file())]);
      await _pump(tester, client);
      expect(find.text('The report is unavailable'), findsOneWidget);
      expect(find.text('No report was stored'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('types'), findsOneWidget);
      expect(client.reads, 2);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Narrow window', (tester) async {
    final name = 'f' * 120;
    final field = 'v' * 120;
    await _pump(
      tester,
      _Client([_ready(_file(name: name, field: field))]),
      size: const Size(390, 800),
    );
    await _scrollTo(tester, find.text(field));
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .every((s) => s.axis == Axis.vertical),
      isTrue,
    );
  });

  testWidgets('Long key lists', (tester) async {
    final keys = List.generate(20000, (i) => 'long-key-$i');
    await _pump(
      tester,
      _Client([_ready(_file(keys: keys, count: keys.length))]),
    );
    expect(find.text('20000'), findsOneWidget);
    expect(find.text('long-key-19999'), findsNothing);
    await _scrollTo(tester, find.text('Changed keys (20000)'));
    expect(find.text('long-key-19999'), findsNothing);
    await _scrollTo(tester, find.text('long-key-0'));
    expect(find.text('long-key-0'), findsOneWidget);
  });

  testWidgets('Report request stalls', (tester) async {
    final client = _StallingClient();
    await _pump(tester, client);
    expect(find.text('Loading the report…'), findsOneWidget);
    client.first.complete(const ReportUnavailable());
    await tester.pumpAndSettle();
    expect(find.text('The report is unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('types'), findsOneWidget);
    expect(client.reads, 2);
  });

  testWidgets('Back from the report', (tester) async {
    final history = FakeBrowserHistory(tester);
    final health = FakeServerHealth();
    final harness = await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      target: ConfiguredServer(Uri.parse('http://localhost:8080/')),
      browserHistory: history,
      health: health,
    );
    health.answer(
      HealthReport(
        version: '1',
        postgres: DependencyStatus.up,
        redis: DependencyStatus.up,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openReport() async {
      final link = find.text('View change report');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(history.current, staticDataReportPath);
      expect(find.text('Change report'), findsOneWidget);
    }

    await openReport();
    await tester.tap(find.text('Back to Settings'));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/settings');
    await openReport();
    await history.pressBack();
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/settings');
  });

  testWidgets('Opened by its address', (tester) async {
    final harness = await pumpShell(
      tester,
      location: staticDataReportPath,
      size: const Size(1440, 900),
    );
    await tester.tap(find.text('Back to Settings'));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/settings');
  });
}
