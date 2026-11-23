import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

enum _Colour implements EsiWireEnum {
  red('red');

  const _Colour(this.wire);

  @override
  final String wire;
}

void main() {
  test('a known value keeps its case and wire form', () {
    const EsiEnum<_Colour> value = EsiKnown(_Colour.red);
    expect(value.wire, 'red');
    expect(value, const EsiKnown(_Colour.red));
    expect(value, isNot(const EsiUnknown<_Colour>('red')));
  });

  test('an unknown value keeps the received string', () {
    const EsiEnum<_Colour> value = EsiUnknown('teal');
    expect(value.wire, 'teal');
    expect(value, const EsiUnknown<_Colour>('teal'));
    expect(value.hashCode, const EsiUnknown<_Colour>('teal').hashCode);
  });

  test('a listed variant keeps its key and value', () {
    const EsiOneOf<Object> value = EsiVariant<Object>('isk', 1500.5);
    expect(value.key, 'isk');
    expect(value, const EsiVariant<Object>('isk', 1500.5));
    expect(value, isNot(const EsiVariant<Object>('tokens', 1500.5)));
  });

  test('an unlisted variant keeps the received object, compared by '
      'content', () {
    final value = EsiUnknownVariant<Object>({
      'barter': [
        1,
        {'a': null},
      ],
    });
    expect(value.key, 'barter');
    expect(
      value,
      EsiUnknownVariant<Object>({
        'barter': [
          1,
          {'a': null},
        ],
      }),
    );
    expect(
      value,
      isNot(
        EsiUnknownVariant<Object>({
          'barter': [1, <String, Object?>{}],
        }),
      ),
    );
    expect(
      value.hashCode,
      EsiUnknownVariant<Object>({
        'barter': [
          1,
          {'a': null},
        ],
      }).hashCode,
    );
  });
}
