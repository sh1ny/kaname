@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_opener_io.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/file_bundle_store.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'support/bundle_fixture.dart';

const buildN = 3714173;
const _hangGuard = Timeout(Duration(minutes: 3));

/// A gzip bundle file whose header names format major [major], with its
/// identity.
BundleCopy otherFormatBundle({required int build, required int major}) {
  final header = jsonEncode({
    'formatMajor': major,
    'formatMinor': 0,
    'build': build,
    'releaseDate': null,
    'locales': ['en'],
    'sections': <Object?>[],
  });
  final bytes = Uint8List.fromList(gzip.encode(utf8.encode('$header\n')));
  return BundleCopy(
    identity: BundleIdentity(build: build, sha256: bundleSha256(bytes)),
    bytes: bytes,
  );
}

final class _PausedSave {
  _PausedSave(Directory directory, BundleCopy copy) {
    finished = FileBundleStore(
      directory: directory,
      opener: FakeBundleOpener(),
      beforeRename: _beforeRename,
    ).save(copy);
    addTearDown(() async {
      release();
      await finished;
    });
  }

  final _reached = Completer<void>();
  final _resume = Completer<void>();
  late final Future<BundleSaveOutcome> finished;
  var renames = 0;

  Future<void> get reached => _reached.future;

  Future<void> _beforeRename() async {
    renames++;
    if (renames != 1) return;
    _reached.complete();
    await _resume.future;
  }

  void release() {
    if (!_resume.isCompleted) _resume.complete();
  }
}

void main() {
  late Directory root;
  late Directory directory;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kaname_bundle_store_');
    directory = Directory('${root.path}${Platform.pathSeparator}static_data');
  });

  tearDown(() => root.deleteSync(recursive: true));

  FileBundleStore store({FakeBundleOpener? opener, DateTime Function()? now}) =>
      FileBundleStore(
        directory: directory,
        opener: opener ?? FakeBundleOpener(),
        now: now,
      );

  /// The files in the store's directory, by name.
  Map<String, File> files() => {
    for (final entity in directory.listSync())
      if (entity is File) entity.uri.pathSegments.last: entity,
  };

  /// The one kept file: every file that is not a save's temporary file.
  File keptFile() => files().entries
      .where((entry) => !entry.key.endsWith('.tmp'))
      .single
      .value;

  Iterable<File> temporaryFiles() => files().entries
      .where((entry) => entry.key.endsWith('.tmp'))
      .map((entry) => entry.value);

  void expectLoaded(KeptBundleLoad load, BundleCopy expected) {
    expect(load, isA<KeptBundleLoaded>());
    final loaded = load as KeptBundleLoaded;
    expect(loaded.identity, expected.identity);
    expect(loaded.bundle.header.build, expected.identity.build);
    expect(loaded.bundle.solarSystems.single.name.en, 'Jita');
  }

  test('kept file loads at start without network', () async {
    final copy = fixtureBundle(buildN);
    expect(await store().save(copy), isA<BundleSaved>());

    // A new store over the same directory is the next start; it has no
    // network to use.
    final opener = FakeBundleOpener();
    expectLoaded(await store(opener: opener).load(), copy);
    expect(opener.calls, 1);
  });

  test(
    'truncated file is rejected, not deleted, and nothing is held',
    () async {
      await store().save(fixtureBundle(buildN));
      final kept = keptFile();
      final truncated = kept.readAsBytesSync().sublist(
        0,
        kept.lengthSync() ~/ 2,
      );
      kept.writeAsBytesSync(truncated);

      final load = await store().load();

      expect(load, isA<KeptBundleRejected>());
      expect(keptFile().path, kept.path);
      expect(keptFile().readAsBytesSync(), truncated);
    },
  );

  test(
    'a kept file of an unsupported major format is refused and not deleted',
    () async {
      final other = otherFormatBundle(build: buildN, major: 2);
      await store().save(other);
      final before = keptFile().readAsBytesSync();

      final load = await store().load();

      expect(load, isA<KeptBundleRejected>());
      final refusal = (load as KeptBundleRejected).refusal;
      expect(refusal, isA<UnsupportedFormat>());
      expect((refusal as UnsupportedFormat).bundleMajor, 2);
      expect(keptFile().readAsBytesSync(), before);
    },
  );

  test('a failed check in one process never deletes the file another process '
      'just saved', () async {
    await store().save(fixtureBundle(buildN));
    final kept = keptFile();
    kept.writeAsBytesSync(kept.readAsBytesSync().sublist(0, 100));

    // Process A reads the truncated file and is still checking it.
    final held = Completer<void>();
    final slowOpener = FakeBundleOpener(onHold: held.complete)..hold = true;
    final slowLoad = store(opener: slowOpener).load();
    addTearDown(() async {
      slowOpener.hold = false;
      slowOpener.release();
      await slowLoad;
    });
    await held.future;

    // Process B saves build N+1 meanwhile.
    final next = fixtureBundle(buildN + 1);
    expect(await store().save(next), isA<BundleSaved>());

    slowOpener.release();
    expect(await slowLoad, isA<KeptBundleRejected>());

    expect(keptFile().path, kept.path);
    expectLoaded(await store().load(), next);
  }, timeout: _hangGuard);

  test('save stopped before the rename loads the previous bundle and removes '
      'temporary files older than an hour', () async {
    final previous = fixtureBundle(buildN);
    expect(await store().save(previous), isA<BundleSaved>());
    final next = fixtureBundle(buildN + 1);
    final now = DateTime.utc(2026);

    // Both writers have closed their temporary file but have not renamed it.
    final older = _PausedSave(directory, next);
    await older.reached;
    final old = temporaryFiles().single;
    old.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
    final newer = _PausedSave(directory, next);
    await newer.reached;
    final recent = temporaryFiles().singleWhere(
      (file) => file.path != old.path,
    );
    recent.setLastModifiedSync(now.subtract(const Duration(minutes: 10)));

    expectLoaded(await store(now: () => now).load(), previous);

    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue, reason: 'another save may own it');

    older.release();
    expect(await older.finished, isA<BundleSaved>());
    newer.release();
    expect(await newer.finished, isA<BundleSaved>());
  }, timeout: _hangGuard);

  test('a save suspended past the cutoff before its rename writes again '
      'when another start removed its temporary file', () async {
    final previous = fixtureBundle(buildN);
    expect(await store().save(previous), isA<BundleSaved>());
    final next = fixtureBundle(buildN + 1);
    final now = DateTime.utc(2026);
    final saving = _PausedSave(directory, next);
    await saving.reached;
    temporaryFiles().single.setLastModifiedSync(
      now.subtract(const Duration(hours: 2)),
    );

    expectLoaded(await store(now: () => now).load(), previous);
    expect(temporaryFiles(), isEmpty);

    saving.release();
    expect(await saving.finished, isA<BundleSaved>());
    expect(saving.renames, 2);
    expect(temporaryFiles(), isEmpty);
    expectLoaded(await store().load(), next);
  }, timeout: _hangGuard);

  test(
    'a failed write keeps the previous copy and lets no error escape',
    () async {
      final n = fixtureBundle(buildN);
      await store().save(n);
      // The temporary file cannot be created in a read-only directory.
      await Process.run('chmod', ['555', directory.path]);
      addTearDown(() => Process.run('chmod', ['755', directory.path]));
      final escaped = <Object>[];

      final outcome = await runZonedGuarded(() async {
        final outcome = await store().save(fixtureBundle(buildN + 1));
        // Give a stray sink error time to surface.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return outcome;
      }, (error, _) => escaped.add(error));

      expect(outcome, isA<BundleNotSaved>());
      expect(escaped, isEmpty);
      await Process.run('chmod', ['755', directory.path]);
      expectLoaded(await store().load(), n);
    },
    testOn: 'posix',
  );

  test('saved rollback loads the older build at an offline restart', () async {
    final n = fixtureBundle(buildN);
    await store().save(n);
    await store().save(fixtureBundle(buildN + 1));
    // The rollback swaps build N back in and saves it.
    await store().save(n);

    expectLoaded(await store().load(), n);
  });

  test('the isolate opener opens a bundle and refuses a wrong hash', () async {
    final copy = fixtureBundle(buildN);
    const opener = IsolateBundleOpener();

    final opened = await opener.open(copy.bytes, copy.identity);
    expect(opened, isA<BundleOpened>());
    expect((opened as BundleOpened).bundle.types.single.name.en, 'Rifter');
    // The index is built in the same isolate operation (design D12).
    expect(opened.index!.search('rifter').hits.single.id, 587);

    final kept = FileBundleStore(directory: directory, opener: opener);
    await kept.save(copy);
    final loaded = await kept.load();
    expect(
      (loaded as KeptBundleLoaded).index!.search('rifter').hits,
      hasLength(1),
    );

    final other = fixtureBundle(buildN + 1).identity;
    final refused = await opener.open(
      copy.bytes,
      BundleIdentity(build: buildN, sha256: other.sha256),
    );
    expect((refused as BundleRefused).refusal, isA<HashMismatch>());
  });
}
