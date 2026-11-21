import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show
        BundleBuildException,
        BundleSection,
        BuiltBundle,
        bundleFormatMajor,
        bundleFormatMinor;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/sde_bundle_support.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Where these tests write the zip and the announced build number that the
/// worker isolate's fake CCP serves. The isolate shares the process id.
String get _ccpDir => '${Directory.systemTemp.path}/kaname_bundle_build_$pid';

/// CCP's service as a fake: `latest.jsonl` names the build in `announce` and
/// the zip is `sde.zip`. Top-level because it crosses into the worker
/// isolate.
SdeSource fakeCcpFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) {
  final build = int.parse(File('$_ccpDir/announce').readAsStringSync());
  final zip = File('$_ccpDir/sde.zip').readAsBytesSync();
  return CcpSdeSource(
    scratchRoot: scratchRoot,
    client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('latest.jsonl')) {
        return http.Response(
          '{"_key":"sde","buildNumber":$build,'
          '"releaseDate":"2026-01-01T00:00:00Z"}\n',
          200,
        );
      }
      if (path.endsWith('-$build-jsonl.zip')) {
        return http.Response.bytes(zip, 200);
      }
      return http.Response('', 404);
    }),
  );
}

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;
    late Directory scratch;
    TestAnnouncer? announced;

    setUp(() async {
      announced = null;
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await resetStore(session);
      scratch = await Directory.systemTemp.createTemp('kaname_bundle_build_');
      addTearDown(() => scratch.delete(recursive: true));
      addTearDown(() async => announced?.announcer.stop());
    });

    /// Makes the fake CCP announce [build] with a complete fixture zip.
    void ccpAnnounces(int build) {
      Directory(_ccpDir).createSync(recursive: true);
      File('$_ccpDir/announce').writeAsStringSync('$build');
      File('$_ccpDir/sde.zip')
          .writeAsBytesSync(SdeFixture.complete(build: build).toZip());
      addTearDown(() {
        if (Directory(_ccpDir).existsSync()) {
          Directory(_ccpDir).deleteSync(recursive: true);
        }
      });
    }

    Future<WorkerHarness> worker() async {
      final harness = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: fakeCcpFactory,
      );
      addTearDown(harness.close);
      return harness;
    }

    /// Runs a check through [harness] and returns its typed result.
    Future<BuildCheckResult> checkThrough(WorkerHarness harness) async {
      final reply = await harness.runBuildCheck(const CcpLatestSource());
      expect(reply, isA<BuildCheckFinished>(), reason: '$reply');
      // The server's start hook and daily call hand the reply on.
      await announced?.reply(reply);
      return (reply as BuildCheckFinished).result;
    }

    /// Expects [build]'s bundle built in the current format with one byte
    /// row of its recorded hash and size, and returns its metadata.
    Future<SdeBundle> expectCurrentBundle(int build) async {
      final row = await bundleRowOf(session, build);
      expect(row, isNotNull, reason: 'no bundle stored for $build');
      expect(row!.outcome, SdeBundleOutcome.built, reason: row.reason);
      expect(
        (row.formatMajor, row.formatMinor),
        (bundleFormatMajor, bundleFormatMinor),
      );
      final bytes = await bundleBytesOf(session, build);
      expect(bytes, isNotNull);
      expect(row.size, bytes!.length);
      return row;
    }

    // Scenario: Every stored build has its bundle / Switch to a new build
    // (D1, C11).
    test(
      'switch stores the new bundle before the switch and keeps the old one',
      () async {
        final harness = await worker();
        ccpAnnounces(2900);
        expect(await checkThrough(harness), isA<BuildSwitched>());
        final old = await expectCurrentBundle(2900);
        announced = await TestAnnouncer.start(session);
        expect(announced!.lastNamed.build, 2900);

        // A second connection holds sde_bundle, so the bundle write waits
        // at its transaction; a third watches the builds meanwhile.
        Future<pg.Connection> connect() => pg.Connection.open(
          pg.Endpoint(
            host: settings.host,
            port: settings.port,
            database: settings.database,
            username: settings.user,
            password: settings.password,
            isUnixSocket: settings.isUnixSocket,
          ),
          settings: pg.ConnectionSettings(sslMode: pg.SslMode.disable),
        );
        final locker = await connect();
        addTearDown(locker.close);
        final observer = await connect();
        addTearDown(observer.close);
        final locked = Completer<void>();
        final release = Completer<void>();
        final holding = locker.runTx((tx) async {
          await tx.execute('LOCK TABLE "sde_bundle" IN EXCLUSIVE MODE');
          locked.complete();
          await release.future;
        });
        await locked.future;

        ccpAnnounces(2901);
        final checking = checkThrough(harness);
        final deadline = DateTime.now().add(const Duration(minutes: 2));
        while (true) {
          final waiting = await observer.execute(
            'SELECT count(*) FROM pg_locks l '
            'JOIN pg_class c ON c.oid = l.relation '
            "WHERE c.relname = 'sde_bundle' AND NOT l.granted",
          );
          if ((waiting.single.single! as int) > 0) break;
          if (DateTime.now().isAfter(deadline)) {
            fail('the bundle write never reached sde_bundle');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        // While the bundle cannot commit, the old build stays active and no
        // switch to the new one exists.
        final active = await observer.execute(
          'SELECT "build" FROM "sde_build" WHERE "activeMarker" = true',
        );
        expect(active.single.single, 2900);
        final switches = await observer.execute(
          r'SELECT count(*) FROM "sde_switch" WHERE "toBuild" = $1::bigint',
          parameters: [2901],
        );
        expect(switches.single.single, 0);
        release.complete();
        await holding;
        final result = await checking;

        expect(result, isA<BuildSwitched>());
        expect((result as BuildSwitched).build, 2901);
        final fresh = await expectCurrentBundle(2901);
        // The announcer, reacting to the `BuildCheckFinished`, announces
        // build 2901's bundle and still holds 2900's as the previous one.
        expect(announced!.lastNamed.build, 2901);
        expect(announced!.lastNamed.sha256, fresh.sha256);
        expect(announced!.lastNamed.size, fresh.size);
        expect(announced!.announcer.heldBundle(2900, old.sha256!), isNotNull);
        final switched = await SdeSwitch.db.findFirstRow(
          session,
          where: (t) => t.toBuild.equals(2901),
        );
        expect(switched, isNotNull);
        expect(
          fresh.builtAt.isBefore(switched!.at),
          isTrue,
          reason: 'bundle at ${fresh.builtAt}, switch at ${switched.at}',
        );
        // The previous build keeps its bundle, unchanged.
        final kept = await expectCurrentBundle(2900);
        expect((kept.sha256, kept.builtAt), (old.sha256, old.builtAt));
      },
    );

    // Scenario: Bundle build failure does not stop the switch (D10).
    test('failed bundle build is recorded once, switch happens, next check '
        'rebuilds', () async {
      // Build 3000 is active; CCP announces 3001.
      final importer = await PostgresStaticDataStore.open(settings);
      final first = SdeFixture.complete(build: 3000).writeTo(scratch, 'a.zip');
      expect(
        await ImportSdeJob(
          store: importer,
          source: LocalZipSdeSource(first, scratchRoot: scratch),
        ).run(),
        isA<ImportSucceeded>(),
      );
      final next = SdeFixture.complete(build: 3001).writeTo(scratch, 'b.zip');

      var attempts = <int>[];
      Future<BuiltBundle> failing(StaticDataStore store, int build) async {
        attempts.add(build);
        throw const BundleBuildException(
          BundleSection.types,
          'synthetic bundle failure',
        );
      }

      Future<BuildCheckResult> check(BuildBundle buildBundle) async {
        final store = await PostgresStaticDataStore.open(settings);
        return TakeLatestBuildJob(
          store: store,
          source: AnnouncingSource(
            LocalZipSdeSource(next, scratchRoot: scratch),
            3001,
          ),
          differ: store.differ(),
          scratchRoot: scratch,
          buildBundle: buildBundle,
        ).run();
      }

      final failed = await check(failing);

      expect(failed, isA<BuildSwitched>(), reason: '$failed');
      expect(attempts, [3001], reason: 'one attempt in the check');
      final row = await bundleRowOf(session, 3001);
      expect(row!.outcome, SdeBundleOutcome.failed);
      expect(row.reason, contains('synthetic bundle failure'));
      expect(row.sha256, isNull);
      expect(await bundleBytesOf(session, 3001), isNull);
      final active = await SdeBuild.db.findFirstRow(
        session,
        where: (t) => t.state.equals(SdeBuildState.active),
      );
      expect(active!.build, 3001);

      attempts = [];
      Future<BuiltBundle> counting(StaticDataStore store, int build) {
        attempts.add(build);
        return buildStoredBundle(store, build);
      }

      final repaired = await check(counting);

      expect(repaired, isA<BuildUpToDate>(), reason: '$repaired');
      expect(attempts, [3001]);
      await expectCurrentBundle(3001);
    });

    // Scenario: Every stored build has its bundle / First activation (D20).
    test('first activation builds and announces its bundle in the same '
        'check', () async {
      final harness = await worker();
      ccpAnnounces(3100);
      announced = await TestAnnouncer.start(session);
      expect(announced!.announcer.installed, isA<BundleAnnouncementNone>());

      final result = await checkThrough(harness);

      expect(result, isA<BuildSwitched>());
      expect((result as BuildSwitched).replacedBuild, isNull);
      final stored = await expectCurrentBundle(3100);
      // The announcer, reacting to the `BuildCheckFinished`, announces
      // build 3100's bundle.
      expect(announced!.lastNamed.build, 3100);
      expect(announced!.lastNamed.sha256, stored.sha256);
    });

    // Scenario: A bundle of another format version is rebuilt (D20, C12).
    test('other-format bundle is rebuilt and announced', () async {
      final harness = await worker();
      ccpAnnounces(3200);
      expect(await checkThrough(harness), isA<BuildSwitched>());
      final before = await expectCurrentBundle(3200);
      await session.db.unsafeExecute(
        'UPDATE "sde_bundle" SET "formatMajor" = 0 WHERE "build" = 3200',
      );
      announced = await TestAnnouncer.start(session);
      expect(announced!.announcer.installed, isA<BundleAnnouncementNone>());

      final result = await checkThrough(harness);

      expect(result, isA<BuildUpToDate>());
      final after = await expectCurrentBundle(3200);
      expect(after.builtAt.isAfter(before.builtAt), isTrue);
      expect(after.sha256, before.sha256);
      // The announcer, reacting to the `BuildCheckFinished`, announces the
      // rebuilt bundle.
      expect(announced!.lastNamed.build, 3200);
      expect(announced!.lastNamed.sha256, after.sha256);
      expect(announced!.lastNamed.formatMajor, bundleFormatMajor);
    });

    // Pre-ship round 25: metadata whose bytes row is gone is rebuilt.
    test('a bundle whose bytes row is gone is rebuilt and announced', () async {
      final harness = await worker();
      ccpAnnounces(3300);
      expect(await checkThrough(harness), isA<BuildSwitched>());
      final before = await expectCurrentBundle(3300);
      await session.db.unsafeExecute(
        'DELETE FROM "sde_bundle_bytes" WHERE "build" = 3300',
      );
      announced = await TestAnnouncer.start(session);
      expect(announced!.announcer.installed, isA<BundleAnnouncementNone>());

      final result = await checkThrough(harness);

      expect(result, isA<BuildUpToDate>());
      final after = await expectCurrentBundle(3300);
      expect(after.builtAt.isAfter(before.builtAt), isTrue);
      expect(await bundleBytesOf(session, 3300), isNotNull);
      expect(announced!.lastNamed.build, 3300);
      expect(announced!.lastNamed.sha256, after.sha256);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
