/// Finds Dart source that carries SDE ids or generates code from SDE content.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// One thing the scan objects to.
final class ScanFinding {
  /// Creates a finding in [file] at [line].
  const ScanFinding(this.file, this.line, this.message);

  /// The path of the file, relative to the scanned root.
  final String file;

  /// The 1-based line.
  final int line;

  /// What is wrong.
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

/// The directories of the workspace that the scan reads, relative to its root.
const List<String> scannedRoots = [
  'packages',
  'app_packages',
  'app/lib',
  'tools',
  'server/kaname_server/lib',
  'server/kaname_server/tool',
  'server/kaname_server/bin',
  'server/kaname_client/lib',
];

/// A name that reads as the id of a type, group, category, attribute or
/// effect: it starts or ends with one of those words followed by `Id`.
final RegExp idName = RegExp(
  r'^(?:(?:type|group|category|attribute|effect)_?id\w*|\w*(?:type|group|category|attribute|effect)_?id)$',
  caseSensitive: false,
);

// `const int typeIdX = 34;`, `static const typeIdX = 34;`,
// `static final int typeIdX = 34;`, or a top-level `final typeIdX = 34;`.
final RegExp _constantDeclaration = RegExp(
  r'^\s*(?:static\s+)?(?:const|final)\s+(?:int\s+)?(\w+)\s*=\s*-?(?:0x[0-9a-fA-F_]+|[0-9_]+)\s*;',
);

final RegExp _enumHeader = RegExp(r'\benum\s+\w+[^{]*\{');
final RegExp _enumIntegerValue = RegExp(r'(\w+)\s*\(\s*-?\d[\d_]*\s*\)');

/// Whether a file is a tool or build hook, by its path.
bool _isToolOrHook(String relativePath) {
  final parts = p.posix.split(relativePath);
  return parts.contains('tools') ||
      parts.contains('tool') ||
      parts.contains('hook') ||
      p.posix.basename(relativePath) == 'build.dart';
}

final RegExp _readsSde = RegExp(r'jsonl|\bsde\b', caseSensitive: false);
final RegExp _writesFiles = RegExp(r'writeAsString|writeAsBytes|openWrite');

/// A string literal that ends in `.dart`: the name of a file to write. An
/// import, export or part directive also ends in one, so those lines (and
/// comments) are left out before this is matched.
final RegExp _namesDartFile = RegExp(r'''\.dart['"]''');
final RegExp _directive = RegExp(r'^\s*(?:import|export|part)\s');

/// [text] without comment lines and import, export and part directives.
String _codeOnly(String text) => [
  for (final line in text.split('\n'))
    if (!line.trimLeft().startsWith('//') && !_directive.hasMatch(line)) line,
].join('\n');

/// Scans one file's [text]; [relativePath] is only used in the findings and
/// to tell tools and build hooks apart.
///
/// Reports, per line:
/// - an integer constant, or an enum value holding an integer, whose name
///   reads as a type, group, category, attribute or effect id;
/// - once per file, a tool or build hook that mentions SDE input and writes a
///   `.dart` file.
///
/// Comment lines are skipped. This is a heuristic: it does not parse Dart.
List<ScanFinding> scanSource(String relativePath, String text) {
  final findings = <ScanFinding>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    final name = _constantDeclaration.firstMatch(line)?.group(1);
    if (name != null && idName.hasMatch(name)) {
      findings.add(
        ScanFinding(
          relativePath,
          i + 1,
          'integer constant `$name` looks like an SDE id; put the id in knownIds',
        ),
      );
    }
  }
  for (final header in _enumHeader.allMatches(text)) {
    final bodyStart = header.end;
    final bodyEnd = text.indexOf(RegExp('[;}]'), bodyStart);
    final body = text.substring(bodyStart, bodyEnd < 0 ? text.length : bodyEnd);
    for (final value in _enumIntegerValue.allMatches(body)) {
      final name = value.group(1)!;
      if (!idName.hasMatch(name)) continue;
      final line =
          '\n'.allMatches(text.substring(0, bodyStart + value.start)).length +
          1;
      findings.add(
        ScanFinding(
          relativePath,
          line,
          'enum value `$name` holds an integer like an SDE id; put the id in knownIds',
        ),
      );
    }
  }
  final code = _codeOnly(text);
  if (_isToolOrHook(relativePath) &&
      _readsSde.hasMatch(code) &&
      _writesFiles.hasMatch(code) &&
      _namesDartFile.hasMatch(code)) {
    findings.add(
      ScanFinding(
        relativePath,
        1,
        'a tool or build hook reads SDE input and writes .dart source',
      ),
    );
  }
  return findings;
}

/// Scans every `.dart` file under [scannedRoots] in [root].
///
/// Generated protocol code under `src/generated` (and the client's
/// `src/protocol`) and `.dart_tool` and `build`
/// directories are skipped, and so are the files in [exemptPaths] (paths
/// relative to [root], in `/` form).
List<ScanFinding> scanWorkspace(
  Directory root, {
  Set<String> exemptPaths = const {},
}) {
  final findings = <ScanFinding>[];
  for (final scanned in scannedRoots) {
    final dir = Directory(p.join(root.path, scanned));
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != '.dart') continue;
      final relative = p.posix.joinAll(
        p.split(p.relative(entity.path, from: root.path)),
      );
      final parts = p.posix.split(relative);
      if (parts.contains('.dart_tool') || parts.contains('build')) continue;
      if (relative.contains('src/generated/')) continue;
      if (relative.startsWith('server/kaname_client/lib/src/protocol/')) {
        continue;
      }
      if (exemptPaths.contains(relative)) continue;
      findings.addAll(scanSource(relative, entity.readAsStringSync()));
    }
  }
  return findings;
}
