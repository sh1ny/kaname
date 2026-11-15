import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Reads [relative] from the repository root, or fails the test.
String _read(String relative) {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  final file = File(p.join(root, relative));
  if (!file.existsSync()) fail('$relative does not exist');
  return file.readAsStringSync();
}

/// The text of the `## ` section of [markdown] whose heading contains
/// [heading] (case-insensitive), up to the next `## ` heading.
String _section(String markdown, String heading) {
  final sections = markdown.split(RegExp(r'^## ', multiLine: true));
  for (final section in sections.skip(1)) {
    final title = section.split('\n').first;
    if (title.toLowerCase().contains(heading.toLowerCase())) return section;
  }
  fail('no "## …$heading…" section');
}

/// Matches when the string contains every one of [phrases], ignoring case.
Matcher _mentionsAll(List<String> phrases) => allOf([
  for (final phrase in phrases)
    predicate<String>(
      (text) => text.toLowerCase().contains(phrase.toLowerCase()),
      'mentions "$phrase"',
    ),
]);

void main() {
  test('CONTRIBUTING has the no-copy section', () {
    final section = _section(_read('CONTRIBUTING.md'), 'no-copy');
    expect(
      section,
      _mentionsAll([
        'code',
        'schemas',
        'templates',
        'data file',
        'pinned, unmodified, credited dependency',
        'provenance note',
      ]),
    );
  });

  test('CONTRIBUTING declines copied code and the PR template has the '
      'no-copy item', () {
    final section = _section(_read('CONTRIBUTING.md'), 'no-copy');
    expect(section, _mentionsAll(['declined']));
    expect(
      _read('.github/pull_request_template.md'),
      contains('- [ ] **No-copy rule:**'),
    );
  });

  test('CONTRIBUTING lists allowed and forbidden integrations', () {
    final section = _section(_read('CONTRIBUTING.md'), 'EULA boundary');
    expect(
      section,
      _mentionsAll([
        'reads game and chat log files',
        'moves or resizes windows',
        'input broadcasting',
        'synthetic input',
        'focus cycling on keys',
        'memory reading',
        'screen capture or OCR of the client',
        'packet inspection',
        'global keyboard hooks',
      ]),
    );
  });

  test('CONTRIBUTING rejects out-of-boundary features regardless of '
      'default', () {
    final section = _section(_read('CONTRIBUTING.md'), 'EULA boundary');
    expect(
      section,
      _mentionsAll(['not accepted', 'whatever its configuration or default']),
    );
  });

  test('CONTRIBUTING requires DCO sign-off and shows git commit -s', () {
    final section = _section(
      _read('CONTRIBUTING.md'),
      'Developer Certificate of Origin',
    );
    expect(
      section,
      _mentionsAll([
        'Developer Certificate of Origin 1.1',
        'https://developercertificate.org/',
        'Signed-off-by: Your Name <you@example.com>',
        'git commit -s',
        'every commit',
      ]),
    );
  });

  test('CONTRIBUTING explains amending with sign-off and describes the CI '
      'check and its one exemption', () {
    final section = _section(
      _read('CONTRIBUTING.md'),
      'Developer Certificate of Origin',
    );
    expect(
      section,
      _mentionsAll([
        'git commit --amend --signoff --no-edit',
        'git rebase --signoff',
        'are not merged',
        'CI checks',
        '`signoff` check',
        'mise run signoff -- --base <upstream remote>/main',
        'only exemption',
        'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>',
        'pull request opened by `dependabot[bot]`',
      ]),
    );
    expect(
      section.toLowerCase(),
      isNot(contains('no automated sign-off check')),
      reason: 'CI now checks sign-off',
    );
  });

  test('PR template has the three check items', () {
    final template = _read('.github/pull_request_template.md');
    for (final item in [
      '- [ ] **No-copy rule:**',
      '- [ ] **EULA boundary:**',
      '- [ ] **DCO sign-off:**',
    ]) {
      expect(template, contains(item));
    }
  });

  test('SECURITY names private reporting, links advisories, no email', () {
    final security = _read('SECURITY.md');
    expect(
      security,
      _mentionsAll([
        'private vulnerability reporting',
        'https://github.com/sh1ny/kaname/security/advisories/new',
        'do not open a public issue',
        'no version is supported until release 0.1',
      ]),
    );
    expect(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+').hasMatch(security),
      isFalse,
      reason: 'SECURITY.md must not publish an email address',
    );
  });

  test('deploy README states linux/amd64 container support and native '
      'Windows and macOS servers unsupported', () {
    final section = _section(_read('deploy/README.md'), 'Supported platforms');
    expect(
      section,
      _mentionsAll([
        '`linux/amd64` container',
        'Windows and macOS',
        'Linux container runtime',
        'arm64',
        'emulation',
        'natively on Windows or macOS',
        'unsupported',
      ]),
    );
  });
}
