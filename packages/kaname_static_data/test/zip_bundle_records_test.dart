import 'dart:io';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    as bundle;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory zips;
  late Directory scratch;

  setUp(() {
    zips = Directory.systemTemp.createTempSync('kaname_zip_bundle_zips_');
    scratch = Directory.systemTemp.createTempSync('kaname_zip_bundle_scratch_');
  });
  tearDown(() {
    zips.deleteSync(recursive: true);
    scratch.deleteSync(recursive: true);
  });

  Future<ZipBundleException> failureOf(File zip) async {
    try {
      await buildBundleFromZip(zip, scratchRoot: scratch);
    } on ZipBundleException catch (error) {
      return error;
    }
    fail('expected a ZipBundleException');
  }

  void expectNothingWritten(File zip) {
    expect(
      zips.listSync().map((entry) => p.basename(entry.path)),
      zip.existsSync() ? [p.basename(zip.path)] : isEmpty,
    );
    expect(scratch.listSync(), isEmpty);
  }

  group('buildBundleFromZip', () {
    test('unreadable zip fails naming the zip and writes nothing', () async {
      final notAZip = writeFile(zips, 'not-a-zip.zip', [1, 2, 3, 4, 5]);
      final notAZipFailure = await failureOf(notAZip);
      expect(notAZipFailure.zipPath, notAZip.path);
      expect(notAZipFailure.toString(), contains(notAZip.path));
      expectNothingWritten(notAZip);
      notAZip.deleteSync();

      final missing = File(p.join(zips.path, 'missing.zip'));
      final missingFailure = await failureOf(missing);
      expect(missingFailure.toString(), contains(missing.path));
      expectNothingWritten(missing);

      final fixture = SdeFixture.complete()..files.remove('types.jsonl');
      final incomplete = fixture.writeTo(zips, 'incomplete.zip');
      final incompleteFailure = await failureOf(incomplete);
      expect(incompleteFailure.toString(), contains(incomplete.path));
      expect(incompleteFailure.reason, contains('types.jsonl'));
      expectNothingWritten(incomplete);
    });

    // Pre-ship round 48: a build number the readers cannot read exactly is
    // refused before a bundle is written.
    test('a build number past 2^53 - 1 fails naming the build', () async {
      const build = bundle.bundleMaxKey + 1;
      final zip = SdeFixture.complete(build: build).writeTo(zips);

      final failure = await failureOf(zip);

      expect(failure.reason, contains('build number $build'));
      expect(scratch.listSync(), isEmpty);
    });

    test('a fixture zip builds a bundle with no server', () async {
      final fixture = SdeFixture.complete(build: 4242);
      fixture.files['_sde.jsonl'] = [
        {'_key': 'sde', 'buildNumber': 4242, 'releaseDate': '2026-03-04'},
        {'_key': 'sde', 'buildNumber': 4242, 'releaseDate': 'ignored'},
      ];
      final categoryKeys = [
        for (final line in fixture.files['categories.jsonl']!)
          (line! as Map<String, Object?>)['_key']! as int,
        9003,
      ]..sort();
      final typeCount = fixture.files['types.jsonl']!.length;
      fixture.files['categories.jsonl']!.addAll([
        // A duplicate typed key: the import keeps the first record.
        {
          '_key': 9001,
          'name': {'en': 'Duplicate'},
        },
        // A wrong-typed value: the import stores `null`.
        {
          '_key': 9003,
          'name': {'en': 'Odd category'},
          'published': 'yes',
        },
        const RawLine('{not json'),
      ]);
      fixture.files['dbuffCollections.jsonl'] = [
        {'_key': 7, 'n': 1},
        {'_key': 3, 'n': 2},
        {'_key': 7, 'n': 3},
      ];
      fixture.files['fighterAbilities.jsonl'] = [const RawLine('{bad')];
      final zip = fixture.writeTo(zips);

      final built = await buildBundleFromZip(zip, scratchRoot: scratch);

      expect(built.buildNumber, 4242);
      expect(scratch.listSync(), isEmpty);
      final opened = bundle.openBundle(
        built.bytes,
        build: 4242,
        sha256: built.sha256,
      );
      final client = switch (opened) {
        bundle.BundleOpened(bundle: final ready) => ready,
        bundle.BundleRefused(:final refusal) => fail('refused: $refusal'),
      };
      final header = client.header;
      expect(header.releaseDate, '2026-03-04');
      final categories = header.sections[bundle.BundleSection.categories]!;
      expect(categories.present, isTrue);
      expect(categories.records, categoryKeys.length);
      expect(header.sections[bundle.BundleSection.types]!.records, typeCount);
      expect(
        header.sections[bundle.BundleSection.dbuffCollections]!.records,
        3,
      );
      for (final absent in [
        bundle.BundleSection.dynamicItemAttributes,
        bundle.BundleSection.fighterAbilities,
        bundle.BundleSection.fighterAbilitiesByType,
      ]) {
        expect(header.sections[absent]!.present, isFalse, reason: '$absent');
        expect(header.sections[absent]!.records, 0, reason: '$absent');
      }

      final categoryRecords = client.records(bundle.BundleSection.categories);
      expect(categoryRecords.map((r) => r.key), categoryKeys);
      expect(categoryRecords.firstWhere((r) => r.key == 9001).typed['name'], {
        'en': 'Test category',
      });
      expect(
        categoryRecords.firstWhere((r) => r.key == 9003).typed['published'],
        isNull,
      );
      final buffs = client.records(bundle.BundleSection.dbuffCollections);
      expect(buffs.map((r) => r.raw!['n']), [2, 1, 3]);
    });
  });
}
