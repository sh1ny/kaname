/// The closed set of results an ESI call returns (design D2 of
/// `esi-client-generator`).
library;

import 'transport.dart';

/// What one ESI call produced. Calls never throw for an HTTP outcome or a
/// response body; every case is one of these.
sealed class EsiResult<T> {
  const EsiResult();
}

/// ESI answered with a success status and a body that matches the schema.
final class EsiSuccess<T> extends EsiResult<T> {
  /// Creates a success.
  const EsiSuccess({
    required this.body,
    required this.status,
    this.etag,
    this.expires,
    this.lastModified,
    this.pages,
  });

  /// The typed body; `null` for an operation that answers with no content.
  final T body;

  /// The HTTP status code (200, 201 or 204).
  final int status;

  /// The `ETag` header, when present.
  final String? etag;

  /// The `Expires` header as sent, when present.
  final String? expires;

  /// The `Last-Modified` header as sent, when present.
  final String? lastModified;

  /// The page count from `X-Pages`, when present.
  final int? pages;
}

/// ESI answered 304: the caller's copy, named by its ETag, is current.
final class EsiNotModified<T> extends EsiResult<T> {
  /// Creates a not-modified result.
  const EsiNotModified({this.etag, this.expires});

  /// The `ETag` header, when present.
  final String? etag;

  /// The `Expires` header as sent, when present.
  final String? expires;
}

/// ESI answered with an error status.
final class EsiError<T> extends EsiResult<T> {
  /// Creates an error result.
  const EsiError({required this.status, this.message});

  /// The HTTP status code.
  final int status;

  /// The `error` message of ESI's JSON error body, when it could be read.
  final String? message;
}

/// ESI answered with a success status, but the body does not match the
/// operation's schema.
final class EsiMalformed<T> extends EsiResult<T> {
  /// Creates a malformed-response result.
  const EsiMalformed({
    required this.status,
    required this.path,
    required this.reason,
  });

  /// The HTTP status code.
  final int status;

  /// The JSON path of the first mismatch, such as `$.items[2].type_id`;
  /// `$` for the body itself.
  final String path;

  /// What differs from the schema.
  final String reason;
}

/// The call's arguments break a bound the spec states; nothing was sent.
final class EsiInvalidRequest<T> extends EsiResult<T> {
  /// Creates an invalid-request result.
  const EsiInvalidRequest({required this.parameter, required this.reason});

  /// The parameter at fault, such as `body` or `page`.
  final String parameter;

  /// Which bound it breaks.
  final String reason;
}

/// The transport could not send the request or got no answer.
final class EsiTransportFailed<T> extends EsiResult<T> {
  /// Creates a transport-failure result carrying the transport's [reason].
  const EsiTransportFailed(this.reason);

  /// The transport's report.
  final String reason;
}

/// The scheduler declined this call without sending it to ESI.
final class EsiNotSent<T> extends EsiResult<T> {
  /// Creates a not-sent result from the transport's refusal.
  const EsiNotSent(this.refusal);

  /// The reason and optional retry deadline, not a wire response.
  final EsiTransportRefused refusal;
}
