import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi/kaname_esi.dart' show esiCatalogue;

/// A compiled group of ESI permissions exposed by Kaname.
enum ScopeClass {
  /// Read a character's own skills.
  characterSkills,
}

enum _Rule { required, optional, never }

enum _Module { personalSkills }

/// An explicit optional permission for one validated character and policy.
final class ScopeOptIn {
  /// Records the full binding; a different owner or revision cannot reuse it.
  const ScopeOptIn({
    required this.characterId,
    required this.owner,
    required this.policyFingerprint,
    required this.scopeClass,
  });

  /// CCP character ID.
  final int characterId;

  /// Signed CCP owner claim for the character.
  final String owner;

  /// The revision and content of the policy the viewer opted into.
  final String policyFingerprint;

  /// The class the viewer explicitly enabled.
  final ScopeClass scopeClass;
}

/// The operator or desktop policy. A malformed policy grants nothing.
final class ScopePolicy {
  ScopePolicy._(
    int revision,
    Set<_Module> modules,
    Map<ScopeClass, _Rule> rules,
  ) : _modules = modules,
      _rules = rules,
      fingerprint = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                revision,
                [
                  for (final m in _Module.values)
                    if (modules.contains(m)) m.name,
                ],
                [
                  for (final c in ScopeClass.values)
                    if (rules[c] case final rule?) [c.name, rule.name],
                ],
              ]),
            ),
          )
          .toString();

  final Set<_Module> _modules;
  final Map<ScopeClass, _Rule> _rules;

  /// Stable digest of the typed policy and operator revision.
  final String fingerprint;

  static final Set<String> _skills = Set.unmodifiable(
    esiCatalogue['GetCharactersCharacterIdSkills']!.scopes,
  );

  /// Parses the exact supported configuration. Use no scopes on failure.
  static ScopePolicy? parse(String? value) {
    if (value == null || value.length > 4096) return null;
    final Object? raw;
    try {
      raw = jsonDecode(value);
    } on FormatException {
      return null;
    }
    if (raw
        case {
          'revision': final int revision,
          'enabledModules': final List<Object?> modules,
          'classes': final Map<String, Object?> classes,
        }
        when revision > 0 && raw is Map<String, Object?> && raw.length == 3) {
      final enabled = <_Module>{};
      for (final module in modules) {
        if (module != 'personalSkills' ||
            !enabled.add(_Module.personalSkills)) {
          return null;
        }
      }
      final rules = <ScopeClass, _Rule>{};
      for (final MapEntry(:key, :value) in classes.entries) {
        final rule = switch (value) {
          'required' => _Rule.required,
          'optional' => _Rule.optional,
          'never' => _Rule.never,
          _ => null,
        };
        if (key != 'characterSkills' || rule == null) return null;
        rules[ScopeClass.characterSkills] = rule;
      }
      return ScopePolicy._(revision, enabled, rules);
    }
    return null;
  }

  /// The canonical desktop policy after the viewer enables local skills.
  static final personalSkills = ScopePolicy._(
    1,
    {_Module.personalSkills},
    {ScopeClass.characterSkills: _Rule.optional},
  );

  /// Resolves the exact requested scopes for a previously verified identity.
  Set<String> scopesFor(int characterId, String owner, {ScopeOptIn? optIn}) {
    if (characterId <= 0 ||
        owner.isEmpty ||
        !_modules.contains(_Module.personalSkills)) {
      return const {};
    }
    return switch (_rules[ScopeClass.characterSkills]) {
      _Rule.required => _skills,
      _Rule.optional
          when optIn?.characterId == characterId &&
              optIn?.owner == owner &&
              optIn?.policyFingerprint == fingerprint &&
              optIn?.scopeClass == ScopeClass.characterSkills =>
        _skills,
      _ => const {},
    };
  }
}

/// Checks that a signed grant exactly matches the currently allowed scopes.
bool matchesGrantedScopes(Set<String> allowed, Set<String> granted) =>
    allowed.length == granted.length && allowed.containsAll(granted);
