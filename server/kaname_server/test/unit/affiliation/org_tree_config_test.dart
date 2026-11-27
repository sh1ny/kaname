import 'package:kaname_server/src/affiliation/org_tree_config.dart';
import 'package:test/test.dart';

void main() {
  test('parses all three tree declarations without mixing ID kinds', () {
    expect(readOrgTree(const {}), isA<UnconfiguredOrgTree>());
    expect(
      readOrgTree(const {'KANAME_ORG_TREE': ''}),
      isA<UnconfiguredOrgTree>(),
    );
    expect(
      readOrgTree(const {'KANAME_ORG_TREE': 'corporation:123'}),
      isA<CorporationOrgTree>().having((tree) => tree.corporationId, 'id', 123),
    );
    expect(
      readOrgTree(const {'KANAME_ORG_TREE': 'alliance:123'}),
      isA<AllianceOrgTree>().having((tree) => tree.allianceId, 'id', 123),
    );
    expect(
      readOrgTree(const {'KANAME_ORG_TREE': 'coalition:123,456,789'}),
      isA<CoalitionOrgTree>().having((tree) => tree.allianceIds, 'ids', {
        123,
        456,
        789,
      }),
    );
  });

  test('rejects invalid declarations and names the setting', () {
    for (final value in [
      ' ',
      'alliance:0',
      'corporation:-1',
      'corporation:+42',
      'alliance:9223372036854775808',
      'alliance:0x2',
      'alliance:12,13',
      'alliance:12\n',
      'coalition:12',
      'coalition:12,12',
      'coalition:12,12,13',
      'coalition:12,',
      'coalition:12,corporation:13',
      'unknown:12',
    ]) {
      expect(
        () => readOrgTree({'KANAME_ORG_TREE': value}),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'setting',
                contains('KANAME_ORG_TREE'),
              )
              .having((error) => error.source, 'no raw value', isNull),
        ),
        reason: value,
      );
    }
  });
}
