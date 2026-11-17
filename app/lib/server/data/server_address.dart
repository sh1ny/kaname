/// Where the app finds its Kaname server.
library;

/// The outcome of resolving the server address.
sealed class ServerTarget {
  const ServerTarget();
}

/// A usable server base address, always ending in `/`.
final class ConfiguredServer extends ServerTarget {
  /// Creates a target for the server at [uri].
  const ConfiguredServer(this.uri);

  /// The absolute `http` or `https` base address of the server.
  final Uri uri;
}

/// No server address was given, so no call is made.
final class NoServer extends ServerTarget {
  /// Creates the no-server target.
  const NoServer();
}

/// A server address was given but is not an absolute `http` or `https` URL.
final class InvalidServer extends ServerTarget {
  /// Creates an invalid target remembering the [raw] text that was rejected.
  const InvalidServer(this.raw);

  /// The rejected address as given.
  final String raw;
}

/// Resolves the server address from explicit platform inputs.
///
/// The class is pure: only `main()` reads `kIsWeb`, `kDebugMode`,
/// `String.fromEnvironment('KANAME_SERVER_URL')` and `Uri.base`, and passes
/// them in, so every rule is a plain unit test.
///
/// Rules:
///
/// - On the web the target is the origin of [base] plus `/api/` (scheme, host
///   and port kept; path, query and fragment dropped). One exception: a debug
///   web build ([isDebug]) with a non-empty [define] honours the define.
/// - Elsewhere the target is [define]; an empty define gives [NoServer].
/// - A define that does not parse, has no `http` or `https` scheme or has no
///   host gives [InvalidServer]. A missing trailing slash is added.
///
/// Carried constraint C3: `KANAME_SERVER_URL` is a build-time stand-in until a
/// connect flow exists (M2/M4). Profile and release web builds ignore it and
/// always use their own origin's `/api/`; only debug web builds honour it.
final class ServerAddress {
  /// Creates a resolver over the given platform inputs.
  const ServerAddress({
    required this.isWeb,
    required this.isDebug,
    required this.define,
    required this.base,
  });

  /// Whether the app runs on the web.
  final bool isWeb;

  /// Whether this is a debug build.
  final bool isDebug;

  /// The raw build-time `KANAME_SERVER_URL` value; empty when not given.
  final String define;

  /// The page origin on the web (`Uri.base`).
  final Uri base;

  /// Resolves the server target from the inputs.
  ServerTarget resolve() {
    if (isWeb && !(isDebug && define.isNotEmpty)) {
      return ConfiguredServer(
        Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: '/api/',
        ),
      );
    }
    if (define.isEmpty) return const NoServer();
    final parsed = Uri.tryParse(define);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      return InvalidServer(define);
    }
    final path = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
    return ConfiguredServer(
      Uri(
        scheme: parsed.scheme,
        host: parsed.host,
        port: parsed.hasPort ? parsed.port : null,
        path: path,
      ),
    );
  }
}
