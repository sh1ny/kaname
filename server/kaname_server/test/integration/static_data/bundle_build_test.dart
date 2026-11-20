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
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

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

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await resetStore(session);
      scratch = await Directory.systemTemp.createTemp('kaname_bundle_build_');
      addTearDown(() => scratch.delete(recursive: true));
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

        ccpAnnounces(2901);
        final result = await checkThrough(harness);

        // Group 7 adds here: the announcer, reacting to this
        // `BuildCheckFinished`, announces build 2901's bundle.
        expect(result, isA<BuildSwitched>());
        expect((result as BuildSwitched).build, 2901);
        final fresh = await expectCurrentBundle(2901);
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

      final result = await checkThrough(harness);

      // Group 7 adds here: the announcer, reacting to this
      // `BuildCheckFinished`, announces build 3100's bundle.
      expect(result, isA<BuildSwitched>());
      expect((result as BuildSwitched).replacedBuild, isNull);
      await expectCurrentBundle(3100);
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

      final result = await checkThrough(harness);

      // Group 7 adds here: the announcer, reacting to this
      // `BuildCheckFinished`, announces the rebuilt bundle.
      expect(result, isA<BuildUpToDate>());
      final after = await expectCurrentBundle(3200);
      expect(after.builtAt.isAfter(before.builtAt), isTrue);
      expect(after.sha256, before.sha256);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
