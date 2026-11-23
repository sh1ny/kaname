import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/change_report_cap.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

RecordChanges _changes(int length, {bool truncated = false}) => RecordChanges(
  count: length + (truncated ? 25 : 0),
  keys: [for (var i = 0; i < length; i++) 'key-$i'],
  truncated: truncated,
);

FileDiff _file(
  String name, {
  required RecordChanges added,
  required RecordChanges removed,
  required RecordChanges changed,
  Map<String, int> fields = const {},
  DiffFileStatus status = DiffFileStatus.both,
}) => FileDiff(
  file: name,
  status: status,
  added: added,
  removed: removed,
  changed: changed,
  changedFields: fields,
);

BuildDiffReport _report(List<FileDiff> files) =>
    BuildDiffReport(fromBuild: 12, toBuild: 13, files: files);

void main() {
  test('40 files of 3,000 keys are cut to 20,000 keys with complete counts and marked lists', () {
    final changes = _changes(1000);
    final source = _report([
      for (var i = 0; i < 40; i++)
        _file('file-$i', added: changes, removed: changes, changed: changes),
    ]);
    final answer = capChangeReport(source, activeBuild: 12);
    expect(answer.outcome, StaticDataReportOutcome.reportReady);
    expect(
      (answer.activeBuild, answer.fromBuild, answer.toBuild),
      (12, 12, 13),
    );
    final files = answer.files!;
    expect(
      files.map((file) => file.file),
      source.files.map((file) => file.file),
    );
    var total = 0;
    for (final file in files) {
      for (final changes in [file.added, file.removed, file.changed]) {
        expect(changes.count, 1000);
        final remaining = 20000 - total;
        final expected = remaining < 1000 ? remaining : 1000;
        expect(
          changes.keys,
          source.files.first.added.keys.take(expected).toList(),
        );
        expect(changes.cutOff, expected < 1000);
        total += changes.keys.length;
      }
    }
    expect(total, 20000);
  });

  test('a 300-key report keeps every key and marks nothing', () {
    final changes = _changes(100);
    final answer = capChangeReport(
      _report([
        _file(
          'new',
          added: changes,
          removed: changes,
          changed: changes,
          status: DiffFileStatus.newFile,
        ),
      ]),
      activeBuild: 13,
    );
    final file = answer.files!.single;
    expect(file.status, StaticDataReportFileStatus.newFile);
    for (final entry in [file.added, file.removed, file.changed]) {
      expect(entry.keys, changes.keys);
      expect(entry.count, 100);
      expect(entry.cutOff, isFalse);
    }
    expect(file.changedFieldCount, 0);
    expect(file.changedFieldsCutOff, isFalse);
  });

  test('a list stored as cut off keeps its keys and its mark', () {
    final stored = _changes(1000, truncated: true);
    final other = _changes(500);
    const empty = RecordChanges(count: 0);
    final file = capChangeReport(
      _report([
        _file(
          'removed',
          added: stored,
          removed: other,
          changed: empty,
          status: DiffFileStatus.removedFile,
        ),
      ]),
      activeBuild: 13,
    ).files!.single;
    expect(file.status, StaticDataReportFileStatus.removedFile);
    expect(file.added.keys, stored.keys);
    expect(file.added.count, 1025);
    expect(file.added.cutOff, isTrue);
    expect(file.removed.keys, other.keys);
    expect(file.removed.cutOff, isFalse);
    expect(file.changed.cutOff, isFalse);
  });

  test('350 changed fields are cut to 200, marked, with the full number', () {
    final fields = {
      for (var i = 349; i >= 0; i--)
        'field-${i.toString().padLeft(3, '0')}': i + 1,
    };
    const empty = RecordChanges(count: 0);
    final file = capChangeReport(
      _report([
        _file(
          'fields',
          added: empty,
          removed: empty,
          changed: empty,
          fields: fields,
        ),
      ]),
      activeBuild: 13,
    ).files!.single;
    expect(file.changedFieldCount, 350);
    expect(file.changedFieldsCutOff, isTrue);
    expect(file.changedFields, {
      for (var i = 0; i < 200; i++)
        'field-${i.toString().padLeft(3, '0')}': i + 1,
    });
    expect(file.changedFields.keys.toList(), [
      for (var i = 0; i < 200; i++) 'field-${i.toString().padLeft(3, '0')}',
    ]);
    expect(fields.length, 350);
  });
}
