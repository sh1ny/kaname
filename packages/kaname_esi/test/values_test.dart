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
}
