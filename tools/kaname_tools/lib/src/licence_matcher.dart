import 'licence_texts.dart';
import 'locked_packages.dart';

/// What a licence text turned out to be.
sealed class LicenceClassification {
  const LicenceClassification();
}

/// The text matches one known licence exactly, slots aside.
final class KnownLicence extends LicenceClassification {
  /// Creates a classification as the licence [id], an SPDX identifier or a
  /// `LicenseRef-` reference.
  const KnownLicence(this.id);

  /// The SPDX identifier or licence reference.
  final String id;
}

/// The text matches no known licence, or more than one, or holds several
/// licences.
final class UnrecognisedLicence extends LicenceClassification {
  /// Creates the classification.
  const UnrecognisedLicence();
}

/// A licence the matcher knows by its canonical text.
///
/// A template is written from the SPDX licence list text of [id]. Where
/// SPDX publishes more than one id for versions of one licence (`GPL-2.0-only`
/// and `GPL-2.0-or-later`), a text match cannot tell them apart, so every
/// GPL-family template is keyed by its `-only` id and says nothing about
/// `-or-later`.
final class LicenceTemplate {
  /// Creates a template of [id] that matches any of the [variants].
  ///
  /// A variant is licence text. It may contain the slot marker `{holder}`,
  /// which stands for 1 to [maxSlotWords] words. Every other word must
  /// match exactly.
  const LicenceTemplate(
    this.id, {
    required this.agplCompatible,
    required this.variants,
  });

  /// The most words a `{holder}` slot takes.
  static const int maxSlotWords = 12;

  /// The current SPDX identifier.
  final String id;

  /// Whether the licence is compatible with AGPL-3.0, per the FSF's licence
  /// list.
  final bool agplCompatible;

  /// The texts that all count as this licence.
  final List<String> variants;
}

String _bsdVariant(String text, {required bool owner}) {
  final varied = owner
      ? text.replaceAll('COPYRIGHT HOLDER OR', 'COPYRIGHT OWNER OR')
      : text;
  return varied.replaceAll(
    'Neither the name of the copyright holder nor',
    'Neither the name of {holder} nor',
  );
}

String _apacheWithSlot() {
  const boilerplate = 'Copyright [yyyy] [name of copyright owner]';
  assert(spdxApache2.contains(boilerplate), 'SPDX Apache-2.0 text changed');
  return spdxApache2.replaceFirst(boilerplate, 'Copyright {holder}');
}

String _apacheHead() =>
    spdxApache2.substring(0, spdxApache2.indexOf('APPENDIX:'));

/// Every licence the matcher knows, allowlistable or not.
///
/// The BSD texts have two variants: SPDX's wording `COPYRIGHT HOLDER OR
/// CONTRIBUTORS` and the older `COPYRIGHT OWNER OR CONTRIBUTORS` that
/// Google's packages carry. Apache-2.0 has two, without and with its
/// `APPENDIX` section, whose line `Copyright [yyyy] [name of copyright
/// owner]` is a `{holder}` slot because packages fill it in. The BSD-3-Clause
/// variants have a `{holder}` slot in the clause that names whose name may not
/// endorse derived products.
final List<LicenceTemplate> licenceTemplates = List.unmodifiable([
  const LicenceTemplate('MIT', agplCompatible: true, variants: [spdxMit]),
  LicenceTemplate(
    'BSD-2-Clause',
    agplCompatible: true,
    variants: [
      _bsdVariant(spdxBsd2Clause, owner: false),
      _bsdVariant(spdxBsd2Clause, owner: true),
    ],
  ),
  LicenceTemplate(
    'BSD-3-Clause',
    agplCompatible: true,
    variants: [
      _bsdVariant(spdxBsd3Clause, owner: false),
      _bsdVariant(spdxBsd3Clause, owner: true),
    ],
  ),
  LicenceTemplate(
    'Apache-2.0',
    agplCompatible: true,
    variants: [_apacheHead(), _apacheWithSlot()],
  ),
  const LicenceTemplate('ISC', agplCompatible: true, variants: [spdxIsc]),
  const LicenceTemplate('Zlib', agplCompatible: true, variants: [spdxZlib]),
  const LicenceTemplate('MPL-2.0', agplCompatible: true, variants: [spdxMpl2]),
  const LicenceTemplate(
    'LGPL-2.1-only',
    agplCompatible: true,
    variants: [spdxLgpl21Only],
  ),
  const LicenceTemplate(
    'LGPL-3.0-only',
    agplCompatible: true,
    variants: [spdxLgpl30Only],
  ),
  const LicenceTemplate(
    'GPL-2.0-only',
    agplCompatible: false,
    variants: [spdxGpl20Only],
  ),
  const LicenceTemplate(
    'GPL-3.0-only',
    agplCompatible: true,
    variants: [spdxGpl30Only],
  ),
  const LicenceTemplate(
    'AGPL-3.0-only',
    agplCompatible: true,
    variants: [spdxAgpl30Only],
  ),
]);

/// Finds the template called [id], or `null` when the matcher has none.
LicenceTemplate? licenceTemplateFor(String id) {
  for (final template in licenceTemplates) {
    if (template.id == id) return template;
  }
  return null;
}

/// Classifies licence text by matching it against [licenceTemplates].
///
/// The order of operations is fixed:
///
/// 1. The text is normalised as the notices code does ([normaliseLicence]);
///    normalising an already normalised text changes nothing.
/// 2. Only the leading header block is dropped: an optional title line (a
///    line of at most [maxTitleWords] words, not a copyright line, followed
///    by a blank line or a copyright line), then consecutive copyright lines
///    (starting `Copyright`, `(c)` or `©` after any indentation, case
///    ignored, blank lines between them allowed), then an optional
///    `All rights reserved.` line. No line after the first body line is
///    ever dropped, because body lines can also start with `copyright` or
///    `(c)`.
/// 3. The rest becomes a word sequence: case folded, punctuation and
///    bullet or numbering marks at line starts removed.
/// 4. The sequence is matched against each variant of each template, which
///    went through steps 2 and 3 too.
///
/// A text that matches the variants of exactly one template is a
/// [KnownLicence]; one that matches none, or the variants of more than one
/// template, is [UnrecognisedLicence].
final class LicenceMatcher {
  /// Creates a matcher over [licenceTemplates].
  const LicenceMatcher();

  /// The longest first line, in words, that counts as a title.
  static const int maxTitleWords = 8;

  /// Classifies the licence [text].
  LicenceClassification classify(String text) {
    final words = _words(text);
    final matched = {
      for (final template in _compiled)
        if (template.variants.any((variant) => _matches(variant, words)))
          template.id,
    };
    return matched.length == 1
        ? KnownLicence(matched.single)
        : const UnrecognisedLicence();
  }
}

const String _slot = '{holder}';

final RegExp _copyrightLine = RegExp(
  r'^\s*(?:copyright\b|\(c\)|©)',
  caseSensitive: false,
);
final RegExp _rightsLine = RegExp(
  r'^\s*all rights reserved\.?\s*$',
  caseSensitive: false,
);
final RegExp _lineMark = RegExp(r'^\s*(?:[*•\-–—]|\d+[.)])\s+');
final RegExp _word = RegExp(r'\{holder\}|[\p{L}\p{N}]+', unicode: true);

final List<({String id, List<List<String>> variants})> _compiled = [
  for (final LicenceTemplate(:id, :variants) in licenceTemplates)
    (id: id, variants: [for (final text in variants) _words(text)]),
];

bool _isBlank(String line) => line.trim().isEmpty;

bool _isTitle(List<String> lines, int index) {
  final line = lines[index];
  if (_copyrightLine.hasMatch(line)) return false;
  if (_word.allMatches(line).length > LicenceMatcher.maxTitleWords) {
    return false;
  }
  if (index + 1 >= lines.length) return false;
  final next = lines[index + 1];
  return _isBlank(next) || _copyrightLine.hasMatch(next);
}

/// Steps 1 to 3 of [LicenceMatcher]: the word sequence of [text].
List<String> _words(String text) {
  final lines = normaliseLicence(text).split('\n');
  var start = 0;
  while (start < lines.length && _isBlank(lines[start])) {
    start++;
  }
  if (start < lines.length && _isTitle(lines, start)) start++;
  var end = start;
  for (var i = start; i < lines.length; i++) {
    if (_copyrightLine.hasMatch(lines[i])) {
      end = i + 1;
    } else if (!_isBlank(lines[i])) {
      break;
    }
  }
  start = end;
  var next = start;
  while (next < lines.length && _isBlank(lines[next])) {
    next++;
  }
  if (next < lines.length && _rightsLine.hasMatch(lines[next])) {
    start = next + 1;
  }
  return [
    for (final line in lines.skip(start))
      for (final match in _word.allMatches(
        line.toLowerCase().replaceFirst(_lineMark, ''),
      ))
        match[0]!,
  ];
}

bool _matches(List<String> template, List<String> words) =>
    _matchFrom(template, 0, words, 0);

bool _matchFrom(List<String> template, int t, List<String> words, int w) {
  var ti = t;
  var wi = w;
  while (ti < template.length) {
    if (template[ti] == _slot) {
      for (var n = 1; n <= LicenceTemplate.maxSlotWords; n++) {
        if (wi + n <= words.length &&
            _matchFrom(template, ti + 1, words, wi + n)) {
          return true;
        }
      }
      return false;
    }
    if (wi >= words.length || words[wi] != template[ti]) return false;
    ti++;
    wi++;
  }
  return wi == words.length;
}
