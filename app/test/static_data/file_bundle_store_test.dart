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

void main() {
  late Directory root;
  late Directory directory;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kaname_bundle_store_');
    directory = Directory('${root.path}${Platform.pathSeparator}static_data');
  });

  tearDown(() => root.deleteSync(recursive: true));

  FileBundleStore store({
    FakeBundleOpener? opener,
    Future<void> Function()? beforeRename,
  }) => FileBundleStore(
    directory: directory,
    opener: opener ?? FakeBundleOpener(),
    beforeRename: beforeRename,
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

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never became true');
  }

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
    final slowOpener = FakeBundleOpener()..hold = true;
    final slowLoad = store(opener: slowOpener).load();
    await waitFor(() => slowOpener.waiting);

    // Process B saves build N+1 meanwhile.
    final next = fixtureBundle(buildN + 1);
    expect(await store().save(next), isA<BundleSaved>());

    slowOpener.release();
    expect(await slowLoad, isA<KeptBundleRejected>());

    expect(keptFile().path, kept.path);
    expectLoaded(await store().load(), next);
  });

  test('save stopped before the rename loads the previous bundle and removes '
      'temporary files older than an hour', () async {
    final previous = fixtureBundle(buildN);
    await store().save(previous);

    // Two saves of build N+1 stop before their rename, as when the app
    // stops; neither ever completes.
    var stopped = 0;
    Future<void> stop() {
      stopped++;
      return Completer<void>().future;
    }

    unawaited(store(beforeRename: stop).save(fixtureBundle(buildN + 1)));
    await waitFor(() => stopped == 1);
    final old = temporaryFiles().single;
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    unawaited(store(beforeRename: stop).save(fixtureBundle(buildN + 1)));
    await waitFor(() => stopped == 2);
    final recent = temporaryFiles().singleWhere(
      (file) => file.path != old.path,
    );
    recent.setLastModifiedSync(
      DateTime.now().subtract(const Duration(minutes: 10)),
    );

    expectLoaded(await store().load(), previous);

    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue, reason: 'another save may own it');
  });

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

    final other = fixtureBundle(buildN + 1).identity;
    final refused = await opener.open(
      copy.bytes,
      BundleIdentity(build: buildN, sha256: other.sha256),
    );
    expect((refused as BundleRefused).refusal, isA<HashMismatch>());
  });
}
