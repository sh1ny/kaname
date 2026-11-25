import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('recognizes ORM and raw SQL access without flagging scoped reads', () {
    expect(
      _references('''
        Future<void> fetch(EsiCallLogRow row) async {
          await db.query('SELECT * FROM esi_' 'call_log_entry');
          final table = generated.EsiCallLogRowTable();
          final all = await generated.EsiCallLogRow.db.find(session);
        }
      '''),
      {'EsiCallLogRow', 'EsiCallLogRowTable', 'esi_call_log_entry'},
    );
    expect(
      _references('''
      // EsiCallLogRow is private. Don't query esi_call_log_entry here.
      final rows = await EsiCallLogStore().ownRows(session, viewer);
    '''),
      isEmpty,
    );
  });

  test(
    'production server reads call history only through its scoped store',
    () {
      final server = p.normalize(p.absolute('../../server/kaname_server'));
      final violations = <String>[];
      for (final directory in ['lib', 'bin']) {
        final sources = Directory(p.join(server, directory));
        for (final file
            in sources
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final relative = p
              .split(p.relative(file.path, from: server))
              .join('/');
          if (relative.startsWith('lib/src/generated/') ||
              relative == 'lib/src/esi/esi_call_log_store.dart') {
            continue;
          }
          for (final symbol in _references(file.readAsStringSync())) {
            violations.add('$relative: $symbol bypasses call-log privacy');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}

Set<String> _references(String source) {
  final visitor = _StorageReferences();
  parseString(content: source, throwIfDiagnostics: false).unit.accept(visitor);
  return visitor.found;
}

final class _StorageReferences extends RecursiveAstVisitor<void> {
  static const _types = {'EsiCallLogRow', 'EsiCallLogRowTable'};
  static const _table = 'esi_call_log_entry';
  final found = <String>{};

  void _checkIdentifier(String name) {
    if (_types.contains(name)) found.add(name);
  }

  void _checkString(String? value) {
    if (value != null && value.toLowerCase().contains(_table)) {
      found.add(_table);
    }
  }

  @override
  void visitNamedType(NamedType node) {
    _checkIdentifier(node.name.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) =>
      _checkIdentifier(node.name);

  @override
  void visitAdjacentStrings(AdjacentStrings node) =>
      _checkString(node.stringValue);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      _checkString(node.value);

  @override
  void visitInterpolationString(InterpolationString node) =>
      _checkString(node.value);
}
