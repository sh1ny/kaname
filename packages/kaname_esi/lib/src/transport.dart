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
  /// Creates a request; [headers] and [body] are copied and cannot be
  /// changed later, through this request or the caller's originals.
  EsiRequest({
    required this.method,
    required this.operationId,
    required this.target,
    required Map<String, String> headers,
    Uint8List? body,
  }) : headers = Map.unmodifiable(headers),
       body = body == null
           ? null
           : Uint8List.fromList(body).asUnmodifiableView();

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
  /// Read-only: writing to it throws [UnsupportedError].
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
       body = body ?? Uint8List(0),
       decodeReceipt = null;

  /// Reuses a wire response without copying its headers or body. The
  /// generated call awaits [decodeReceipt] once after attempting to decode.
  EsiResponse.withDecodeReceipt(EsiResponse wire, this.decodeReceipt)
    : status = wire.status,
      headers = wire.headers,
      body = wire.body;

  /// The HTTP status code.
  final int status;

  /// The response headers, with lower-cased names.
  final Map<String, String> headers;

  /// The response body bytes; empty when there is none.
  final Uint8List body;

  /// Reports whether the generated call produced a usable representation.
  final Future<void> Function(bool usable)? decodeReceipt;
}

/// The request could not be sent or no answer came back.
final class EsiTransportFailure extends EsiTransportOutcome {
  /// Creates a failure explained by [reason].
  const EsiTransportFailure(this.reason);

  /// Why the request failed, for logs and diagnostics.
  final String reason;
}

/// Why the scheduler declined a request before opening an HTTP exchange.
enum EsiRefusalReason {
  /// An applicable budget did not cover the reservation.
  budget,

  /// The governor stopped the applicable scope.
  stopped,

  /// The waiting queue had no space for this priority.
  queueFull,

  /// The admission ticket expired before dispatch.
  waitExpired,

  /// A prior forbidden or not-found result still suppresses this read.
  negativeCached,

  /// The caller already holds a representation that is not due for polling.
  notDue,

  /// Polling is paused while Tranquility is unavailable.
  outage,

  /// The shared scheduler state could not confirm dispatch.
  stateUnavailable,

  /// Another caller is polling the equivalent corporation representation.
  corpBusy,

  /// The scheduler could not track another scope without dropping live state.
  scopeCapacity,

  /// Upstream group observations disagree about which budget applies.
  routeConflict,

  /// The operation and supplied context cannot safely be used together.
  invalidContext,

  /// The shared store is waiting for prior upstream debits to drain.
  stateRecovering,
}

/// A scheduler decision, not an upstream response or a transport error.
final class EsiTransportRefused extends EsiTransportOutcome {
  /// Creates a refusal that is not a negative-cache hit.
  const EsiTransportRefused(this.reason, {this.retryAt})
    : assert(reason != EsiRefusalReason.negativeCached),
      suppressedStatus = null;

  /// Creates a refusal carrying the original forbidden or not-found status.
  const EsiTransportRefused.negativeCached(int status, {this.retryAt})
    : assert(status == 403 || status == 404),
      reason = EsiRefusalReason.negativeCached,
      suppressedStatus = status;

  /// The stable reason the scheduler refused to send.
  final EsiRefusalReason reason;

  /// The earliest indicated time to reconsider the request, when known.
  final DateTime? retryAt;

  /// The prior negative status, not a status of this request.
  final int? suppressedStatus;
}
