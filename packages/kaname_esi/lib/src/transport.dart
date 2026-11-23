/// The one way a request leaves the ESI client: an injected [EsiTransport].
library;

import 'dart:typed_data';

/// The HTTP methods ESI operations use.
enum EsiMethod {
  /// `GET`.
  get('GET'),

  /// `POST`.
  post('POST'),

  /// `PUT`.
  put('PUT'),

  /// `DELETE`.
  delete('DELETE');

  const EsiMethod(this.wire);

  /// The method as it is written on the wire.
  final String wire;
}

/// One request the client asks a transport to send.
///
/// It holds only what goes on the wire, plus the operation id so a
/// scheduler can find the route's catalogue entry without parsing paths. It
/// never holds a caller's identity, token or priority: those are bound on
/// the transport instance (design D13 of `esi-client-generator`).
final class EsiRequest {
  /// Creates a request; [headers] are copied and cannot be changed later.
  EsiRequest({
    required this.method,
    required this.operationId,
    required this.target,
    required Map<String, String> headers,
    this.body,
  }) : headers = Map.unmodifiable(headers);

  /// The HTTP method.
  final EsiMethod method;

  /// The spec's operation id, such as `GetCharactersCharacterIdAssets`.
  final String operationId;

  /// The request target: a relative URI holding the filled path and the
  /// query, percent-encoded exactly once by the client.
  ///
  /// The transport resolves it against `https://esi.evetech.net` and never
  /// encodes it again.
  final Uri target;

  /// The headers the client sets: always `X-Compatibility-Date`, and
  /// `If-None-Match`, `Accept-Language` and `Content-Type` when they apply.
  final Map<String, String> headers;

  /// The JSON request body as UTF-8 bytes, or `null` when there is none.
  final Uint8List? body;
}

/// Sends [EsiRequest]s to ESI on the client's behalf.
///
/// The client has no network access of its own; whoever supplies the
/// transport also decides which character's token and budget a call uses
/// and its priority (constraint C8 of `esi-client-generator`).
///
/// `User-Agent`, `Authorization`, `If-Modified-Since` and `X-Tenant` are the
/// transport's headers, never the generated client's (constraint C6 of
/// `esi-client-generator`): the client never sets them, and a transport adds
/// them as its own policy requires.
abstract interface class EsiTransport {
  /// Sends [request] and reports what came back, or why nothing did.
  ///
  /// Implementations report failures as [EsiTransportFailure] rather than
  /// throwing.
  Future<EsiTransportOutcome> send(EsiRequest request);
}

/// What a transport reports for one request.
sealed class EsiTransportOutcome {
  const EsiTransportOutcome();
}

/// ESI answered with [status].
final class EsiResponse extends EsiTransportOutcome {
  /// Creates a response; header names are lower-cased.
  EsiResponse({
    required this.status,
    Map<String, String> headers = const {},
    Uint8List? body,
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       }),
       body = body ?? Uint8List(0);

  /// The HTTP status code.
  final int status;

  /// The response headers, with lower-cased names.
  final Map<String, String> headers;

  /// The response body bytes; empty when there is none.
  final Uint8List body;
}

/// The request could not be sent or no answer came back.
final class EsiTransportFailure extends EsiTransportOutcome {
  /// Creates a failure explained by [reason].
  const EsiTransportFailure(this.reason);

  /// Why the request failed, for logs and diagnostics.
  final String reason;
}
