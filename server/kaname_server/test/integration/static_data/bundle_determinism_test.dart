import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    as bundle;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../support/sde_bundle_support.dart';
import '../test_tools/serverpod_test_tools.dart';

/// The two bundles of one fixture: the server's and the zip builder's.
typedef _Pair = ({
  Uint8List serverBytes,
  String serverSha256,
  bundle.BuiltBundle local,
});

/// Opens [bytes] as the bundle of [build] with [sha256], or fails.
bundle.ClientBundle _open(Uint8List bytes, int build, String sha256) =>
    switch (bundle.openBundle(bytes, build: build, sha256: sha256)) {
      bundle.BundleOpened(bundle: final opened) => opened,
      bundle.BundleRefused(:final refusal) => fail('refused: $refusal'),
    };

void main() {
  withServerpod('Given a migrated database and a fixture zip', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late PostgresConnectionSettings settings;
    late Directory scratch;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await resetStore(session);
      scratch = await Directory.systemTemp.createTemp('kaname_bundle_det_');
      addTearDown(() => scratch.delete(recursive: true));
    });

    /// Runs a build check that announces [build] and reads it from [zip],
    /// as CCP's check would: the server's bundle step builds the bundle.
    Future<BuildCheckResult> check(File zip, int build) async {
      final store = await PostgresStaticDataStore.open(settings);
      return TakeLatestBuildJob(
        store: store,
        source: AnnouncingSource(
          LocalZipSdeSource(zip, scratchRoot: scratch),
          build,
        ),
        differ: store.differ(),
        scratchRoot: scratch,
      ).run();
    }

    /// The bundle the server stored for [build], with its recorded hash.
    Future<({Uint8List bytes, String sha256})> stored(int build) async {
      final row = await bundleRowOf(session, build);
      expect(row, isNotNull, reason: 'no bundle stored for $build');
      expect(row!.outcome, SdeBundleOutcome.built, reason: row.reason);
      final bytes = await bundleBytesOf(session, build);
      expect(bytes, isNotNull, reason: 'no bundle bytes for $build');
      return (bytes: bytes!, sha256: row.sha256!);
    }

    /// Builds [fixture] as [build] on both paths: through the server's
    /// check (first activation) and with no server.
    Future<_Pair> bothPaths(SdeFixture fixture, int build) async {
      final zip = fixture.writeTo(scratch);
      final result = await check(zip, build);
      expect(result, isA<BuildSwitched>(), reason: '$result');
      final server = await stored(build);
      final local = await buildBundleFromZip(zip, scratchRoot: scratch);
      return (
        serverBytes: server.bytes,
        serverSha256: server.sha256,
        local: local,
      );
    }

    void expectSameBytes(_Pair pair) {
      expect(pair.serverSha256, pair.local.sha256);
      expect(pair.serverBytes, pair.local.bytes);
    }

    test('server bundle and local zip bundle have the same bytes', () async {
      const build = 5100;
      final fixture = SdeFixture.complete(build: build);
      final ability = {
        '_key': 7001,
        'name': {'en': 'Test ability', 'de': 'Testfaehigkeit'},
        'cooldownSeconds': 10,
        'disallowInHighSec': true,
        'targetFlags': [1, 2],
      };
      fixture.files['fighterAbilities.jsonl'] = [ability];
      final effect =
          fixture.files['dogmaEffects.jsonl']!.single! as Map<String, Object?>;

      final pair = await bothPaths(fixture, build);

      expectSameBytes(pair);
      for (final bytes in [pair.serverBytes, pair.local.bytes]) {
        final opened = _open(bytes, build, pair.local.sha256);
        expect(opened.header.releaseDate, '2026-01-01T00:00:00Z');
        final effects = opened.records(bundle.BundleSection.dogmaEffects);
        expect(effects.single.key, 9701);
        expect(effects.single.raw, effect);
        expect(effects.single.typed['displayName'], {'en': 'Test effect'});
        final abilities = opened.records(bundle.BundleSection.fighterAbilities);
        expect(abilities.single.key, 7001);
        expect(abilities.single.raw, ability);
      }
    });

    // Scenario: Section presence follows accepted records / Optional file
    // with no accepted records (C24).
    test('optional file with no accepted records is absent on both paths after '
        'its report is pruned', () async {
      const build = 5200;
      final fixture = SdeFixture.complete(build: build);
      fixture.files['dynamicItemAttributes.jsonl'] = [
        const RawLine('{not json'),
        const RawLine('[1, 2'),
      ];
      final zip = fixture.writeTo(scratch);
      final importer = await PostgresStaticDataStore.open(settings);
      final imported = await ImportSdeJob(
        store: importer,
        source: LocalZipSdeSource(zip, scratchRoot: scratch),
      ).run();
      expect(imported, isA<ImportSucceeded>(), reason: '$imported');
      final pruner = await PostgresStaticDataStore.open(settings);
      addTearDown(pruner.close);
      await pruner.pruneRecords(keep: 0);
      expect(await SdeImport.db.count(session), 0);
      expect(await bundleRowOf(session, build), isNull);

      // A check that finds the build up to date repairs its bundle.
      final result = await check(zip, build);
      expect(result, isA<BuildUpToDate>(), reason: '$result');
      final server = await stored(build);
      final local = await buildBundleFromZip(zip, scratchRoot: scratch);

      expectSameBytes((
        serverBytes: server.bytes,
        serverSha256: server.sha256,
        local: local,
      ));
      for (final bytes in [server.bytes, local.bytes]) {
        final section = _open(
          bytes,
          build,
          local.sha256,
        ).header.sections[bundle.BundleSection.dynamicItemAttributes]!;
        expect(section.present, isFalse);
        expect(section.records, 0);
      }
    });

    // Scenario: Release date / numeric build-number match (C23).
    test('release date comes from the first `_sde` object whose build number '
        'numerically equals the build on both paths', () async {
      const build = 42;
      final fixture = SdeFixture.complete(build: build);
      fixture.files['_sde.jsonl'] = [
        {'_key': 'sde', 'releaseDate': '2026-01-01'},
        const RawLine(
          '{"_key": "sde", "buildNumber": 42e0, '
          '"releaseDate": "2026-02-02"}',
        ),
        {'_key': 'sde', 'buildNumber': 42, 'releaseDate': '2026-03-03'},
        {'_key': 'sde', 'buildNumber': 42, 'releaseDate': '2026-04-04'},
      ];

      final pair = await bothPaths(fixture, build);

      expectSameBytes(pair);
      for (final bytes in [pair.serverBytes, pair.local.bytes]) {
        expect(
          _open(bytes, build, pair.local.sha256).header.releaseDate,
          '2026-02-02',
        );
      }
    });

    // Scenario: Record selection is the import's on both paths (C23).
    test(
      'duplicate typed and dbuffCollections keys and float in an integer '
      'column give the same records, values and bytes on both paths',
      () async {
        const build = 5300;
        final fixture = SdeFixture.complete(build: build);
        fixture.files['categories.jsonl']!.add({
          '_key': 9001,
          'name': {'en': 'Duplicate category'},
          'published': false,
        });
        final types = fixture.files['types.jsonl']!;
        final bare = types[1]! as Map<String, Object?>;
        types[1] = {...bare, 'portionSize': 1.5};
        fixture.files['dbuffCollections.jsonl'] = [
          {'_key': 7, 'n': 1},
          {'_key': 3, 'n': 2},
          {'_key': 7, 'n': 3},
        ];

        final pair = await bothPaths(fixture, build);

        expectSameBytes(pair);
        for (final bytes in [pair.serverBytes, pair.local.bytes]) {
          final opened = _open(bytes, build, pair.local.sha256);
          final category = opened
              .records(bundle.BundleSection.categories)
              .where((r) => r.key == 9001)
              .single;
          expect(category.typed['name'], {'en': 'Test category'});
          expect(category.typed['published'], isTrue);
          final type = opened
              .records(bundle.BundleSection.types)
              .where((r) => r.key == 9202)
              .single;
          expect(type.typed.containsKey('portionSize'), isTrue);
          expect(type.typed['portionSize'], isNull);
          final buffs = opened.records(bundle.BundleSection.dbuffCollections);
          expect(buffs.map((r) => (r.key, r.raw!['n'])), [
            (3, 2),
            (7, 1),
            (7, 3),
          ]);
        }
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
