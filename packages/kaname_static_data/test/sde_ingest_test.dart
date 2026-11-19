import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

/// Records the size of every batch it is given.
final class _BatchRecorder implements StaticDataWriter {
  final List<int> rawBatches = [];

  @override
  Future<void> insertRaw(int build, List<RawRecord> records) async =>
      rawBatches.add(records.length);

  @override
  Future<void> insertTyped(int build, List<TypedRow> rows) async {}

  @override
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  }) async {}

  @override
  Future<void> switchTo(int build, {required DateTime at}) =>
      throw UnimplementedError('the ingest never switches');

  @override
  Future<void> rollBack({required DateTime at}) =>
      throw UnimplementedError('the ingest never rolls back');
}

Stream<SdeLine> _lines(Iterable<String> texts) async* {
  var number = 0;
  for (final text in texts) {
    yield SdeTextLine(++number, text);
  }
}

void main() {
  test('a batch is written once its lines pass the byte bound', () async {
    final writer = _BatchRecorder();
    final ingest = SdeIngest(
      build: 1,
      writer: writer,
      fieldCheck: FieldCheckCollector(const []),
      checkDeadline: () {},
      batchSize: 500,
      maxBatchBytes: 100,
    );
    final line = '{"_key": 1, "text": "${'x' * 40}"}';

    await ingest.ingestFile('somethingRaw.jsonl', _lines(List.filled(6, line)));

    // Each line is over 50 bytes: two of them pass the 100-byte bound.
    expect(writer.rawBatches, [2, 2, 2]);
    expect(ingest.fileCounts['somethingRaw.jsonl'], 6);
  });

  test('small lines are still written in batches of batchSize', () async {
    final writer = _BatchRecorder();
    final ingest = SdeIngest(
      build: 1,
      writer: writer,
      fieldCheck: FieldCheckCollector(const []),
      checkDeadline: () {},
      batchSize: 4,
    );

    await ingest.ingestFile(
      'somethingRaw.jsonl',
      _lines(List.filled(10, '{"_key": 1}')),
    );

    expect(writer.rawBatches, [4, 4, 2]);
  });
}
