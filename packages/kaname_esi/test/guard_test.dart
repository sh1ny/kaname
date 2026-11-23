import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/package_boundary.dart';

void main() {
  group('the package itself', () {
    test('names only allowed libraries and its own files', () {
      expect(boundaryProblems('.', 'kaname_esi'), isEmpty);
    });

    test('has no runtime dependencies', () {
      expect(runtimeDependencies('pubspec.yaml'), isEmpty);
    });
  });

  group('the boundary scanner', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('kaname_esi_guard'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) {
      File(p.join(root.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    List<String> problems() => boundaryProblems(root.path, 'kaname_esi');

    test('accepts the allowed libraries and package-local URIs', () {
      write('lib/a.dart', '''
// import 'dart:io'; in a comment is not a directive.
/* import 'dart:html'; */
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show jsonDecode;
import 'dart:core';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:kaname_esi/kaname_esi.dart';
import 'src/b.dart';
export 'src/b.dart';
part 'src/c.dart';

const text = "import 'dart:io';";
''');
      write('lib/src/b.dart', "import '../a.dart';\n");
      write('lib/src/c.dart', "part of '../a.dart';\n");
      expect(problems(), isEmpty);
    });

    // Scenario: Disallowed library imported.
    for (final (kind, directive) in [
      ('import', "import 'dart:html';"),
      ('export', "export 'dart:io';"),
      (
        'conditional import',
        "import 'src/x.dart'\n    if (dart.library.js_interop) 'dart:js_interop';",
      ),
    ]) {
      test('a disallowed dart: library in a $kind fails naming the file '
          'and the library', () {
        write('lib/src/x.dart', '');
        write('lib/src/generated/models.dart', '$directive\n');
        final found = problems();
        expect(found, hasLength(1));
        expect(found.single, startsWith('lib/src/generated/models.dart: '));
        expect(found.single, contains(RegExp(r'dart:(html|io|js_interop)')));
      });
    }

    test('nested metadata before the library does not hide a disallowed '
        'import', () {
      write(
        'lib/src/a.dart',
        "@Deprecated(_Note(('x', ')')))\n"
            '@pragma("vm:entry-point")\n'
            'library;\n\n'
            "import 'dart:io';\n",
      );
      final found = problems();
      expect(found, hasLength(1));
      expect(found.single, startsWith('lib/src/a.dart: dart:io '));
    });

    // Scenario: Import leaves the package.
    for (final (kind, directive, uri) in [
      (
        'import',
        "import 'package:kaname_core/kaname_core.dart';",
        'package:kaname_core/kaname_core.dart',
      ),
      (
        'export',
        "export '../../test/support/package_boundary.dart';",
        '../../test/support/package_boundary.dart',
      ),
      (
        'conditional import',
        "import 'b.dart' if (dart.library.io) 'package:http/http.dart';",
        'package:http/http.dart',
      ),
      ('part', "part '../../tool/x.dart';", '../../tool/x.dart'),
    ]) {
      test('a $kind leaving the package fails naming the file and the URI, '
          'with the pubspec unchanged', () {
        write('pubspec.yaml', 'name: kaname_esi\n');
        write('lib/src/b.dart', '');
        write('lib/src/a.dart', '$directive\n');
        final found = problems();
        expect(found, hasLength(1));
        expect(found.single, startsWith('lib/src/a.dart: $uri '));
        expect(runtimeDependencies(p.join(root.path, 'pubspec.yaml')), isEmpty);
      });
    }

    // Scenario: Runtime dependency added.
    test('a runtime dependency is reported by name', () {
      write('pubspec.yaml', '''
name: kaname_esi
dependencies:
  http: ^1.0.0
dev_dependencies:
  test: ^1.26.0
''');
      expect(runtimeDependencies(p.join(root.path, 'pubspec.yaml')), ['http']);
    });
  });
}
