import 'dart:convert';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/src/record_shape.dart';
import 'package:test/test.dart';

bool check(Object line, {required bool raw}) {
  final bytes = Uint8List.fromList(
    line is String ? utf8.encode(line) : line as List<int>,
  );
  return isRecordLine(bytes, 0, bytes.length, raw: raw);
}

void main() {
  test('record lines the reader decodes are accepted', () {
    for (final line in [
      '[1,{},null]',
      '[-7,{},{}]',
      ' [ 0 , { } , null ] ',
      r'[2,{"a":"\"\\\/\b\f\n\r\t\u00e9"},null]',
      '[3,{"name":{"en":"Ægir ✓ 🚀"}},{"x":[1,-0.5,2e10,3E-2,true,false,null]}]',
      '[4,{"a":{"b":{"c":[[[]]]}}},{"":""}]',
      '[9007199254740991,{},null]',
      '[-9007199254740991,{},null]',
    ]) {
      final decoded = jsonDecode(line) as List<Object?>;
      expect(check(line, raw: decoded[2] != null), isTrue, reason: line);
    }
  });

  test('lines the reader cannot decode as a record are refused', () {
    for (final line in <Object>[
      '',
      '[1,{}]',
      '[1,{},null,null]',
      '[1,[],null]',
      '[1,{},[]]',
      '["1",{},null]',
      '[01,{},null]',
      '[1.0,{},null]',
      '[1234567890123456789,{},null]',
      '[9007199254740992,{},null]',
      '[-9007199254740992,{},null]',
      '[1,{"a":1.},null]',
      '[1,{"a":-},null]',
      '[1,{"a":tru},null]',
      '[1,{"a":1,},null]',
      '[1,{a:1},null]',
      '[1,{"a":"\t"},null]',
      r'[1,{"a":"\u12"},null]',
      '[1,{},null]]',
      [
        ...utf8.encode('[1,{"a":"'),
        0xED,
        0xA0,
        0x80,
        ...utf8.encode('"},null]'),
      ],
      [...utf8.encode('[1,{"a":"'), 0xC0, 0xAF, ...utf8.encode('"},null]')],
      [...utf8.encode('[1,{},null]'), 0xC3],
      '[1,{"a":${'[' * 600}${']' * 600}},null]',
    ]) {
      for (final raw in [false, true]) {
        expect(check(line, raw: raw), isFalse, reason: '$line, raw: $raw');
      }
    }
  });

  // Pre-ship round 31.
  test('the raw position holds an object exactly in a raw-carrying '
      'section', () {
    expect(check('[1,{},{}]', raw: true), isTrue);
    expect(check('[1,{},null]', raw: false), isTrue);
    expect(check('[1,{},null]', raw: true), isFalse);
    expect(check('[1,{},{}]', raw: false), isFalse);
  });
}
