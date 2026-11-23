import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

enum _Kind implements EsiWireEnum {
  alpha('alpha'),
  betaGamma('beta-gamma');

  const _Kind(this.wire);

  @override
  final String wire;
}

Matcher _decodeError(String path, String reason) => isA<EsiDecodeException>()
    .having((e) => e.path, 'path', path)
    .having((e) => e.reason, 'reason', reason);

Matcher _invalid(String path, String reason) => isA<EsiInvalidArgument>()
    .having((e) => e.path, 'path', path)
    .having((e) => e.reason, 'reason', reason);

void main() {
  group('EsiJson reads', () {
    test('scalars of the right JSON type', () {
      expect(EsiJson.integer(3, r'$'), 3);
      expect(EsiJson.number(3, r'$'), 3.0);
      expect(EsiJson.number(1.5, r'$'), 1.5);
      expect(EsiJson.string('a', r'$'), 'a');
      expect(EsiJson.boolean(false, r'$'), isFalse);
      expect(
        EsiJson.dateTime('2030-01-02T03:04:05Z', r'$'),
        DateTime.utc(2030, 1, 2, 3, 4, 5),
      );
      expect(EsiJson.any([1, 'a'], r'$'), [1, 'a']);
    });

    test('a wrong JSON type is a mismatch at its path', () {
      expect(
        () => EsiJson.integer('7', r'$.id'),
        throwsA(_decodeError(r'$.id', 'expected an integer, got a string')),
      );
      expect(
        () => EsiJson.integer(1.5, r'$'),
        throwsA(_decodeError(r'$', 'expected an integer, got a number')),
      );
      expect(
        () => EsiJson.object([], r'$'),
        throwsA(_decodeError(r'$', 'expected an object, got an array')),
      );
      expect(
        () => EsiJson.dateTime('soon', r'$.at'),
        throwsA(_decodeError(r'$.at', 'expected a date-time, got "soon"')),
      );
    });

    test('UUIDs are checked in both directions', () {
      const id = '3868eaed-8278-4cb7-9709-7d7de9c20dc7';
      expect(EsiJson.uuid(id, r'$.id'), id);
      expect(EsiCheck.uuid(id, 'job_id'), id);
      expect(
        () => EsiJson.uuid('not-a-uuid', r'$.id'),
        throwsA(_decodeError(r'$.id', 'expected a UUID, got "not-a-uuid"')),
      );
      expect(
        () => EsiCheck.uuid('not-a-uuid', 'job_id'),
        throwsA(_invalid('job_id', 'must be a UUID, got "not-a-uuid"')),
      );
    });

    test('dates and date-times are read strictly, never normalised', () {
      expect(EsiJson.date('2030-02-28', r'$'), DateTime.utc(2030, 2, 28));
      expect(
        EsiJson.dateTime('2030-01-02T05:04:05.5+02:00', r'$'),
        DateTime.utc(2030, 1, 2, 3, 4, 5, 500),
      );
      expect(
        EsiJson.dateTime('2030-01-02t03:04:05z', r'$'),
        DateTime.utc(2030, 1, 2, 3, 4, 5),
      );
      for (final text in ['2030-02-30', '2030-13-01', '2030-1-2', '20300102']) {
        expect(
          () => EsiJson.date(text, r'$.d'),
          throwsA(_decodeError(r'$.d', 'expected a date, got "$text"')),
          reason: text,
        );
      }
      for (final text in [
        '2030-01-02',
        '2030-01-02T03:04:05',
        '2030-02-30T03:04:05Z',
        '2030-01-02T24:00:00Z',
        '2030-01-02T03:60:00Z',
        '2030-01-02 03:04:05Z',
      ]) {
        expect(
          () => EsiJson.dateTime(text, r'$.t'),
          throwsA(_decodeError(r'$.t', 'expected a date-time, got "$text"')),
          reason: text,
        );
      }
    });

    test('a missing required field is a mismatch at its path', () {
      expect(
        () => EsiJson.required({'a': 1}, 'b', r'$'),
        throwsA(_decodeError(r'$.b', 'required field "b" is missing')),
      );
      expect(EsiJson.required({'b': null}, 'b', r'$'), isNull);
    });

    test('an optional field is null when absent, and a present null is '
        'checked against its schema', () {
      expect(EsiJson.optional({}, 'a', r'$', EsiJson.integer), isNull);
      expect(
        () => EsiJson.optional({'a': null}, 'a', r'$', EsiJson.integer),
        throwsA(isA<EsiDecodeException>()),
      );
      expect(
        EsiJson.optionalNullable({'a': null}, 'a', r'$', EsiJson.integer),
        isNull,
      );
      expect(EsiJson.optionalNullable({}, 'a', r'$', EsiJson.integer), isNull);
      expect(EsiJson.optionalNullable({'a': 2}, 'a', r'$', EsiJson.integer), 2);
      expect(EsiJson.optional({'a': 2}, 'a', r'$', EsiJson.integer), 2);
      expect(
        () => EsiJson.optional({'a': 'x'}, 'a', r'$', EsiJson.integer),
        throwsA(_decodeError(r'$.a', 'expected an integer, got a string')),
      );
    });

    test('arrays and maps name the item at fault', () {
      expect(EsiJson.list([1, 2], r'$', EsiJson.integer), [1, 2]);
      expect(
        () => EsiJson.list([1, 'x'], r'$.ids', EsiJson.integer),
        throwsA(_decodeError(r'$.ids[1]', 'expected an integer, got a string')),
      );
      expect(EsiJson.map({'a': 1}, r'$', EsiJson.integer), {'a': 1});
      expect(
        () => EsiJson.map({'a': true}, r'$.m', EsiJson.integer),
        throwsA(_decodeError(r'$.m.a', 'expected an integer, got a boolean')),
      );
    });

    test('enums keep unlisted strings and refuse non-strings', () {
      expect(
        EsiJson.enumValue('beta-gamma', r'$', _Kind.values),
        const EsiKnown(_Kind.betaGamma),
      );
      expect(
        EsiJson.enumValue('delta', r'$', _Kind.values),
        const EsiUnknown<_Kind>('delta'),
      );
      expect(
        () => EsiJson.enumValue(4, r'$.kind', _Kind.values),
        throwsA(_decodeError(r'$.kind', 'expected a string, got an integer')),
      );
    });

    test('a oneOf object needs exactly one key', () {
      expect(EsiJson.oneOfKey({'isk': 1}, r'$'), 'isk');
      expect(
        () => EsiJson.oneOfKey({}, r'$.price'),
        throwsA(
          _decodeError(
            r'$.price',
            'expected an object with exactly one key, got 0',
          ),
        ),
      );
      expect(
        () => EsiJson.oneOfKey({'a': 1, 'b': 2}, r'$'),
        throwsA(
          _decodeError(r'$', 'expected an object with exactly one key, got 2'),
        ),
      );
    });
  });

  group('EsiCheck writes', () {
    test('values within their bounds unchanged', () {
      expect(EsiCheck.range(5, 'page', minimum: 1, maximum: 5), 5);
      expect(EsiCheck.length('ab', 'name', minLength: 1, maxLength: 2), 'ab');
      expect(EsiCheck.plain('x', 'a'), 'x');
      expect(EsiCheck.optional<int>(null, 'a', EsiCheck.plain), isNull);
      expect(EsiCheck.wire(_Kind.betaGamma, 'kind'), 'beta-gamma');
      expect(EsiCheck.known(const EsiKnown(_Kind.alpha), 'kind'), 'alpha');
      expect(EsiCheck.date(DateTime.utc(2030, 1, 2, 23), 'day'), '2030-01-02');
      expect(
        EsiCheck.dateTime(DateTime.utc(2030, 1, 2, 3, 4, 5), 'at'),
        '2030-01-02T03:04:05.000Z',
      );
      expect(EsiCheck.map({'a': 1}, 'body', EsiCheck.plain), {'a': 1});
    });

    test('a value outside its bounds names the parameter', () {
      expect(
        () => EsiCheck.range(0, 'page', minimum: 1),
        throwsA(_invalid('page', 'must be at least 1, got 0')),
      );
      expect(
        () => EsiCheck.range(11, 'n', maximum: 10),
        throwsA(_invalid('n', 'must be at most 10, got 11')),
      );
      expect(
        () => EsiCheck.length('', 'name', minLength: 1),
        throwsA(_invalid('name', 'must be at least 1 characters long')),
      );
      expect(
        () => EsiCheck.length('abc', 'name', maxLength: 2),
        throwsA(_invalid('name', 'must be at most 2 characters long')),
      );
      // OpenAPI counts code points: a supplementary character is one,
      // though Dart's String.length counts it as two code units.
      expect(
        () => EsiCheck.length('\u{1F680}a', 'search', minLength: 3),
        throwsA(_invalid('search', 'must be at least 3 characters long')),
      );
      final rockets = '\u{1F680}' * 50;
      expect(EsiCheck.length(rockets, 'name', maxLength: 50), rockets);
      expect(
        () => EsiCheck.known(const EsiUnknown<_Kind>('delta'), 'body.kind'),
        throwsA(
          _invalid(
            'body.kind',
            'holds "delta", which the pinned spec does not list',
          ),
        ),
      );
      expect(
        () => EsiCheck.unknownVariant('barter', 'body.price'),
        throwsA(
          _invalid(
            'body.price',
            'holds the variant "barter", which the pinned spec does not list',
          ),
        ),
      );
    });

    test('arrays are checked for size, repeats and each item', () {
      int write(int value, String path) =>
          EsiCheck.range(value, path, minimum: 1);
      expect(EsiCheck.list([1, 2], 'body', write, minItems: 1), [1, 2]);
      expect(
        () => EsiCheck.list(<int>[], 'body', write, minItems: 1),
        throwsA(_invalid('body', 'must hold at least 1 items')),
      );
      expect(
        () => EsiCheck.list([1, 2, 3], 'body', write, maxItems: 2),
        throwsA(_invalid('body', 'must hold at most 2 items')),
      );
      expect(
        () => EsiCheck.list([1, 1], 'body', write, unique: true),
        throwsA(_invalid('body', 'must not repeat an item')),
      );
      expect(
        () => EsiCheck.list([1, 0], 'body', write),
        throwsA(_invalid('body[1]', 'must be at least 1, got 0')),
      );
    });
  });
}
