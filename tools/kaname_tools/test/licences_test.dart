import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';
import 'support/licence_fixtures.dart';

const _mit = '''
MIT License

Copyright (c) 2020 Someone

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _isc = '''
ISC License

Copyright (c) 2021, Example

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
''';

const _custom = 'Do whatever you like with this, we do not mind.\n';

const _allowedMit = '''
allowed:
  - MIT
  - BSD-3-Clause
exceptions: []
''';

/// One locked package: `name version source`.
typedef _Locked = (String, String, String);

String _lock(List<_Locked> packages) {
  final entries = [
    for (final (name, version, source) in packages)
      '  $name:\n'
          '    dependency: direct main\n'
          '    description: ${source == 'sdk' ? 'flutter' : name}\n'
          '    source: $source\n'
          '    version: "$version"\n',
  ];
  return 'packages:\n${entries.join()}sdks:\n  dart: ">=3.13.0 <4.0.0"\n';
}

/// A resolved repository: each hosted package `name` has the licence file
/// content given in [licences] (no file when absent) under `/cache/name`.
InMemoryFileSystem _repo({
  required List<_Locked> packages,
  Map<String, String> licences = const {},
  String? policy = _allowedMit,
}) {
  final fs = InMemoryFileSystem()..writeFile('pubspec.lock', _lock(packages));
  final roots = [
    for (final (name, _, _) in packages)
      '{"name": "$name", "rootUri": "file:///cache/$name", '
          '"packageUri": "lib/"}',
  ];
  fs.writeFile(
    '.dart_tool/package_config.json',
    '{"configVersion": 2, "packages": [${roots.join(', ')}]}',
  );
  for (final MapEntry(:key, :value) in licences.entries) {
    fs.writeFile('/cache/$key/LICENSE', value);
  }
  for (final (name, _, _) in packages) {
    fs.writeFile('/cache/$name/pubspec.yaml', 'name: $name\n');
  }
  if (policy != null) fs.writeFile('licence-policy.yaml', policy);
  return fs;
}

Future<CliResult> _check(InMemoryFileSystem fs) =>
    runTool(fs, ['licences', '--check']);

void main() {
  test('sky_engine is accepted as LicenseRef-flutter-engine-bundle and '
      'flutter as BSD-3-Clause', () async {
    final fs = _repo(
      packages: [
        ('flutter', '0.0.0', 'sdk'),
        ('flutter_test', '0.0.0', 'sdk'),
        ('sky_engine', '0.0.0', 'sdk'),
        ('alpha', '1.0.0', 'hosted'),
      ],
      licences: {'alpha': _mit},
    );

    final result = await _check(fs);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(result.out, contains('BSD-3-Clause: 2'));
    expect(result.out, contains('LicenseRef-flutter-engine-bundle: 1'));
    expect(result.out, contains('MIT: 1'));
  });

  test('unrecognised licence fails naming package and version', () async {
    final fs = _repo(
      packages: [('alpha', '1.0.0', 'hosted'), ('weird', '1.2.3', 'hosted')],
      licences: {'alpha': _mit, 'weird': _custom},
    );

    final result = await _check(fs);

    expect(result.code, 1);
    expect(result.err, contains('weird 1.2.3'));
    expect(result.err, contains('unrecognised'));
    expect(result.err, isNot(contains('alpha')));
  });

  test(
    'package without a licence file fails naming package and version',
    () async {
      final fs = _repo(
        packages: [('alpha', '1.0.0', 'hosted'), ('bare', '0.4.0', 'hosted')],
        licences: {'alpha': _mit},
      );

      final result = await _check(fs);

      expect(result.code, 1);
      expect(result.err, contains('bare 0.4.0'));
      expect(result.err, contains('no licence file'));
    },
  );

  test('unresolved workspace fails with the resolve hint', () async {
    final fs = _repo(
      packages: [('alpha', '1.0.0', 'hosted')],
      licences: {'alpha': _mit},
    )..deleteFile('.dart_tool/package_config.json');

    final result = await _check(fs);

    expect(result.code, 1);
    expect(result.err, contains('mise run resolve'));
    expect(result.out, isEmpty);
  });

  test('all allowed passes and prints counts per identifier', () async {
    final fs = _repo(
      packages: [
        ('alpha', '1.0.0', 'hosted'),
        ('beta', '2.0.0', 'hosted'),
        ('gamma', '3.0.0', 'hosted'),
      ],
      licences: {'alpha': _mit, 'beta': _mit, 'gamma': bsdGoogleLlc},
    );

    final result = await _check(fs);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(result.out, contains('MIT: 2'));
    expect(result.out, contains('BSD-3-Clause: 1'));
  });

  test(
    'every disallowed package is listed with version and identifier',
    () async {
      final fs = _repo(
        packages: [
          ('alpha', '1.0.0', 'hosted'),
          ('beta', '2.1.0', 'hosted'),
          ('gamma', '3.2.1', 'hosted'),
        ],
        licences: {'alpha': _mit, 'beta': _isc, 'gamma': bsdGoogleLlc},
        policy: 'allowed:\n  - MIT\nexceptions: []\n',
      );

      final result = await _check(fs);

      expect(result.code, 1);
      expect(result.err, contains('beta 2.1.0'));
      expect(result.err, contains('ISC'));
      expect(result.err, contains('gamma 3.2.1'));
      expect(result.err, contains('BSD-3-Clause'));
      expect(result.err, isNot(contains('alpha')));
    },
  );

  group('exceptions', () {
    String policy(String entries) => 'allowed:\n  - MIT\nexceptions:\n$entries';

    String entry({
      String package = 'weird',
      String version = '1.2.3',
      String licence = 'unrecognised',
      String reason = 'Owner read the licence; it is permissive.',
    }) =>
        '  - package: $package\n'
        '    version: "$version"\n'
        '    licence: $licence\n'
        '    reason: "$reason"\n'
        '    approved: 2026-11-01\n';

    InMemoryFileSystem repo(String policyText, {String text = _custom}) =>
        _repo(
          packages: [
            ('alpha', '1.0.0', 'hosted'),
            ('weird', '1.2.3', 'hosted'),
          ],
          licences: {'alpha': _mit, 'weird': text},
          policy: policyText,
        );

    test(
      'exact-version exception passes and is listed with its reason',
      () async {
        final result = await _check(repo(policy(entry())));

        expect(result.err, isEmpty);
        expect(result.code, 0);
        expect(result.out, contains('weird 1.2.3'));
        expect(
          result.out,
          contains('Owner read the licence; it is permissive.'),
        );
        expect(result.out, contains('excepted'));
      },
    );

    test(
      'exception for another version does not cover the locked one',
      () async {
        final result = await _check(repo(policy(entry(version: '1.2.2'))));

        expect(result.code, 1);
        expect(result.err, contains('weird 1.2.3'));
        expect(result.err, contains('unrecognised'));
        expect(result.out, isNot(contains('excepted')));
      },
    );

    test(
      'exception for an unlocked package or version fails as stale',
      () async {
        final result = await _check(
          repo(policy(entry() + entry(package: 'ghost', version: '9.9.9'))),
        );

        expect(result.code, 1);
        expect(result.err, contains('ghost 9.9.9'));
        expect(result.err, contains('stale'));
        expect(result.err, isNot(contains('weird 1.2.3')));

        final other = await _check(repo(policy(entry(version: '1.2.2'))));
        expect(other.err, contains('weird 1.2.2'));
        expect(other.err, contains('stale'));
      },
    );

    test(
      'exception whose licence differs from the classification fails',
      () async {
        final result = await _check(
          repo(policy(entry(licence: 'MPL-2.0')), text: _isc),
        );

        expect(result.code, 1);
        expect(result.err, contains('weird 1.2.3'));
        expect(result.err, contains('MPL-2.0'));
        expect(result.err, contains('ISC'));
        expect(result.out, isNot(contains('excepted')));
      },
    );

    test('exception cannot record or cover a licence read failure', () async {
      // A read-failure label is not a licence: the loader refuses it, so a
      // missing licence file cannot be passed off as an approved package.
      for (final label in ['"no licence file"', '"unreadable licence"']) {
        final result = await _check(
          repo(policy(entry(licence: label)), text: ''),
        );

        expect(result.code, 1, reason: label);
        expect(result.err, contains('exceptions[0]'), reason: label);
        expect(
          result.err,
          contains('must be an SPDX id the check knows or unrecognised'),
          reason: label,
        );
        expect(result.out, isNot(contains('excepted')), reason: label);
      }

      // A valid entry for a package whose licence file is missing names
      // the read failure, not a licence mismatch.
      final missing = _repo(
        packages: [('weird', '1.2.3', 'hosted')],
        policy: policy(entry()),
      );
      final result = await _check(missing);

      expect(result.code, 1);
      expect(result.err, contains('weird 1.2.3'));
      expect(
        result.err,
        contains('cannot cover a package whose licence was not read'),
      );
      expect(result.out, isNot(contains('excepted')));
    });

    test('exception for an allowed package fails as not needed', () async {
      final result = await _check(
        repo(
          policy(entry(package: 'alpha', version: '1.0.0')),
          text: _mit,
        ),
      );

      expect(result.code, 1);
      expect(result.err, contains('alpha 1.0.0'));
      expect(result.err, contains('not needed'));
    });

    test(
      'malformed policy or entry without a field fails and excepts nothing',
      () async {
        final missingReason =
            'allowed:\n  - MIT\nexceptions:\n'
            '  - package: weird\n'
            '    version: "1.2.3"\n'
            '    licence: unrecognised\n'
            '    approved: 2026-11-01\n';
        final badDate = policy(entry().replaceFirst('2026-11-01', 'yesterday'));
        final broken = 'allowed: [MIT\nexceptions: {';

        for (final text in [missingReason, badDate, broken]) {
          final result = await _check(repo(text));

          expect(result.code, 1, reason: text);
          expect(result.err, contains('licence-policy.yaml'), reason: text);
          expect(result.out, isNot(contains('excepted')), reason: text);
        }
        final result = await _check(repo(missingReason));
        expect(result.err, contains('exceptions[0]'));
        expect(result.err, contains('reason'));
        expect(result.err, contains('weird'));
      },
    );
  });

  test('unknown policy key fails naming file and key', () async {
    final fs = _repo(
      packages: [('alpha', '1.0.0', 'hosted')],
      licences: {'alpha': _mit},
      policy: 'allowed:\n  - MIT\nexceptons: []\n',
    );

    final result = await _check(fs);

    expect(result.code, 1);
    expect(result.err, contains('licence-policy.yaml'));
    expect(result.err, contains('exceptons'));
  });

  test('allowlisted GPL-2.0-only fails as not AGPL-compatible', () async {
    final fs = _repo(
      packages: [('alpha', '1.0.0', 'hosted')],
      licences: {'alpha': _mit},
      policy: 'allowed:\n  - MIT\n  - GPL-2.0-only\nexceptions: []\n',
    );

    final result = await _check(fs);

    expect(result.code, 1);
    expect(result.err, contains('GPL-2.0-only'));
    expect(result.err, contains('AGPL-3.0'));
    expect(result.out, isNot(contains('MIT: ')), reason: 'nothing is allowed');
  });

  test('allowlist id without a template fails', () async {
    final fs = _repo(
      packages: [('alpha', '1.0.0', 'hosted')],
      licences: {'alpha': _mit},
      policy: 'allowed:\n  - MIT\n  - Frobnicate-1.0\nexceptions: []\n',
    );

    final result = await _check(fs);

    expect(result.code, 1);
    expect(result.err, contains('Frobnicate-1.0'));
    expect(result.out, isNot(contains('MIT: ')), reason: 'nothing is allowed');
  });
}
