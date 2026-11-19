import 'dart:io';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory scratch;
  late Directory zips;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('kaname_local_test_');
    zips = Directory.systemTemp.createTempSync('kaname_local_zips_');
  });
  tearDown(() {
    scratch.deleteSync(recursive: true);
    zips.deleteSync(recursive: true);
  });

  LocalZipSdeSource sourceOf(
    List<int> bytes, {
    SdeLimits limits = const SdeLimits(),
  }) => LocalZipSdeSource(
    writeFile(zips, 'build.zip', bytes),
    limits: limits,
    scratchRoot: scratch,
  );

  Future<String> reasonOf(Future<Object?> Function() action) async {
    try {
      await action();
    } on SdeSourceException catch (e) {
      return e.reason;
    }
    fail('expected an SdeSourceException');
  }

  group('LocalZipSdeSource', () {
    test(
      'the archive reports the zip size and the declared unpacked size',
      () async {
        final bytes = buildZip({
          'a.jsonl': [
            {'_key': 1},
          ],
          'b.jsonl': [
            {'_key': 22},
          ],
          'readme.txt': [const RawLine('not counted: not an sde file')],
        });
        final archive = await sourceOf(bytes).open() as ZipSdeArchive;
        addTearDown(archive.close);

        expect(archive.zipBytes, bytes.length);
        // '{"_key":1}\n' is 11 bytes and '{"_key":22}\n' is 12.
        expect(archive.declaredUnpackedBytes, 23);
        expect(archive.largestEntryBytes, 12);
      },
    );

    test('reads lines, skips blank ones and counts every line', () async {
      final source = sourceOf(
        buildZip({
          'a.jsonl': [
            {'_key': 1},
            const RawLine(''),
            const RawLine('   '),
            const RawLine('{"_key":2}\r'),
            {'_key': 3},
          ],
          'readme.txt': [const RawLine('not an sde file')],
        }),
      );
      expect(source.kind, SdeSourceKind.local);
      expect(await source.announcedBuild(), isNull);
      final archive = await source.open();
      addTearDown(archive.close);

      expect(archive.fileNames, ['a.jsonl'], reason: 'only .jsonl entries');
      final lines = await archive.lines('a.jsonl').toList();
      expect(lines.map((l) => l.number), [1, 4, 5]);
      expect(lines.map((l) => (l as SdeTextLine).text), [
        '{"_key":1}',
        '{"_key":2}',
        '{"_key":3}',
      ]);
      expect(
        scratch.listSync(recursive: true).whereType<File>(),
        isEmpty,
        reason: 'the unpacked entry is deleted once its lines are consumed',
      );

      await archive.close();
      expect(scratch.listSync(), isEmpty, reason: 'close deletes the work dir');
    });

    test(
      'a line over the cap and invalid UTF-8 are unreadable lines',
      () async {
        final source = sourceOf(
          buildZip({
            'a.jsonl': [
              const RawLine('{"_key":1}'),
              RawLine('{"_key":2,"pad":"${'x' * 100}"}'),
              const RawLine('{"_key":3}'),
            ],
          }),
          limits: const SdeLimits(maxLineBytes: 50),
        );
        final archive = await source.open();
        addTearDown(archive.close);
        final lines = await archive.lines('a.jsonl').toList();
        expect(lines, hasLength(3));
        expect(lines[0], isA<SdeTextLine>());
        expect(
          lines[1],
          isA<SdeUnreadableLine>()
              .having((l) => l.number, 'number', 2)
              .having((l) => l.reason, 'reason', 'line exceeds 50 bytes'),
        );
        expect(lines[2], isA<SdeTextLine>().having((l) => l.number, 'n', 3));

        final bad = await sourceOf(
          buildZipBytes({
            'b.jsonl': [
              ...'{"_key":1,"n":"'.codeUnits,
              0xC3,
              0x28,
              ...'"}\n'.codeUnits,
            ],
          }),
        ).open();
        addTearDown(bad.close);
        expect(
          await bad.lines('b.jsonl').single,
          isA<SdeUnreadableLine>().having(
            (l) => l.reason,
            'reason',
            'invalid UTF-8',
          ),
        );
      },
    );

    test('a truncated or missing zip fails without naming a path', () async {
      final whole = buildZip({
        'a.jsonl': [
          for (var i = 0; i < 50; i++) {'_key': i, 'name': 'name $i'},
        ],
      });
      final truncated = await reasonOf(
        () => sourceOf(whole.sublist(0, whole.length ~/ 2)).open(),
      );
      expect(truncated, startsWith('local zip cannot be read'));

      final garbage = await reasonOf(
        () => sourceOf('not a zip'.codeUnits).open(),
      );
      expect(garbage, startsWith('local zip cannot be read'));

      final missing = await reasonOf(
        () => LocalZipSdeSource(
          File('${zips.path}/absent.zip'),
          scratchRoot: scratch,
        ).open(),
      );
      expect(missing, 'local zip does not exist');

      for (final reason in [truncated, garbage, missing]) {
        expect(reason, isNot(contains(zips.path)));
        expect(reason, isNot(contains(scratch.path)));
      }
      expect(scratch.listSync(), isEmpty, reason: 'failures leave no files');
    });

    test('an entry or the whole zip over its cap is refused', () async {
      final bytes = buildZip({
        'a.jsonl': [
          for (var i = 0; i < 20; i++) {'_key': i},
        ],
        'b.jsonl': [
          for (var i = 0; i < 20; i++) {'_key': i},
        ],
      });
      expect(
        await reasonOf(
          () => sourceOf(
            bytes,
            limits: const SdeLimits(maxEntryBytes: 100),
          ).open(),
        ),
        'local zip entry a.jsonl exceeds 100 bytes unpacked',
      );
      expect(
        await reasonOf(
          () => sourceOf(
            bytes,
            limits: const SdeLimits(maxTotalBytes: 400),
          ).open(),
        ),
        'local zip entries exceed 400 bytes unpacked',
      );
      expect(scratch.listSync(), isEmpty);
    });
  });
}
