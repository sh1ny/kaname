import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_app/settings/ui/static_data_section.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart' as local;
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../support/pump_shell.dart';
import 'support/bundle_fixture.dart';
import 'support/static_data_admin_widget_cases.dart';

final _reconnect = DateTime(2026, 1, 1, 12, 0, 30);
final _retry = DateTime(2026, 1, 1, 12, 1);
const _next = BundleIdentity(build: 102, sha256: 'next');

class _Bundle extends StaticDataNotifier {
  _Bundle(this.initial);
  final local.StaticDataState initial;

  @override
  local.StaticDataState build() => initial;

  @override
  void downloadNow() {
    state = local.NoBundle(
      const local.Downloading(),
      announced: state.announced,
      connection: state.connection,
      download: const local.DownloadInProgress(),
    );
  }
}

class _Status extends ServerStaticDataStatusNotifier {
  _Status(this.initial);
  final ServerStaticDataStatusState initial;

  @override
  ServerStaticDataStatusState build() => initial;

  @override
  void refresh() => state = StatusShown(_snapshot());
}

StaticDataStatus _snapshot({
  bool staged = false,
  bool worker = false,
  bool recovery = false,
  bool startup = false,
  bool settlement = false,
}) => StaticDataStatus(
  activeBuild: staged ? 101 : 102,
  previousBuild: staged ? null : 101,
  stagedBuild: staged ? 102 : null,
  buildRevision: 2,
  settingRevision: NoWrites(),
  autoUpdate: !staged,
  busy: false,
  adminConfigured: false,
  workerStuck: worker,
  recoveryStuck: recovery,
  startupStuck: startup,
  settlementStuck: settlement,
  ccpLatest: StaticDataCcpLatest(build: 102, checkedAt: _reconnect),
  latestCheck: StaticDataCheckStatus(
    checkedAt: _reconnect,
    outcome: SdeCheckOutcome.switched,
  ),
);

local.BundleReady _bundle({
  local.ConnectionState connection = const local.Connected(),
  local.DownloadState download = const local.UpToDate(),
  local.LastDownload last = const local.NoDownloadYet(),
  bool announced = true,
}) {
  final copy = fixtureBundle(101);
  final result = openBundle(
    copy.bytes,
    build: 101,
    sha256: copy.identity.sha256,
  );
  final bundle = switch (result) {
    BundleOpened(:final bundle) => bundle,
    BundleRefused(:final refusal) => fail('Bundle fixture refused: $refusal'),
  };
  return local.BundleReady(
    identity: copy.identity,
    bundle: bundle,
    index: SearchIndex.of(bundle),
    updating: download is local.DownloadInProgress,
    announced: announced ? _next : null,
    connection: connection,
    download: download,
    lastDownload: last,
  );
}

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  local.StaticDataState? bundle,
  ServerStaticDataStatusState? status,
  bool configured = true,
}) async {
  setWindowSize(tester, const Size(390, 950));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverTargetProvider.overrideWithValue(
          configured
              ? ConfiguredServer(Uri.parse('http://localhost:8080/'))
              : const NoServer(),
        ),
        staticDataProvider.overrideWith(() => _Bundle(bundle ?? _bundle())),
        serverStaticDataStatusProvider.overrideWith(
          () => _Status(status ?? StatusShown(_snapshot())),
        ),
      ],
      child: MaterialApp(
        theme: EmberTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  staticDataAdminWidgetCases();
  const section = StaticDataSection();
  testWidgets('Up to date: announced build, connection and download', (
    t,
  ) async {
    await _show(t, section);
    expect(find.text('Build 101'), findsWidgets);
    expect(find.text('Build 102'), findsWidgets);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
  });
  testWidgets('Waiting after a failed download: time and reason', (t) async {
    await _show(
      t,
      section,
      bundle: _bundle(
        download: local.WaitingToRetry(_retry, local.DownloadFailure.network),
      ),
    );
    expect(find.textContaining('Waiting to retry at 12:01:00'), findsOneWidget);
    expect(find.textContaining('network error'), findsOneWidget);
  });
  testWidgets('Format too new: names the upgrade', (t) async {
    await _show(
      t,
      section,
      bundle: _bundle(
        download: const local.Stopped(local.DownloadStopReason.appUpdateNeeded),
      ),
    );
    expect(find.text('App update needed'), findsOneWidget);
  });
  testWidgets('Stream down: names next reconnect', (t) async {
    await _show(
      t,
      section,
      bundle: _bundle(connection: local.StreamDown(_reconnect)),
    );
    expect(
      find.text('Server unreachable, retrying at 12:00:30'),
      findsOneWidget,
    );
  });
  testWidgets('Reconnect in flight: no passed time, download waits', (t) async {
    await _show(
      t,
      section,
      bundle: _bundle(
        connection: const local.Reconnecting(),
        download: local.WaitingToRetry(_retry, local.DownloadFailure.network),
      ),
    );
    expect(find.text('Server unreachable, reconnecting'), findsOneWidget);
    expect(find.textContaining('12:01:00'), findsOneWidget);
    expect(
      find.textContaining('12:00:30', findRichText: true),
      findsWidgets,
    ); // Server check still shows its time.
    expect(find.text('Download now'), findsOneWidget);
  });
  testWidgets('Stream down while a download waits: independent times', (
    t,
  ) async {
    await _show(
      t,
      section,
      bundle: _bundle(
        connection: local.StreamDown(_reconnect),
        download: local.WaitingToRetry(_retry, local.DownloadFailure.refused),
      ),
    );
    expect(
      find.text('Server unreachable, retrying at 12:00:30'),
      findsOneWidget,
    );
    expect(find.textContaining('12:01:00'), findsOneWidget);
    expect(find.text('Download now'), findsOneWidget);
  });
  testWidgets('No server configured: no polling action', (t) async {
    await _show(t, section, configured: false);
    expect(find.text('No server configured'), findsWidgets);
    expect(find.text('Refresh'), findsNothing);
  });
  testWidgets('Download stored: names build and time', (t) async {
    await _show(
      t,
      section,
      bundle: _bundle(last: local.DownloadSucceeded(102, _retry, 1)),
    );
    expect(find.text('Build 102 stored at 12:01'), findsOneWidget);
  });
  testWidgets('Download now pressed: replaces retry with downloading', (
    t,
  ) async {
    await _show(
      t,
      section,
      bundle: _bundle(
        download: local.WaitingToRetry(_retry, local.DownloadFailure.network),
      ),
    );
    await t.tap(find.text('Download now'));
    await t.pump();
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('Download now'), findsNothing);
  });
  testWidgets('Nothing to download: no download action', (t) async {
    await _show(t, section);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Download now'), findsNothing);
  });
  testWidgets('Status shown: build identities and check result', (t) async {
    await _show(t, section);
    for (final value in ['Build 101', 'Build 102', 'CCP latest']) {
      expect(find.text(value), findsWidgets);
    }
    expect(find.textContaining('Switched'), findsOneWidget);
    expect(find.textContaining('12:00:30'), findsWidgets);
  });
  testWidgets('Newer build waiting: staged and auto-update off', (t) async {
    await _show(t, section, status: StatusShown(_snapshot(staged: true)));
    expect(find.text('Build 102, waiting to be switched to'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });
  testWidgets('Status unavailable: bundle stays and Refresh retries', (
    t,
  ) async {
    await _show(t, section, status: const StatusUnavailable());
    expect(find.text('Server status unavailable'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('localhost'), findsNothing);
    await t.tap(find.text('Refresh'));
    await t.pump();
    expect(find.text('Server status unavailable'), findsNothing);
    expect(find.text('CCP latest'), findsOneWidget);
  });
  for (final (label, snapshot) in [
    ('Worker stuck', _snapshot(worker: true)),
    ('Recovery stuck', _snapshot(recovery: true)),
    ('Start-up stuck', _snapshot(startup: true)),
    ('Settlement stuck', _snapshot(settlement: true)),
  ]) {
    testWidgets('$label: restart is stated in text', (t) async {
      await _show(t, section, status: StatusShown(snapshot));
      expect(find.text('$label, restart the server'), findsOneWidget);
    });
  }
}
