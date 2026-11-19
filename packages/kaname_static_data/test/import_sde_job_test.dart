import 'dart:convert';
import 'dart:io';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

import 'support/fake_http.dart';

const int _build = 1000;

void main() {
  late Directory scratch;
  late Directory zips;
  late InMemoryStaticDataStore store;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('kaname_job_scratch_');
    zips = Directory.systemTemp.createTempSync('kaname_job_zips_');
    store = InMemoryStaticDataStore();
  });
  tearDown(() {
    expect(scratch.listSync(), isEmpty, reason: 'the job leaves no temp files');
    scratch.deleteSync(recursive: true);
    zips.deleteSync(recursive: true);
  });

  /// Runs a job over [fixture] with a local zip source.
  Future<ImportResult> import(
    SdeFixture fixture, {
    InMemoryStaticDataStore? into,
    SdeLimits limits = const SdeLimits(),
    List<KnownId> knownIdTable = knownIds,
    int batchSize = 500,
    DateTime Function()? clock,
  }) => ImportSdeJob(
    store: into ?? store,
    source: LocalZipSdeSource(
      fixture.writeTo(zips),
      limits: limits,
      scratchRoot: scratch,
    ),
    limits: limits,
    knownIdTable: knownIdTable,
    batchSize: batchSize,
    clock: clock,
    scratchRoot: scratch,
  ).run();

  ImportSucceeded succeeded(ImportResult result) {
    expect(result, isA<ImportSucceeded>(), reason: '$result');
    return result as ImportSucceeded;
  }

  ImportRecord onlyRecord() {
    expect(store.records, hasLength(1));
    return store.records.single.record;
  }

  TypedRow typeRow(int id) =>
      store.typedRows(_build, 'sde_type').singleWhere((r) => r.sdeId == id);

  group('stale temporary directories', () {
    Directory stale(String name) {
      final dir = Directory('${scratch.path}/$name')..createSync();
      File('${dir.path}/sde.zip').writeAsStringSync('half a download');
      Directory('${dir.path}/unpacked').createSync();
      File('${dir.path}/unpacked/types.jsonl').writeAsStringSync('{}');
      return dir;
    }

    test('a killed import\'s directory is removed under the lock', () async {
      final left = stale('kaname_sde_import_killed');
      final other = Directory('${scratch.path}/someone_elses')..createSync();

      succeeded(await import(SdeFixture.complete()));

      expect(left.existsSync(), isFalse);
      expect(other.existsSync(), isTrue, reason: 'only the prefix is swept');
      other.deleteSync();
    });

    test('a sweep leaves the dirs of a sibling root alone', () async {
      final sibling = Directory.systemTemp.createTempSync('kaname_sibling_');
      addTearDown(() => sibling.deleteSync(recursive: true));
      final theirs = Directory('${sibling.path}/kaname_sde_import_theirs')
        ..createSync();
      final ours = stale('kaname_sde_import_ours');

      succeeded(await import(SdeFixture.complete()));

      expect(ours.existsSync(), isFalse);
      expect(theirs.existsSync(), isTrue);
    });

    test('a job given no scratch root sweeps nothing', () async {
      // Where a sweep with no root would look: the system temp directory.
      final foreign = Directory(
        '${Directory.systemTemp.path}/kaname_sde_import_foreign_$pid',
      )..createSync();
      addTearDown(() => foreign.deleteSync(recursive: true));
      final fixture = SdeFixture.complete();

      final result = await ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(fixture.writeTo(zips), scratchRoot: scratch),
      ).run();

      expect(result, isA<ImportSucceeded>());
      expect(foreign.existsSync(), isTrue);
    });

    test('a missing root is created for the sources', () async {
      final root = Directory('${scratch.path}/nested/db');

      final result = await ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(
          SdeFixture.complete().writeTo(zips),
          scratchRoot: root,
        ),
        scratchRoot: root,
      ).run();

      expect(result, isA<ImportSucceeded>());
      expect(root.listSync(), isEmpty);
      Directory('${scratch.path}/nested').deleteSync(recursive: true);
    });

    test('nothing is removed when the lock is busy', () async {
      final left = stale('kaname_sde_import_running');
      final holder = InMemoryStaticDataStore(lock: store.lock);
      await holder.tryLock();

      final result = await import(SdeFixture.complete());

      expect(result, isA<ImportSkipped>());
      expect(left.existsSync(), isTrue);
      left.deleteSync(recursive: true);
    });
  });

  group('sources', () {
    test('local zip and CCP source store equal rows', () async {
      final fixture = SdeFixture.complete();
      final zipBytes = fixture.toZip();
      final ccpStore = InMemoryStaticDataStore();
      final client = FakeHttpClient((request) async {
        return request.url.path.endsWith('latest.jsonl')
            ? bytesResponse(
                utf8.encode('{"_key":"sde","buildNumber":$_build}\n'),
              )
            : bytesResponse(zipBytes);
      });

      final local = succeeded(await import(fixture));
      final ccp = succeeded(
        await ImportSdeJob(
          store: ccpStore,
          source: CcpSdeSource(
            client: client,
            baseUrl: Uri.parse('https://sde.example.test/'),
            scratchRoot: scratch,
          ),
        ).run(),
      );

      Map<String, Object?> snapshot(InMemoryStaticDataStore s) => {
        for (final file in typedFiles)
          file.table: [
            for (final row in s.typedRows(_build, file.table))
              [row.sdeId, row.values, row.raw.value],
          ],
        'raw': [
          for (final r in s.rawRecords(_build))
            [r.file, r.line, r.key, r.record.value],
        ],
      };
      expect(snapshot(ccpStore), snapshot(store));
      expect(ccp.build, local.build);
      expect(ccpStore.records.single.record.source, SdeSourceKind.ccp);
      expect(onlyRecord().source, SdeSourceKind.local);
      expect(onlyRecord().build, _build);
    });

    test('fails on build number mismatch', () async {
      final client = FakeHttpClient((request) async {
        return request.url.path.endsWith('latest.jsonl')
            ? bytesResponse(utf8.encode('{"_key":"sde","buildNumber":1001}\n'))
            : bytesResponse(SdeFixture.complete().toZip());
      });
      final result = await ImportSdeJob(
        store: store,
        source: CcpSdeSource(
          client: client,
          baseUrl: Uri.parse('https://sde.example.test/'),
          scratchRoot: scratch,
        ),
      ).run();

      expect(result, isA<ImportFailed>());
      final reason = (result as ImportFailed).reason;
      expect(reason, startsWith('build number mismatch'));
      expect(reason, allOf(contains('1001'), contains('1000')));
      expect(store.builds, isEmpty);
      expect(store.rowsWritten, 0);
      expect(onlyRecord().outcome, ImportOutcome.failed);
      expect(onlyRecord().failureReason, reason);
    });

    test('an unreadable source fails with its reason and no rows', () async {
      final whole = SdeFixture.complete().toZip();
      final file = writeFile(
        zips,
        'cut.zip',
        whole.sublist(0, whole.length ~/ 2),
      );
      final result = await ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(file, scratchRoot: scratch),
      ).run();

      expect(result, isA<ImportFailed>());
      expect(
        (result as ImportFailed).reason,
        startsWith('local zip cannot be read'),
      );
      expect(store.builds, isEmpty);
      expect(onlyRecord().outcome, ImportOutcome.failed);
    });
  });

  group('typed files', () {
    test('known fields land in typed columns and the record is kept', () async {
      final fixture = SdeFixture.complete();
      final result = succeeded(await import(fixture));

      expect(result.build, _build);
      final full = typeRow(9201);
      expect(full.values, {
        'groupId': 9101,
        'name': 'Test hull',
        'published': true,
        'volume': 5.0,
        'capacity': 10.5,
        'portionSize': 1,
        'mass': 1000.0,
        'marketGroupId': 9301,
        'metaGroupId': 1,
      });
      expect(full.values['volume'], isA<double>());
      expect(full.raw.value, fixture.files['types.jsonl']![0]);
      for (final file in typedFiles) {
        expect(
          store.typedRows(_build, file.table),
          isNotEmpty,
          reason: '${file.table} has rows',
        );
      }
      expect(result.report.drift.newFields, isEmpty);
      expect(result.report.drift.wrongTypedFields, isEmpty);
    });

    test('missing optional field stores null', () async {
      succeeded(await import(SdeFixture.complete()));
      expect(typeRow(9202).values, {
        'groupId': 9102,
        'name': 'Bare type',
        'published': false,
        'volume': null,
        'capacity': null,
        'portionSize': 1,
        'mass': null,
        'marketGroupId': null,
        'metaGroupId': null,
      });
    });

    test('wrong-typed field is null and reported', () async {
      final fixture = SdeFixture.complete();
      final bare = fixture.files['types.jsonl']![1]! as Map<String, Object?>;
      bare['groupID'] = 'oops'; // not an integer
      bare['volume'] = 'big'; // not a number
      bare['portionSize'] = 1.5; // an int column rejects a non-integer
      final result = succeeded(await import(fixture));

      final row = typeRow(9202);
      expect(row.values['groupId'], isNull);
      expect(row.values['volume'], isNull);
      expect(row.values['portionSize'], isNull);
      expect(row.raw.value['groupID'], 'oops', reason: 'the JSON keeps it');
      expect(
        result.report.drift.wrongTypedFields.map(
          (f) => (f.file, f.field, f.records),
        ),
        unorderedEquals([
          ('types.jsonl', 'groupID', 1),
          ('types.jsonl', 'volume', 1),
          ('types.jsonl', 'portionSize', 1),
        ]),
      );
    });
  });

  group('other files', () {
    test('known untyped file stored raw, not new', () async {
      final result = succeeded(await import(SdeFixture.complete()));

      final factions = store.rawRecordsOf(_build, 'factions.jsonl');
      expect(factions.map((r) => (r.line, r.key)), [
        (1, '500001'),
        (2, '500002'),
      ]);
      expect(factions.first.record.value['name'], {'en': 'Test faction'});
      final languages = store.rawRecordsOf(
        _build,
        'translationLanguages.jsonl',
      );
      expect(languages.single.key, '', reason: 'string keys are not kept');
      expect(result.report.drift.newFiles, isEmpty);
      expect(result.report.fileCounts['factions.jsonl'], 2);
    });

    test('empty file listed with zero records', () async {
      final fixture = SdeFixture.complete()..files['factions.jsonl'] = [];
      final result = succeeded(await import(fixture));

      expect(result.report.fileCounts['factions.jsonl'], 0);
      expect(
        result.report.drift.missingFiles,
        isNot(contains('factions.jsonl')),
      );
      expect(store.rawRecordsOf(_build, 'factions.jsonl'), isEmpty);
    });
  });

  group('bad records', () {
    test('invalid JSON line is skipped and reported', () async {
      final fixture = SdeFixture.complete();
      fixture.files['types.jsonl']!.add(const RawLine('{"_key": 9203, '));
      final result = succeeded(await import(fixture));

      final bad = result.report.badRecords.files['types.jsonl']!;
      expect(bad.count, 1);
      expect(bad.records.single.line, 3);
      expect(bad.records.single.reason, 'invalid JSON');
      expect(store.typedRows(_build, 'sde_type'), hasLength(2));
      expect(result.report.fileCounts['types.jsonl'], 2);
    });

    test('duplicate key keeps first and reports second', () async {
      final fixture = SdeFixture.complete();
      fixture.files['types.jsonl']!.add({
        '_key': 9201,
        'groupID': 1,
        'name': {'en': 'Second'},
        'portionSize': 1,
        'published': true,
      });
      final result = succeeded(await import(fixture));

      final bad = result.report.badRecords.files['types.jsonl']!;
      expect(
        (bad.records.single.line, bad.records.single.reason),
        (3, 'duplicate key'),
      );
      expect(typeRow(9201).values['name'], 'Test hull');
    });

    test('keyless, wrong-keyed and non-object records are skipped', () async {
      final fixture = SdeFixture.complete();
      fixture.files['groups.jsonl']!.addAll([
        {
          'categoryID': 1,
          'name': {'en': 'No key'},
        },
        {
          '_key': 'text',
          'name': {'en': 'Text key'},
        },
        [1, 2, 3],
      ]);
      final result = succeeded(await import(fixture));

      final bad = result.report.badRecords.files['groups.jsonl']!;
      expect(bad.records.map((r) => (r.line, r.reason)), [
        (3, 'missing key'),
        (4, 'key has the wrong type'),
        (5, 'not a JSON object'),
      ]);
      expect(result.report.badRecords.total, 3);
    });

    test('only the first 100 bad records of a file are listed', () async {
      final fixture = SdeFixture.complete();
      fixture.files['factions.jsonl']!.addAll([
        for (var i = 0; i < 130; i++) const RawLine('nope'),
      ]);
      final result = succeeded(await import(fixture));

      final bad = result.report.badRecords.files['factions.jsonl']!;
      expect(bad.count, 130);
      expect(bad.records, hasLength(100));
      expect(bad.records.last.line, 102);
    });

    test('required file with every line bad fails as missing', () async {
      final fixture = SdeFixture.complete();
      fixture.files['types.jsonl'] = [
        const RawLine('{broken'),
        const RawLine('also broken'),
      ];
      final result = await import(fixture);

      expect(result, isA<ImportFailed>());
      expect(
        (result as ImportFailed).reason,
        'missing required files: types.jsonl',
      );
      expect(store.builds, isEmpty, reason: 'nothing of the build remains');
      expect(store.rowsWritten, 0);
      expect(onlyRecord().outcome, ImportOutcome.failed);
    });
  });

  group('drift', () {
    test('unknown file stored raw and reported new', () async {
      final fixture = SdeFixture.complete()
        ..files['newThing.jsonl'] = [
          {'_key': 7, 'x': 1},
          {'_key': 'a', 'x': 2},
        ];
      final result = succeeded(await import(fixture));

      expect(result.report.drift.newFiles, ['newThing.jsonl']);
      expect(store.rawRecordsOf(_build, 'newThing.jsonl').map((r) => r.key), [
        '7',
        '',
      ]);
    });

    test('unknown field kept in JSON and reported', () async {
      final fixture = SdeFixture.complete();
      (fixture.files['types.jsonl']![0]! as Map<String, Object?>)['newField'] =
          7;
      final result = succeeded(await import(fixture));

      expect(
        result.report.drift.newFields.map((f) => (f.file, f.field, f.records)),
        [('types.jsonl', 'newField', 1)],
      );
      expect(typeRow(9201).raw.value['newField'], 7);
    });
  });

  group('required files', () {
    test('missing types file fails and names it', () async {
      final fixture = SdeFixture.complete()..files.remove('types.jsonl');
      final result = await import(fixture);

      expect(result, isA<ImportFailed>());
      expect(
        (result as ImportFailed).reason,
        'missing required files: types.jsonl',
      );
      expect(store.builds, isEmpty);
      expect(store.rowsWritten, 0);
      expect(onlyRecord().failureReason, 'missing required files: types.jsonl');
    });

    test('zip without _sde fails with no build number', () async {
      final fixture = SdeFixture.complete()..files.remove('_sde.jsonl');
      final result = await import(fixture);

      expect((result as ImportFailed).reason, 'no build number');
      expect(store.builds, isEmpty);
      expect(store.rowsWritten, 0);
      expect(onlyRecord().failureReason, 'no build number');
    });

    test('an _sde record without a build number fails the same way', () async {
      final fixture = SdeFixture.complete()
        ..files['_sde.jsonl'] = [
          {'_key': 'sde', 'buildNumber': 'x'},
        ];
      expect(
        ((await import(fixture)) as ImportFailed).reason,
        'no build number',
      );
    });

    test('missing known untyped file is reported only', () async {
      final fixture = SdeFixture.complete()..files.remove('factions.jsonl');
      final result = succeeded(await import(fixture));

      expect(result.report.drift.missingFiles, contains('factions.jsonl'));
      expect(store.builds, {_build: BuildState.active});
    });
  });

  group('checks', () {
    test('known-ids check passes', () async {
      final result = succeeded(await import(SdeFixture.complete()));

      expect(result.report.knownIds.passed, isTrue);
      expect(result.report.knownIds.checked, knownIds.length);
      expect(result.report.knownIds.toSdeJson().value['passed'], true);
    });

    test('missing known id is reported', () async {
      final result = succeeded(
        await import(
          SdeFixture.complete(),
          knownIdTable: [
            ...knownIds,
            const KnownId('no such type', 987654, IdKind.type),
            // 9201 is a type, not a group.
            const KnownId('type as group', 9201, IdKind.group),
          ],
        ),
      );

      final findings = result.report.knownIds.findings;
      expect(result.report.knownIds.passed, isFalse);
      expect(findings.map((f) => f.known.name), [
        'no such type',
        'type as group',
      ]);
      expect(findings[0].isMissing, isTrue);
      expect(findings[1].foundAs, [IdKind.type]);
      expect(store.builds, {
        _build: BuildState.active,
      }, reason: 'import goes on');
      final json = findings[0].known;
      expect((json.id, json.kind), (987654, IdKind.type));
    });

    test('field check reports every field present', () async {
      final result = succeeded(await import(SdeFixture.complete()));

      final check = result.report.fieldCheck;
      expect(check.isComplete, isTrue);
      expect(check.results, hasLength(industryLogisticsFields.length));
      expect(check.results.every((r) => r.records >= 1), isTrue);
      expect(
        check.results.firstWhere((r) => r.field.path == 'portionSize').records,
        2,
      );
    });

    test('field check reports a missing field', () async {
      final fixture = SdeFixture.complete();
      (fixture.files['types.jsonl']![0]! as Map<String, Object?>).remove(
        'capacity',
      );
      fixture.files.remove('mapStargates.jsonl');
      final result = succeeded(await import(fixture));

      final missing = result.report.fieldCheck.missing.map(
        (r) => '${r.field.file}:${r.field.path}',
      );
      expect(missing, [
        'types.jsonl:capacity',
        'mapStargates.jsonl:destination.solarSystemID',
      ]);
      expect(result.report.fieldCheck.isComplete, isFalse);
      expect(store.builds, {_build: BuildState.active});
    });
  });

  group('records, locking and activation', () {
    test('stored build is skipped without writes', () async {
      store.seedBuild(_build, BuildState.active);
      final result = await import(SdeFixture.complete());

      expect(result, isA<ImportSkipped>());
      expect((result as ImportSkipped).build, _build);
      expect(store.rowsWritten, 0);
      expect(store.committedTransactions, 0);
      expect(store.builds, {_build: BuildState.active});
      expect(onlyRecord().outcome, ImportOutcome.skipped);
      expect(onlyRecord().build, _build);
    });

    test('a stored announced build is skipped before the download', () async {
      store.seedBuild(_build, BuildState.staged);
      final client = FakeHttpClient((request) async {
        return bytesResponse(
          utf8.encode('{"_key":"sde","buildNumber":$_build}\n'),
        );
      });
      final result = await ImportSdeJob(
        store: store,
        source: CcpSdeSource(
          client: client,
          baseUrl: Uri.parse('https://sde.example.test/'),
          scratchRoot: scratch,
        ),
      ).run();

      expect(result, isA<ImportSkipped>());
      expect(client.requested.map((u) => u.pathSegments.last), [
        'latest.jsonl',
      ]);
    });

    test('the job names the record it wrote, whatever the outcome', () async {
      final ok = ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(
          SdeFixture.complete().writeTo(zips),
          scratchRoot: scratch,
        ),
        scratchRoot: scratch,
      );
      expect(ok.recordId, isNull);
      succeeded(await ok.run());
      expect(ok.recordId, store.records.single.id);

      final other = InMemoryStaticDataStore(lock: store.lock);
      await other.tryLock();
      final busy = ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(
          SdeFixture.complete().writeTo(zips),
          scratchRoot: scratch,
        ),
        scratchRoot: scratch,
      );
      expect(await busy.run(), isA<ImportSkipped>());
      expect(busy.recordId, store.records.last.id);
      expect(busy.recordId, isNot(ok.recordId));
    });

    test('a second importer is skipped while the lock is held', () async {
      final other = InMemoryStaticDataStore(lock: store.lock);
      await other.tryLock();
      final result = await import(SdeFixture.complete());

      expect(result, isA<ImportSkipped>());
      expect((result as ImportSkipped).reason, 'import already running');
      expect(onlyRecord().outcome, ImportOutcome.skipped);
      expect(onlyRecord().failureReason, 'import already running');
      expect(store.rowsWritten, 0);
      expect(store.isClosed, isTrue);
    });

    test(
      'the first build becomes active and a later one stays staged',
      () async {
        final first = succeeded(await import(SdeFixture.complete()));
        expect(first.state, BuildState.active);

        final later = SdeFixture.complete(build: 1001);
        final result = succeeded(await import(later));
        expect(result.state, BuildState.staged);
        expect(store.builds, {
          1000: BuildState.active,
          1001: BuildState.staged,
        });
        expect(store.typedRows(1000, 'sde_type'), hasLength(2));
      },
    );

    test(
      'a commit removes every other staged build, never the active one',
      () async {
        succeeded(await import(SdeFixture.complete()));
        succeeded(await import(SdeFixture.complete(build: 1001)));
        succeeded(await import(SdeFixture.complete(build: 999)));

        expect(store.builds, {1000: BuildState.active, 999: BuildState.staged});
        expect(store.typedRows(1001, 'sde_type'), isEmpty);
        expect(store.rawRecords(1001), isEmpty);
        expect(store.typedRows(1000, 'sde_type'), isNotEmpty);
      },
    );

    test('an import removes the staged build before writing and keeps active '
        'and previous', () async {
      store
        ..seedBuild(1000, BuildState.active)
        ..seedBuild(999, BuildState.previous)
        ..seedBuild(1001, BuildState.staged);
      final seen = <Map<int, BuildState>>[];

      final result = await ImportSdeJob(
        store: store,
        source: _HookedSource(
          LocalZipSdeSource(
            SdeFixture.complete(build: 1002).writeTo(zips),
            scratchRoot: scratch,
          ),
          (index) {
            if (index == 0) seen.add(store.builds);
          },
        ),
      ).run();

      succeeded(result);
      expect(seen, [
        {1000: BuildState.active, 999: BuildState.previous},
      ], reason: 'build 1001 is gone before the first file is read');
      expect(store.builds, {
        1000: BuildState.active,
        999: BuildState.previous,
        1002: BuildState.staged,
      });
    });

    test('a failed import leaves the staged build removed and active and '
        'previous unchanged', () async {
      store
        ..seedBuild(1000, BuildState.active)
        ..seedBuild(999, BuildState.previous)
        ..seedBuild(1001, BuildState.staged);

      final result = await ImportSdeJob(
        store: store,
        source: _HookedSource(
          LocalZipSdeSource(
            SdeFixture.complete(build: 1002).writeTo(zips),
            scratchRoot: scratch,
          ),
          (index) {
            if (index == 2) throw const SdeSourceException('entry broke');
          },
        ),
      ).run();

      expect(result, isA<ImportFailed>(), reason: '$result');
      expect(store.builds, {1000: BuildState.active, 999: BuildState.previous});
      expect(store.typedRows(1002, 'sde_category'), isEmpty);
      expect(store.typedRows(1001, 'sde_type'), isEmpty);
    });

    test(
      'an import of the staged build itself skips and removes nothing',
      () async {
        store
          ..seedBuild(1000, BuildState.active)
          ..seedBuild(1001, BuildState.staged);

        final result = await import(SdeFixture.complete(build: 1001));

        expect(result, isA<ImportSkipped>(), reason: '$result');
        expect(store.builds, {
          1000: BuildState.active,
          1001: BuildState.staged,
        });
      },
    );

    test('first build becomes active with no previous build', () async {
      final result = succeeded(await import(SdeFixture.complete()));

      expect(result.state, BuildState.active);
      expect(store.builds, {_build: BuildState.active});
    });

    test(
      'other running records are marked interrupted under the lock',
      () async {
        final stale = await store.insertRecord(
          ImportRecord(
            source: SdeSourceKind.ccp,
            startedAt: DateTime.utc(2026),
            outcome: ImportOutcome.running,
          ),
        );
        succeeded(await import(SdeFixture.complete()));

        final byId = {for (final r in store.records) r.id: r.record};
        expect(byId[stale]!.outcome, ImportOutcome.failed);
        expect(byId[stale]!.failureReason, 'interrupted');
        expect(byId.values.last.outcome, ImportOutcome.succeeded);
      },
    );

    test('a success records itself with four reports and is pruned', () async {
      var clock = DateTime.utc(2026, 1, 1);
      DateTime now() => clock = clock.add(const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        await store.insertRecord(
          ImportRecord(
            source: SdeSourceKind.local,
            startedAt: DateTime.utc(2025, 1, 1 + i),
            outcome: ImportOutcome.failed,
          ),
        );
      }
      final job = ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(
          SdeFixture.complete().writeTo(zips),
          scratchRoot: scratch,
        ),
        clock: now,
        keepRecords: 3,
      );
      final result = succeeded(await job.run());

      expect(store.records, hasLength(3));
      final record = store.records.last.record;
      expect(record.outcome, ImportOutcome.succeeded);
      expect(record.build, _build);
      expect(record.finishedAt, isNotNull);
      final report = record.report!;
      expect(report.fileCounts['types.jsonl'], 2);
      expect(report.drift.toSdeJson().value, contains('newFiles'));
      expect(report.badRecords.toSdeJson().value['total'], 0);
      expect(report.knownIds.toSdeJson().value['passed'], isTrue);
      expect(report.fieldCheck.toSdeJson().value['complete'], isTrue);
      expect(result.report, same(report));
    });

    test('rows are written in batches of the given size', () async {
      final fixture = SdeFixture.complete();
      fixture.files['factions.jsonl'] = [
        for (var i = 0; i < 25; i++) {'_key': i},
      ];
      succeeded(await import(fixture, batchSize: 4));
      expect(store.rawRecordsOf(_build, 'factions.jsonl'), hasLength(25));
    });

    test('an error after rows were written rolls everything back', () async {
      succeeded(await import(SdeFixture.complete()));
      final rowsBefore = store.rowsWritten;

      // A source whose last file breaks after the earlier files were read and
      // their rows were handed to the transaction.
      final inner = LocalZipSdeSource(
        SdeFixture.complete(build: 1001).writeTo(zips, 'second.zip'),
        scratchRoot: scratch,
      );
      final result = await ImportSdeJob(
        store: store,
        source: _BreakingSource(inner, breakAfter: 'groups.jsonl'),
      ).run();

      expect(result, isA<ImportFailed>());
      expect((result as ImportFailed).reason, 'entry broke');
      expect(result.build, 1001);
      expect(store.builds, {1000: BuildState.active});
      expect(store.rowsWritten, rowsBefore, reason: 'no row of 1001 remains');
      expect(store.typedRows(1001, 'sde_category'), isEmpty);
      expect(store.records.last.record.outcome, ImportOutcome.failed);
      expect(store.records.last.record.failureReason, 'entry broke');
    });

    test('an import past the time limit fails as timed out', () async {
      var clock = DateTime.utc(2026);
      DateTime now() => clock = clock.add(const Duration(minutes: 30));
      final result = await import(
        SdeFixture.complete(),
        limits: const SdeLimits(importTimeout: Duration(hours: 1)),
        clock: now,
      );

      expect((result as ImportFailed).reason, 'timed out');
      expect(store.builds, isEmpty);
      expect(store.rowsWritten, 0);
    });

    test('the store is unlocked and closed whatever the outcome', () async {
      await import(SdeFixture.complete());
      expect(store.isClosed, isTrue);
      expect(store.lock.isHeld, isFalse);

      final failing = InMemoryStaticDataStore();
      await import(
        SdeFixture.complete()..files.remove('types.jsonl'),
        into: failing,
      );
      expect(failing.isClosed, isTrue);
      expect(failing.lock.isHeld, isFalse);
    });
  });
}

/// Hands out the inner source's archive, but the file after [breakAfter]
/// (in name order) throws instead of yielding lines.
final class _BreakingSource implements SdeSource {
  _BreakingSource(this.inner, {required this.breakAfter});

  final SdeSource inner;
  final String breakAfter;

  @override
  SdeSourceKind get kind => inner.kind;

  @override
  Future<int?> announcedBuild() => inner.announcedBuild();

  @override
  Future<SdeArchive> open() async =>
      _BreakingArchive(await inner.open(), breakAfter);
}

final class _BreakingArchive implements SdeArchive {
  _BreakingArchive(this.inner, this.breakAfter);

  final SdeArchive inner;
  final String breakAfter;

  @override
  List<String> get fileNames => inner.fileNames;

  @override
  Stream<SdeLine> lines(String fileName) {
    final names = fileNames;
    final index = names.indexOf(breakAfter);
    if (names.indexOf(fileName) > index && fileName != sdeRecordFileName) {
      return Stream.error(const SdeSourceException('entry broke'));
    }
    return inner.lines(fileName);
  }

  @override
  Future<void> close() => inner.close();
}

/// Hands out the inner source's archive, but calls [onRead] before each file
/// but `_sde` is read, counting from 0. [onRead] may throw.
final class _HookedSource implements SdeSource {
  _HookedSource(this.inner, this.onRead);

  final SdeSource inner;
  final void Function(int index) onRead;

  @override
  SdeSourceKind get kind => inner.kind;

  @override
  Future<int?> announcedBuild() => inner.announcedBuild();

  @override
  Future<SdeArchive> open() async => _HookedArchive(await inner.open(), onRead);
}

final class _HookedArchive implements SdeArchive {
  _HookedArchive(this.inner, this.onRead);

  final SdeArchive inner;
  final void Function(int index) onRead;
  int _reads = 0;

  @override
  List<String> get fileNames => inner.fileNames;

  @override
  Stream<SdeLine> lines(String fileName) {
    if (fileName == sdeRecordFileName) return inner.lines(fileName);
    final index = _reads++;
    return Stream.fromFuture(Future.sync(() => onRead(index)))
        .asyncExpand((_) => inner.lines(fileName));
  }

  @override
  Future<void> close() => inner.close();
}
