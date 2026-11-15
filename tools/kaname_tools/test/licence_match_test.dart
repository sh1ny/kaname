import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/licence_fixtures.dart';

/// The SPDX identifier [text] classifies as, or `unrecognised`.
String _classify(String text) =>
    switch (const LicenceMatcher().classify(text)) {
      KnownLicence(:final id) => id,
      UnrecognisedLicence() => 'unrecognised',
    };

/// The MIT licence without a title or copyright line.
const _mitBody = '''
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''';

/// [bsdGoogleLlc] without its one-line Dart project header.
String get _bsdBody => bsdGoogleLlc.split('\n').skip(2).join('\n');

const _bsd2Spdx = '''
Copyright (c) <year> <owner>

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
''';

void main() {
  test('MIT with any copyright header classifies as MIT', () {
    for (final header in [
      'Copyright (c) 2019 Someone',
      'Copyright 2020 Ada Lovelace\nCopyright (c) 2021 Alan Turing',
      '(c) 1999 Nobody in particular',
      '© 2016 Vladimir Kharlampidi',
      '  copyright (C) 2024, the Example authors. All rights reserved.',
      'MIT License\n\nCopyright (c) 2018 Example Inc.',
    ]) {
      expect(_classify('$header\n\n$_mitBody\n'), 'MIT', reason: header);
    }
    expect(_classify(_mitBody), 'MIT', reason: 'no header at all');
  });

  test('BSD-3-Clause with a separate All rights reserved line classifies', () {
    expect(
      _classify(
        'Copyright 2013 The Flutter Authors.\nAll rights reserved.\n\n'
        '$_bsdBody',
      ),
      'BSD-3-Clause',
    );
    expect(
      _classify(
        'Copyright (c) 2013 A\nCopyright (c) 2014 B\n\n'
        'All rights reserved.\n\n$_bsdBody',
      ),
      'BSD-3-Clause',
    );
  });

  test('BSD-3-Clause with Google LLC and Google Inc. holders classify in '
      'HOLDER and OWNER wording, and BSD-2-Clause in SPDX wording', () {
    expect(_classify(bsdGoogleLlc), 'BSD-3-Clause');
    expect(_classify(bsdGoogleInc), 'BSD-3-Clause');
    String holder(String text) =>
        text.replaceFirst('COPYRIGHT\nOWNER OR', 'COPYRIGHT\nHOLDER OR');
    expect(holder(bsdGoogleLlc), isNot(bsdGoogleLlc));
    expect(_classify(holder(bsdGoogleLlc)), 'BSD-3-Clause');
    expect(_classify(holder(bsdGoogleInc)), 'BSD-3-Clause');
    expect(_classify(_bsd2Spdx), 'BSD-2-Clause');
  });

  test('MIT title line and Apache-2.0 with or without appendix, or with a '
      'filled-in appendix copyright line, classify', () {
    expect(_classify(mitWithTitle), 'MIT');
    expect(_classify(apacheWithAppendix), 'Apache-2.0');
    final end = apacheWithAppendix.indexOf('   APPENDIX');
    expect(end, greaterThan(0));
    expect(_classify(apacheWithAppendix.substring(0, end)), 'Apache-2.0');
    expect(apacheFilledAppendix, contains('Copyright 2021 Google LLC'));
    expect(_classify(apacheFilledAppendix), 'Apache-2.0');
  });

  test('one changed clause word, a third HOLDER/OWNER word or an over-long '
      'appendix slot is unrecognised', () {
    expect(
      _classify(mitWithTitle.replaceFirst('WITHOUT WARRANTY', 'WITH WARRANTY')),
      'unrecognised',
    );
    expect(
      _classify(
        bsdGoogleLlc.replaceFirst('with or without', 'with or without any'),
      ),
      'unrecognised',
    );
    // A body line that starts with "copyright" is not header: changing it
    // must still be seen.
    expect(
      _classify(
        bsdGoogleLlc.replaceFirst(
          'copyright notice, this list of '
              'conditions and the following\n      disclaimer in',
          'copyright '
              'notices, this list of conditions and the following\n      '
              'disclaimer in',
        ),
      ),
      'unrecognised',
    );
    expect(
      _classify(apacheWithAppendix.replaceFirst('Licensor', 'Licensee')),
      'unrecognised',
    );
    expect(
      _classify(
        bsdGoogleLlc.replaceFirst(
          'COPYRIGHT\nOWNER OR',
          'COPYRIGHT\nSTEWARD OR',
        ),
      ),
      'unrecognised',
    );
    const long =
        'one two three four five six seven eight nine ten eleven '
        'twelve thirteen';
    expect(
      _classify(apacheFilledAppendix.replaceFirst('2021 Google LLC', long)),
      'unrecognised',
    );
    expect(
      _classify(
        apacheFilledAppendix.replaceFirst(
          '2021 Google LLC',
          'one two '
              'three four five six seven eight nine ten eleven twelve',
        ),
      ),
      'Apache-2.0',
    );
    expect(
      _classify(apacheFilledAppendix.replaceFirst('Licensor', 'Licensee')),
      'unrecognised',
    );
    // The holder slot takes 1 to 12 words, no more.
    const thirteen =
        'one two three four five six seven eight nine ten '
        'eleven twelve thirteen';
    expect(
      _classify(bsdGoogleLlc.replaceFirst('Google LLC', thirteen)),
      'unrecognised',
    );
    expect(
      _classify(
        bsdGoogleLlc.replaceFirst(
          'Google LLC',
          'one two three four '
              'five six seven eight nine ten eleven twelve',
        ),
      ),
      'BSD-3-Clause',
    );
  });

  test('a file holding two licences is unrecognised', () {
    expect(_classify('$mitWithTitle\n\n$bsdGoogleLlc'), 'unrecognised');
  });
}
