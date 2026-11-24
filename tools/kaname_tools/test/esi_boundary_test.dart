import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('reports direct production ESI access', () {
    expect(
      _bypass('''
        import 'package:kaname_esi/kaname_esi.dart' as esi;
        final uri = Uri.https('esi.' 'evetech.net', '/status');
        final factory = esi.EsiClient.new;
      '''),
      ['unscheduled ESI client import', 'direct ESI origin'],
    );
    expect(
      _bypass('''
        import 'package:kaname_esi/kaname_esi.dart' show EsiResult, EsiSuccess;
        // An example may mention https://esi.evetech.net without sending there.
      '''),
      isEmpty,
    );
  });

  test('reports independent scheduler construction in a product module', () {
    expect(
      _bypass('''
        import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart' as esi;
        final scheduler = esi.EsiScheduler(
          state: esi.MemorySchedulerState(), key: [1], send: sendDirect,
        );
      '''),
      ['ESI scheduler composition outside its owner'],
    );
    expect(
      _bypass('''
        import 'dart:io' if (dart.library.io)
          'package:kaname_esi_scheduler/native.dart';
      '''),
      ['ESI scheduler composition outside its owner'],
    );
    expect(
      _bypass('''
        import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart'
          show EsiPriority, EsiPrincipal;
      '''),
      isEmpty,
    );
  });

  test('production modules cannot bypass the ESI scheduler', () {
    final root = p.normalize(p.absolute('../..'));
    final violations = <String>[];
    for (final parent in [
      'app',
      'server',
      'packages',
      'app_packages',
      'tools',
    ]) {
      final directory = Directory(p.join(root, parent));
      for (final member
          in parent == 'app'
              ? [directory]
              : directory.listSync(followLinks: false).whereType<Directory>()) {
        for (final subdir in ['lib', 'bin']) {
          final sources = Directory(p.join(member.path, subdir));
          if (!sources.existsSync()) continue;
          for (final file
              in sources
                  .listSync(recursive: true, followLinks: false)
                  .whereType<File>()) {
            if (!file.path.endsWith('.dart')) continue;
            final relative = p
                .split(p.relative(file.path, from: root))
                .join('/');
            final ownClient = relative.startsWith('packages/kaname_esi/lib/');
            final scheduled =
                relative ==
                'packages/kaname_esi_scheduler/lib/src/scheduler.dart';
            final native =
                relative == 'packages/kaname_esi_scheduler/lib/native.dart';
            final supported =
                relative.startsWith('packages/kaname_esi_scheduler/lib/src/') ||
                relative.startsWith('server/kaname_server/lib/src/esi/');
            final pinFetch =
                relative == 'tools/kaname_tools/lib/src/esi_fetch.dart';
            if (ownClient) continue;
            for (final reason in _bypass(
              file.readAsStringSync(),
              allowImport: supported || native || scheduled,
              allowOrigin: pinFetch || native,
            )) {
              violations.add('$relative: $reason');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

List<String> _bypass(
  String source, {
  bool allowImport = false,
  bool allowOrigin = false,
}) {
  final visitor = _Boundary(allowImport, allowOrigin);
  parseString(content: source, throwIfDiagnostics: false).unit.accept(visitor);
  return visitor.violations;
}

final class _Boundary extends RecursiveAstVisitor<void> {
  _Boundary(this.allowImport, this.allowOrigin);

  static const _sendTypes = {
    'EsiClient',
    'EsiTransport',
    'EsiCall',
    'EsiRequest',
  };
  static const _compositionTypes = {
    'EsiScheduler',
    'MemorySchedulerState',
    'SchedulerState',
    'EsiWireSend',
  };
  final bool allowImport;
  final bool allowOrigin;
  final violations = <String>[];

  @override
  void visitImportDirective(ImportDirective node) {
    _checkImport(node.uri.stringValue, node.combinators);
    for (final alternative in node.configurations) {
      _checkImport(alternative.uri.stringValue, node.combinators);
    }
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkImport(node.uri.stringValue, node.combinators);
    for (final alternative in node.configurations) {
      _checkImport(alternative.uri.stringValue, node.combinators);
    }
  }

  void _checkImport(String? uri, Iterable<Combinator> combinators) {
    if (allowImport || uri == null) return;
    final (blocked, message) = switch (uri) {
      'package:kaname_esi/kaname_esi.dart' => (
        _sendTypes,
        'unscheduled ESI client import',
      ),
      'package:kaname_esi_scheduler/kaname_esi_scheduler.dart' => (
        _compositionTypes,
        'ESI scheduler composition outside its owner',
      ),
      _
          when uri.startsWith('package:kaname_esi_scheduler/') ||
              uri.endsWith('/esi/redis_scheduler_state.dart') =>
        (null, 'ESI scheduler composition outside its owner'),
      _ when uri.startsWith('package:kaname_esi/src/') => (
        null,
        'unscheduled ESI client import',
      ),
      _ => (null, null),
    };
    if (message == null) return;
    if (blocked == null) {
      violations.add(message);
      return;
    }
    var available = blocked;
    for (final c in combinators) {
      if (c is ShowCombinator) {
        available = available.intersection({
          for (final name in c.shownNames) name.name,
        });
      } else if (c is HideCombinator) {
        available = available.difference({
          for (final name in c.hiddenNames) name.name,
        });
      }
    }
    if (available.isNotEmpty) violations.add(message);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) =>
      _checkOrigin(node.stringValue);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      _checkOrigin(node.stringValue);

  void _checkOrigin(String? value) {
    if (!allowOrigin &&
        value != null &&
        value.toLowerCase().contains('esi.evetech.net')) {
      violations.add('direct ESI origin');
    }
  }
}
