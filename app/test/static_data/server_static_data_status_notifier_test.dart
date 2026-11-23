import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_app/static_data/data/status_client.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart';
import 'package:kaname_client/kaname_client.dart';

StaticDataStatus snapshot({bool busy = false, int? build, int? staged}) =>
    StaticDataStatus(
      activeBuild: build,
      stagedBuild: staged,
      latestCheck: staged == null
          ? null
          : StaticDataCheckStatus(
              checkedAt: DateTime.utc(2026),
              latestBuild: staged,
              outcome: SdeCheckOutcome.staged,
            ),
      buildRevision: 1,
      settingRevision: NoWrites(),
      autoUpdate: true,
      adminConfigured: true,
      busy: busy,
      workerStuck: false,
      settlementStuck: false,
      recoveryStuck: false,
      startupStuck: false,
    );

class FakeStatusClient implements StaticDataStatusClient {
  final calls = <Completer<RpcResult<StaticDataStatus>>>[];
  final answers = <Completer<RpcResult<StaticDataStatus>>>[];

  @override
  RpcCall<StaticDataStatus> read() {
    final answer = Completer<RpcResult<StaticDataStatus>>();
    final settled = Completer<RpcResult<StaticDataStatus>>();
    answers.add(answer);
    calls.add(settled);
    return (answer: answer.future, settled: settled.future);
  }

  void complete(StaticDataStatus status) {
    final result = RpcAnswered(status);
    answers.last.complete(result);
    calls.last.complete(result);
  }

  void fail() {
    const result = RpcUnanswered<StaticDataStatus>();
    answers.last.complete(result);
    calls.last.complete(result);
  }
}

class FakeStaticDataNotifier extends StaticDataNotifier {
  @override
  StaticDataState build() => const NoBundle(Starting());

  void announce(int build) => state = NoBundle(
    const Starting(),
    announced: BundleIdentity(build: build, sha256: 'hash'),
  );
}

ProviderContainer statusContainer(FakeStatusClient client) => ProviderContainer(
  overrides: [
    staticDataStatusClientProvider.overrideWithValue(client),
    staticDataProvider.overrideWith(FakeStaticDataNotifier.new),
  ],
);

void main() {
  testWidgets('Import finishes while watched', (tester) async {
    final client = FakeStatusClient();
    final container = statusContainer(client);
    addTearDown(container.dispose);
    container.read(serverStaticDataStatusProvider);
    container.read(staticDataSettingsVisibleProvider.notifier).setVisible(true);
    client.complete(snapshot(busy: true, build: 1));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 5));
      client.complete(snapshot(busy: i != 7, build: i == 7 ? 2 : 1));
      await tester.pump();
    }
    expect(
      (container.read(
        serverStaticDataStatusProvider,
      ) as StatusShown).status.activeBuild,
      2,
    );
    await tester.pump(const Duration(seconds: 29));
    expect(client.calls.length, 9);
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls.length, 10);
    client.complete(snapshot(build: 2));
    await tester.pump();
    container
        .read(staticDataSettingsVisibleProvider.notifier)
        .setVisible(false);
  });

  testWidgets('Work starts between reads', (tester) async {
    final client = FakeStatusClient();
    final container = statusContainer(client);
    addTearDown(container.dispose);
    container.read(serverStaticDataStatusProvider);
    container.read(staticDataSettingsVisibleProvider.notifier).setVisible(true);
    client.complete(snapshot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    expect(client.calls.length, 1);
    await tester.pump(const Duration(seconds: 1));
    client.complete(snapshot(busy: true, staged: 2));
    await tester.pump();
    expect(
      (container.read(
        serverStaticDataStatusProvider,
      ) as StatusShown).status.latestCheck?.outcome,
      SdeCheckOutcome.staged,
    );
    container
        .read(staticDataSettingsVisibleProvider.notifier)
        .setVisible(false);
  });

  testWidgets('Announcement during a read', (tester) async {
    final client = FakeStatusClient();
    final container = statusContainer(client);
    addTearDown(container.dispose);
    container.read(serverStaticDataStatusProvider);
    container.read(staticDataSettingsVisibleProvider.notifier).setVisible(true);
    final bundles =
        container.read(staticDataProvider.notifier) as FakeStaticDataNotifier;
    bundles.announce(1);
    bundles.announce(2);
    const unanswered = RpcUnanswered<StaticDataStatus>();
    client.answers.first.complete(unanswered);
    await tester.pump();
    expect(client.calls.length, 1);
    client.calls.first.complete(RpcAnswered(snapshot()));
    await tester.pump();
    expect(client.calls.length, 2);
    client.complete(snapshot(build: 2));
    await tester.pump();
    expect(
      (container.read(
        serverStaticDataStatusProvider,
      ) as StatusShown).status.activeBuild,
      2,
    );
    container
        .read(staticDataSettingsVisibleProvider.notifier)
        .setVisible(false);
  });

  testWidgets('Reads fail while busy', (tester) async {
    final client = FakeStatusClient();
    final container = statusContainer(client);
    addTearDown(container.dispose);
    container.read(serverStaticDataStatusProvider);
    container.read(staticDataSettingsVisibleProvider.notifier).setVisible(true);
    client.complete(snapshot(busy: true));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 5));
      client.fail();
      await tester.pump();
    }
    expect(
      container.read(serverStaticDataStatusProvider),
      isA<StatusUnavailable>(),
    );
    await tester.pump(const Duration(minutes: 1));
    expect(client.calls.length, 4);
    container.read(serverStaticDataStatusProvider.notifier).refresh();
    expect(client.calls.length, 5);
    client.complete(snapshot());
    await tester.pump();
    expect(container.read(serverStaticDataStatusProvider), isA<StatusShown>());
    container
        .read(staticDataSettingsVisibleProvider.notifier)
        .setVisible(false);
  });
}
