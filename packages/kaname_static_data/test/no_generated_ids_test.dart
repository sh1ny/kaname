/// The source scan that keeps SDE content out of generated code.
///
/// **C5:** no Dart code, enum or constant is generated from SDE content; ids
/// code needs go in `knownIds`. The scan is a heuristic backstop for review:
/// it fails when Dart source in the workspace's packages, outside the file
/// that holds `knownIds`, declares an integer constant or an enum value with
/// an integer whose name reads as a type, group, category, attribute or
/// effect id, and when a tool or build hook reads SDE input to write `.dart`
/// source.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/id_constant_scanner.dart';

/// Files the scan does not read: the file that holds `knownIds`, and the scan
/// itself, whose positive-control fixtures contain what it looks for.
const Set<String> _exempt = {
  'packages/kaname_static_data/lib/src/known_ids.dart',
  'packages/kaname_static_data/test/no_generated_ids_test.dart',
  'packages/kaname_static_data/test/support/id_constant_scanner.dart',
};

Directory _workspaceRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: kaname_workspace')) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('workspace root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

void main() {
  test('no id constants outside knownIds', () {
    final findings = scanWorkspace(_workspaceRoot(), exemptPaths: _exempt);
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  group('the scan itself', () {
    test('positive control: an id constant is flagged', () {
      const source = '''
/// A fixture.
const typeIdTritanium = 34;
''';
      final findings = scanSource('packages/x/lib/a.dart', source);
      expect(findings, hasLength(1));
      expect(findings.single.file, 'packages/x/lib/a.dart');
      expect(findings.single.line, 2);
      expect(findings.single.message, contains('typeIdTritanium'));
    });

    test('flags the other id spellings, enum values and static members', () {
      const source = r'''
class Ids {
  static const int tritaniumTypeId = 34;
  static final categoryIdShip = 6;
}
const ATTRIBUTE_ID_MASS = 4;
const int effect_id_online = 16;
enum Ore {
  veldspar(1230),
  groupIdAsteroid(25),
  ;
  const Ore(this.id);
  final int id;
}
''';
      final findings = scanSource('a.dart', source);
      expect(findings.map((f) => f.line), [2, 3, 5, 6, 9]);
    });

    test('does not flag ordinary code', () {
      const source = r'''
int typeIdColumnIndex = 3;
void f() {
  var groupIdCount = 0;
  final typeId = readId();
  final categoryId = row['categoryID'] as int;
}
const maxTypeCount = 5;
const defaultTimeout = 30;
// const typeIdTritanium = 34;
const String typeIdLabel = 'Type id';
enum Kind { type(true), group(false) }
''';
      expect(scanSource('a.dart', source), isEmpty);
    });

    test('flags a tool that reads SDE input to write .dart source', () {
      const generator = '''
import 'dart:io';
void main() {
  final lines = File('types.jsonl').readAsLinesSync();
  File('lib/type_ids.dart').writeAsStringSync(lines.join());
}
''';
      expect(scanSource('tools/gen/bin/gen.dart', generator), hasLength(1));
      // The same code outside a tool or hook is not this rule's business.
      expect(scanSource('packages/x/lib/gen.dart', generator), isEmpty);
      // A tool that reads SDE input and writes no Dart source is fine.
      const reporter = '''
void main() {
  final lines = File('types.jsonl').readAsLinesSync();
  File('report.md').writeAsStringSync(lines.join());
}
''';
      expect(scanSource('tools/gen/bin/report.dart', reporter), isEmpty);
    });

    test('a tool that only imports .dart files and prints is not a generator', () {
      const importer = '''
/// Run with `dart run tool/sde_import.dart`.
import 'dart:io';
import 'package:kaname_server/src/static_data/sde_import_args.dart';
export 'src/other.dart';
part 'part.dart';
void main() {
  final lines = File('types.jsonl').readAsLinesSync();
  stdout.writeln('read the sde');
  File('report.md').writeAsStringSync(lines.join());
}
''';
      expect(
        scanSource('server/kaname_server/tool/sde_import.dart', importer),
        isEmpty,
      );
      // A generator that names its .dart output in a string literal is flagged
      // wherever the tool lives, also when it prints too.
      const generator = '''
import 'dart:io';
void main() {
  final lines = File('types.jsonl').readAsLinesSync();
  stdout.writeln('writing');
  File("lib/ids.dart").writeAsStringSync(lines.join());
}
''';
      expect(
        scanSource('server/kaname_server/tool/gen.dart', generator),
        hasLength(1),
      );
    });

    test('the workspace scan reads the server tool, bin and client roots', () {
      expect(
        scannedRoots,
        containsAll([
          'server/kaname_server/tool',
          'server/kaname_server/bin',
          'server/kaname_client/lib',
        ]),
      );
      final copy = Directory.systemTemp.createTempSync('kaname_scan_roots_');
      addTearDown(() => copy.deleteSync(recursive: true));
      for (final dir in [
        'server/kaname_server/tool',
        'server/kaname_server/bin',
        'server/kaname_client/lib',
      ]) {
        final directory = Directory(p.join(copy.path, dir))
          ..createSync(recursive: true);
        File(p.join(directory.path, 'ids.dart'))
            .writeAsStringSync('const typeIdSeeded = 34;\n');
      }
      // The generated client protocol is not scanned.
      final protocol = Directory(
        p.join(copy.path, 'server', 'kaname_client', 'lib', 'src', 'protocol'),
      )..createSync(recursive: true);
      File(p.join(protocol.path, 'p.dart'))
          .writeAsStringSync('const typeIdGenerated = 1;\n');

      expect(scanWorkspace(copy).map((f) => f.file).toList()..sort(), [
        'server/kaname_client/lib/ids.dart',
        'server/kaname_server/bin/ids.dart',
        'server/kaname_server/tool/ids.dart',
      ]);
    });

    test('a seeded constant in a copy of the workspace fails the scan', () {
      final copy = Directory.systemTemp.createTempSync('kaname_scan_copy_');
      addTearDown(() => copy.deleteSync(recursive: true));
      final lib = Directory(p.join(copy.path, 'packages', 'seeded', 'lib'))
        ..createSync(recursive: true);
      File(p.join(lib.path, 'ids.dart'))
          .writeAsStringSync('library;\n\nconst typeIdTritanium = 34;\n');
      // Generated protocol code is skipped, and so is an exempt file.
      final generated = Directory(
        p.join(copy.path, 'server', 'kaname_server', 'lib', 'src', 'generated'),
      )..createSync(recursive: true);
      File(p.join(generated.path, 'protocol.dart'))
          .writeAsStringSync('const typeIdGenerated = 1;\n');

      final findings = scanWorkspace(copy);
      expect(findings.map((f) => '${f.file}:${f.line}'), [
        'packages/seeded/lib/ids.dart:3',
      ]);

      expect(
        scanWorkspace(copy, exemptPaths: {'packages/seeded/lib/ids.dart'}),
        isEmpty,
      );
    });
  });
}
