import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:test/test.dart';

const _skills = 'esi-skills.read_skills.v1';

ScopePolicy _policy(String rule, {int revision = 1, bool enabled = true}) =>
    ScopePolicy.parse('''
{"revision":$revision,"enabledModules":[${enabled ? '"personalSkills"' : ''}],
 "classes":{$rule}}
''')!;

void main() {
  test('Enabled module and permitted classes', () {
    final required = _policy('"characterSkills":"required"');
    final optional = _policy('"characterSkills":"optional"');
    final choice = ScopeOptIn(
      characterId: 41,
      owner: 'test-owner',
      policyFingerprint: optional.fingerprint,
      scopeClass: ScopeClass.characterSkills,
    );
    expect(required.scopesFor(41, 'test-owner'), {_skills});
    expect(optional.scopesFor(41, 'test-owner', optIn: choice), {_skills});
    expect(
      _policy('"characterSkills":"never"').scopesFor(41, 'test-owner'),
      isEmpty,
    );
    expect(
      _policy(
        '"characterSkills":"required"',
        enabled: false,
      ).scopesFor(41, 'test-owner'),
      isEmpty,
    );
  });

  test('Missing policy or optional opt-in', () {
    final optional = _policy('"characterSkills":"optional"');
    final choice = ScopeOptIn(
      characterId: 41,
      owner: 'test-owner',
      policyFingerprint: optional.fingerprint,
      scopeClass: ScopeClass.characterSkills,
    );
    expect(ScopePolicy.parse(null), isNull);
    expect(_policy('').scopesFor(41, 'test-owner'), isEmpty);
    expect(optional.scopesFor(41, 'test-owner'), isEmpty);
    expect(optional.scopesFor(42, 'test-owner', optIn: choice), isEmpty);
    expect(optional.scopesFor(41, 'different-owner', optIn: choice), isEmpty);
    expect(
      _policy(
        '"characterSkills":"optional"',
        revision: 2,
      ).scopesFor(41, 'test-owner', optIn: choice),
      isEmpty,
    );
    expect(
      ScopePolicy.parse('''
{"revision":1,"enabledModules":["personalSkills","unknown"],
 "classes":{"characterSkills":"required"}}
'''),
      isNull,
    );
  });

  test('Grant differs from the permitted request', () {
    final required = _policy('"characterSkills":"required"');
    final scopes = required.scopesFor(41, 'test-owner');
    expect(matchesGrantedScopes(scopes, {_skills}), isTrue);
    expect(matchesGrantedScopes(scopes, {_skills, 'extra'}), isFalse);
    expect(matchesGrantedScopes(scopes, const {}), isFalse);
    expect(matchesGrantedScopes(const {}, {_skills}), isFalse);
  });
}
