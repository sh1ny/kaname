/// The route catalogue's value types (design D5 of `esi-client-generator`).
library;

import 'transport.dart';

/// How a route splits a long result across calls.
enum EsiPagination {
  /// One call returns the whole result.
  none,

  /// A `page` query parameter, with the page count in `X-Pages`.
  pages,

  /// `before` and `after` cursor parameters.
  cursor,
}

/// The rate-limit group a route spends from, as the spec's `x-rate-limit`
/// extension states it.
///
/// A route whose operation has no `x-rate-limit` carries
/// [EsiRateGroup.none], a case of its own, never a null group. The
/// catalogue only reports what the spec states: what a group's budget means
/// and how calls are paced against it belongs to the request scheduler
/// (constraint C5 of `esi-client-generator`).
sealed class EsiRateGroup {
  const EsiRateGroup();

  /// The group of every route the spec gives no rate limit.
  static const EsiRateGroup none = EsiNoRateGroup._();
}

/// The route states no rate limit.
final class EsiNoRateGroup extends EsiRateGroup {
  const EsiNoRateGroup._();

  @override
  String toString() => 'EsiRateGroup.none';
}

/// The route spends from the named group.
final class EsiRateLimited extends EsiRateGroup {
  /// Creates a group of [maxTokens] tokens over [window].
  const EsiRateLimited({
    required this.name,
    required this.maxTokens,
    required this.window,
  });

  /// The group name, such as `alliance-social`.
  final String name;

  /// The tokens the group holds per window.
  final int maxTokens;

  /// The window the tokens refill over.
  final Duration window;

  @override
  bool operator ==(Object other) =>
      other is EsiRateLimited &&
      other.name == name &&
      other.maxTokens == maxTokens &&
      other.window == window;

  @override
  int get hashCode => Object.hash(name, maxTokens, window);

  @override
  String toString() => 'EsiRateLimited($name, $maxTokens per $window)';
}

/// What the pinned spec states about one operation.
final class EsiRoute {
  /// Creates a route entry.
  const EsiRoute({
    required this.operationId,
    required this.method,
    required this.pathTemplate,
    required this.rateGroup,
    required this.pagination,
    this.requiresAuthentication = false,
    this.scopes = const [],
    this.roles = const [],
    this.cacheMode,
    this.serverCacheMode,
    this.serverCacheTtl,
    this.clientCacheTtl,
    this.cacheAge,
  });

  /// The spec's operation id.
  final String operationId;

  /// The HTTP method.
  final EsiMethod method;

  /// The path template, such as `/characters/{character_id}/assets`.
  final String pathTemplate;

  /// The rate-limit group, or [EsiRateGroup.none].
  final EsiRateGroup rateGroup;

  /// How the route paginates.
  final EsiPagination pagination;

  /// Whether a call needs an SSO token.
  final bool requiresAuthentication;

  /// The SSO scopes the route requires; empty for a public route.
  final List<String> scopes;

  /// The corporation roles the spec says the route requires.
  final List<String> roles;

  /// `x-cache-mode`, when stated.
  final String? cacheMode;

  /// `x-server-cache-mode`, when stated.
  final String? serverCacheMode;

  /// `x-server-cache-ttl`, when stated.
  final Duration? serverCacheTtl;

  /// `x-client-cache-ttl`, when stated.
  final Duration? clientCacheTtl;

  /// `x-cache-age`, when stated.
  final Duration? cacheAge;

  @override
  bool operator ==(Object other) =>
      other is EsiRoute &&
      other.operationId == operationId &&
      other.method == method &&
      other.pathTemplate == pathTemplate &&
      other.rateGroup == rateGroup &&
      other.pagination == pagination &&
      other.requiresAuthentication == requiresAuthentication &&
      _sameList(other.scopes, scopes) &&
      _sameList(other.roles, roles) &&
      other.cacheMode == cacheMode &&
      other.serverCacheMode == serverCacheMode &&
      other.serverCacheTtl == serverCacheTtl &&
      other.clientCacheTtl == clientCacheTtl &&
      other.cacheAge == cacheAge;

  @override
  int get hashCode => Object.hash(
    operationId,
    method,
    pathTemplate,
    rateGroup,
    pagination,
    requiresAuthentication,
    Object.hashAll(scopes),
    Object.hashAll(roles),
    cacheMode,
    serverCacheMode,
    serverCacheTtl,
    clientCacheTtl,
    cacheAge,
  );

  @override
  String toString() => 'EsiRoute(${method.wire} $pathTemplate)';
}

/// Every route of the pinned spec, found by operation id or by method and
/// path template.
final class EsiCatalogue {
  /// Creates a catalogue from its two indexes; the generator writes both.
  const EsiCatalogue({
    required Map<String, EsiRoute> byOperationId,
    required Map<String, EsiRoute> byMethodAndPath,
  }) : _byOperationId = byOperationId,
       _byMethodAndPath = byMethodAndPath;

  final Map<String, EsiRoute> _byOperationId;
  final Map<String, EsiRoute> _byMethodAndPath;

  /// Every route, in the spec's order.
  Iterable<EsiRoute> get routes => _byOperationId.values;

  /// The route of [operationId], or `null` when the spec has none.
  EsiRoute? operator [](String operationId) => _byOperationId[operationId];

  /// The route for [method] on [pathTemplate], or `null` when the spec
  /// defines none.
  EsiRoute? find(EsiMethod method, String pathTemplate) =>
      _byMethodAndPath[methodAndPathKey(method, pathTemplate)];

  /// The key of the method-and-path index.
  static String methodAndPathKey(EsiMethod method, String pathTemplate) =>
      '${method.wire} $pathTemplate';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
