/// Checks that keep `kaname_esi` free of any network access of its own
/// (design D11 and constraint C1 of `esi-client-generator`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The only SDK libraries a file under the package's `lib/` may name.
const Set<String> allowedDartLibraries = {
  'dart:core',
  'dart:async',
  'dart:convert',
  'dart:collection',
  'dart:math',
  'dart:typed_data',
};

/// Every problem with the import, export, part and conditional-import URIs
/// of the `.dart` files under [packageRoot]'s `lib/`, generated files
/// included. Each problem names the file (relative to [packageRoot]) and the
/// URI. Empty when every URI is an allowed `dart:` library or resolves
/// inside `lib/` (relative, or `package:<packageName>/`).
List<String> boundaryProblems(String packageRoot, String packageName) {
  final lib = Directory(p.join(packageRoot, 'lib'));
  if (!lib.existsSync()) return const [];
  final problems = <String>[];
  final files =
      lib
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final relative = p.posix.joinAll(
      p.split(p.relative(file.path, from: packageRoot)),
    );
    for (final uri in directiveUris(file.readAsStringSync())) {
      if (_why(uri, relative, packageName) case final String reason) {
        problems.add('$relative: $uri $reason');
      }
    }
  }
  return problems;
}

String? _why(String uri, String file, String packageName) {
  if (uri.startsWith('dart:')) {
    return allowedDartLibraries.contains(uri)
        ? null
        : 'is not one of the allowed dart: libraries '
              '(${allowedDartLibraries.join(', ')})';
  }
  if (uri.startsWith('package:')) {
    return uri.startsWith('package:$packageName/')
        ? null
        : 'leaves the package';
  }
  if (Uri.tryParse(uri) case Uri(hasScheme: true)) return 'leaves the package';
  final target = p.posix.normalize(p.posix.join(p.posix.dirname(file), uri));
  return target.startsWith('lib/') ? null : 'leaves lib/';
}

/// The runtime dependencies listed in the pubspec at [pubspecPath], by name.
List<String> runtimeDependencies(String pubspecPath) {
  final yaml = loadYaml(File(pubspecPath).readAsStringSync());
  if (yaml case {'dependencies': final Map<Object?, Object?> deps}) {
    return [for (final name in deps.keys) '$name'];
  }
  return const [];
}

/// Every URI named by the directives at the start of [source]: each
/// `import`, `export` and `part` URI, including every conditional-import
/// alternative and `part of` URIs.
///
/// Comments are skipped, and the scan stops at the first token that cannot
/// begin a directive or an annotation, so text in later string literals is
/// never read.
List<String> directiveUris(String source) {
  final text = _withoutComments(source);
  final uris = <String>[];
  var i = 0;
  final directive = RegExp(r'(library|import|export|part)\b');
  final annotation = RegExp(r'@[A-Za-z_$][\w$.]*(\s*\([^)]*\))?');
  final literal = RegExp(r'''r?('[^'\n]*'|"[^"\n]*")''');
  while (true) {
    while (i < text.length && text[i].trim().isEmpty) {
      i++;
    }
    if (i >= text.length) break;
    if (annotation.matchAsPrefix(text, i) case final Match m) {
      i = m.end;
      continue;
    }
    final match = directive.matchAsPrefix(text, i);
    if (match == null) break;
    final end = _directiveEnd(text, match.end);
    if (end < 0) break;
    final body = text.substring(match.end, end);
    if (match.group(1) != 'library') {
      for (final m in literal.allMatches(body)) {
        final quoted = m.group(1)!;
        uris.add(quoted.substring(1, quoted.length - 1));
      }
    }
    i = end + 1;
  }
  return uris;
}

/// The index of the `;` ending the directive whose body starts at [start],
/// skipping semicolons inside string literals; -1 when there is none.
int _directiveEnd(String text, int start) {
  String? quote;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == ';') {
      return i;
    }
  }
  return -1;
}

/// [source] with every comment replaced by spaces, keeping string literals.
String _withoutComments(String source) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < source.length) {
    final c = source[i];
    if (quote != null) {
      out.write(c);
      if (c == '\\' && i + 1 < source.length) {
        out.write(source[i + 1]);
        i += 2;
        continue;
      }
      if (source.startsWith(quote, i)) {
        out.write(source.substring(i + 1, i + quote.length));
        i += quote.length;
        quote = null;
        continue;
      }
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      var depth = 0;
      while (i < source.length) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
          if (depth == 0) break;
        } else {
          i++;
        }
      }
      out.write(' ');
      continue;
    }
    for (final q in const ["'''", '"""', "'", '"']) {
      if (source.startsWith(q, i)) {
        quote = q;
        out.write(q);
        i += q.length;
        break;
      }
    }
    if (quote == null) {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}
