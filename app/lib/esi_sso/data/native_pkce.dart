import 'dart:async';
import 'dart:io';

import 'package:kaname_esi_sso/kaname_esi_sso.dart';

/// Outcome of the desktop loopback, code exchange and grant verification.
sealed class NativePkceResult {
  const NativePkceResult();
}

/// A signed grant, still subject to holder and policy checks before activation.
final class NativeSignedGrant extends NativePkceResult {
  const NativeSignedGrant._(this.identity, this.grant);

  /// The verified CCP character and scopes.
  final CcpVerifiedIdentity identity;

  /// The grant for the native vault only. Never display or send to Kaname.
  final CcpGrant grant;
}

/// Fixed desktop OAuth failure codes.
enum NativePkceFailure implements NativePkceResult {
  /// The user or CCP cancelled the attempt.
  cancelled,

  /// The listener or CCP was unavailable, or the attempt timed out.
  unavailable,

  /// The server did not return a valid grant for the requested scopes.
  rejected,
}

/// Owns one bound single-use native OAuth attempt and its loopback listeners.
final class NativePkce {
  /// Tests can choose an ephemeral [_port]; production uses the registered one.
  NativePkce({
    required this._oauth,
    required this._verifier,
    this._port = 48175,
  });

  final CcpOAuth _oauth;
  final CcpJwtVerifier _verifier;
  final int _port;
  Completer<NativePkceResult>? _active;
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  /// Runs the external browser flow. [launch] opens the CCP authorization URL.
  Future<NativePkceResult> run({
    required String clientId,
    required Set<String> scopes,
    required Future<bool> Function(Uri) launch,
  }) async {
    if (_active != null || !_id.hasMatch(clientId)) {
      return NativePkceFailure.unavailable;
    }
    final done = Completer<NativePkceResult>();
    _active = done;
    final timer = Timer(
      const Duration(minutes: 5),
      () => _finish(done, NativePkceFailure.unavailable),
    );
    final listeners = <HttpServer>[];
    try {
      var port = _port;
      for (final address in [
        InternetAddress.loopbackIPv4,
        InternetAddress.loopbackIPv6,
      ]) {
        try {
          final listener = await HttpServer.bind(
            address,
            port,
            v6Only: address.type == InternetAddressType.IPv6,
          );
          listeners.add(listener);
          port = listener.port;
        } on SocketException catch (e) {
          if (!const {
            47,
            49,
            97,
            99,
            10047,
            10049,
          }.contains(e.osError?.errorCode)) {
            rethrow;
          }
        }
      }
      if (listeners.isEmpty || done.isCompleted) {
        return NativePkceFailure.unavailable;
      }
      final registration = CcpPublic(
        clientId,
        Uri(
          scheme: 'http',
          host: 'localhost',
          port: port,
          path: '/auth/esi/callback',
        ),
      );
      final state = newOAuthProof();
      final proof = newOAuthProof();
      var consumed = false;
      for (final listener in listeners) {
        listener.listen(
          (request) async {
            try {
              if (request.method != 'GET' ||
                  request.uri.toString().length > 8192 ||
                  request.uri.path != '/auth/esi/callback' ||
                  request.headers.value(HttpHeaders.hostHeader) !=
                      'localhost:$port' ||
                  request.contentLength > 0 ||
                  request.headers.chunkedTransferEncoding ||
                  consumed ||
                  done.isCompleted) {
                await _page(request, false);
                return;
              }
              final query = request.uri.queryParametersAll;
              if (query['state'] case [final received] when received == state) {
                if (query['error'] case ['access_denied']
                    when !query.containsKey('code')) {
                  consumed = true;
                  await _page(request, false);
                  _finish(done, NativePkceFailure.cancelled);
                  return;
                }
                if (query['code'] case [final code]
                    when code.isNotEmpty && !query.containsKey('error')) {
                  consumed = true;
                  final exchange = await _oauth.exchange(
                    registration,
                    code,
                    verifier: proof,
                  );
                  if (exchange is CcpGrant && !done.isCompleted) {
                    final identity = await _verifier.verify(
                      exchange.accessToken,
                      clientId: clientId,
                    );
                    if (identity is CcpVerifiedIdentity &&
                        matchesGrantedScopes(scopes, identity.scopes) &&
                        !done.isCompleted) {
                      await _page(request, true);
                      _finish(done, NativeSignedGrant._(identity, exchange));
                      return;
                    }
                  }
                  await _page(request, false);
                  _finish(
                    done,
                    exchange == CcpExchangeFailure.unavailable
                        ? NativePkceFailure.unavailable
                        : NativePkceFailure.rejected,
                  );
                  return;
                }
              }
              await _page(request, false);
            } on Object {
              request.response
                  .detachSocket()
                  .then((socket) => socket.destroy())
                  .ignore();
              if (consumed) _finish(done, NativePkceFailure.unavailable);
            }
          },
          onError: (Object error) =>
              _finish(done, NativePkceFailure.unavailable),
        );
      }
      final url = await _oauth.authorizationUrl(
        registration,
        state: state,
        scopes: scopes,
        verifier: proof,
      );
      if (url == null) return NativePkceFailure.unavailable;
      if (!done.isCompleted) unawaited(_open(launch, url, done));
      return await done.future;
    } on Object {
      return NativePkceFailure.unavailable;
    } finally {
      timer.cancel();
      for (final listener in listeners) {
        await listener.close(force: true);
      }
      _active = null;
    }
  }

  /// Cancels the current attempt without installing any credential.
  void cancel() {
    if (_active case final active?) {
      _finish(active, NativePkceFailure.cancelled);
    }
  }

  static Future<void> _open(
    Future<bool> Function(Uri) launch,
    Uri uri,
    Completer<NativePkceResult> done,
  ) async {
    try {
      if (await launch(uri)) return;
    } on Object {
      // A platform exception is not suitable for display.
    }
    _finish(done, NativePkceFailure.unavailable);
  }

  static void _finish(
    Completer<NativePkceResult> done,
    NativePkceResult result,
  ) {
    if (!done.isCompleted) done.complete(result);
  }

  static Future<void> _page(HttpRequest request, bool ok) async {
    final response = request.response;
    response.statusCode = ok ? 200 : 400;
    response.headers
      ..contentType = ContentType.html
      ..set('cache-control', 'no-store')
      ..set('referrer-policy', 'no-referrer')
      ..set(
        'content-security-policy',
        "default-src 'none'; frame-ancestors 'none'",
      )
      ..set('x-content-type-options', 'nosniff');
    response.write(
      ok
          ? '<!doctype html><title>Kaname sign-in</title><p>Return to Kaname to continue.</p>'
          : '<!doctype html><title>Kaname sign-in</title><p>Kaname could not finish this request.</p>',
    );
    await response.close();
  }
}
