/// Runs one operation: builds its request target and headers, sends it
/// through the transport and turns the outcome into an [EsiResult].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'result.dart';
import 'transport.dart';

/// A response body that does not match the operation's schema.
///
/// Decoders raise it; [EsiCall.run] turns it into [EsiMalformed], so it never
/// escapes a call.
final class EsiDecodeException implements Exception {
  /// Creates a mismatch at the JSON [path], explained by [reason].
  const EsiDecodeException(this.path, this.reason);

  /// The JSON path of the mismatch, such as `$.items[2].type_id`.
  final String path;

  /// What differs from the schema.
  final String reason;

  @override
  String toString() => 'EsiDecodeException($path: $reason)';
}

/// Decodes an operation's JSON body, raising [EsiDecodeException] on a
/// mismatch.
typedef EsiDecoder<T> = T Function(Object? json);

/// The request and response plumbing generated operations share.
abstract final class EsiCall {
  /// Builds a relative request target from an already encoded [path] and
  /// the raw [query] pairs, percent-encoding each query name and value
  /// exactly once.
  static Uri target(String path, [List<(String, String)> query = const []]) {
    if (query.isEmpty) return Uri.parse(path);
    final encoded = [
      for (final (name, value) in query)
        '${Uri.encodeQueryComponent(name)}=${Uri.encodeQueryComponent(value)}',
    ].join('&');
    return Uri.parse('$path?$encoded');
  }

  /// Percent-encodes one path parameter value.
  static String segment(Object value) => Uri.encodeComponent('$value');

  /// The headers a request carries: always `X-Compatibility-Date`, and the
  /// optional ones only when given.
  static Map<String, String> headers({
    required String compatibilityDate,
    String? ifNoneMatch,
    String? acceptLanguage,
    bool jsonBody = false,
  }) => {
    'X-Compatibility-Date': compatibilityDate,
    'If-None-Match': ?ifNoneMatch,
    'Accept-Language': ?acceptLanguage,
    if (jsonBody) 'Content-Type': 'application/json',
  };

  /// Encodes a request body as UTF-8 JSON.
  static Uint8List jsonBody(Object? value) => utf8.encode(jsonEncode(value));

  /// Sends [request] through [transport] and reads the outcome.
  ///
  /// A 2xx body is decoded with [decode]; when [noContent] is given, a 204
  /// gives its value instead. Never throws for an HTTP status, a header or
  /// a body; an exception the transport throws becomes a transport failure.
  static Future<EsiResult<T>> run<T>(
    EsiTransport transport,
    EsiRequest request, {
    required EsiDecoder<T> decode,
    T Function()? noContent,
  }) async {
    final EsiTransportOutcome outcome;
    try {
      outcome = await transport.send(request);
    } on Exception catch (error) {
      return EsiTransportFailed('transport threw: $error');
    }
    return switch (outcome) {
      EsiTransportFailure(:final reason) => EsiTransportFailed(reason),
      EsiResponse() => read(outcome, decode: decode, noContent: noContent),
    };
  }

  /// Turns one [response] into a result, as [run] does.
  static EsiResult<T> read<T>(
    EsiResponse response, {
    required EsiDecoder<T> decode,
    T Function()? noContent,
  }) {
    final EsiResponse(:status, :headers, :body) = response;
    final etag = headers['etag'];
    final expires = headers['expires'];
    if (status == 304) return EsiNotModified(etag: etag, expires: expires);
    if (status < 200 || status > 299) {
      return EsiError(status: status, message: _errorMessage(body));
    }

    final int? pages;
    switch (headers['x-pages']) {
      case null:
        pages = null;
      case final text:
        pages = int.tryParse(text.trim());
        if (pages == null) {
          return EsiMalformed(
            status: status,
            path: r'$headers.x-pages',
            reason: 'X-Pages is not an integer: "$text"',
          );
        }
    }

    final T value;
    if (status == 204 && noContent != null) {
      value = noContent();
    } else {
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(body));
      } on FormatException catch (error) {
        return EsiMalformed(
          status: status,
          path: r'$',
          reason: 'body is not JSON: ${error.message}',
        );
      }
      try {
        value = decode(json);
      } on EsiDecodeException catch (error) {
        return EsiMalformed(
          status: status,
          path: error.path,
          reason: error.reason,
        );
      }
    }

    return EsiSuccess(
      body: value,
      status: status,
      etag: etag,
      expires: expires,
      lastModified: headers['last-modified'],
      pages: pages,
    );
  }

  static String? _errorMessage(Uint8List body) {
    try {
      return switch (jsonDecode(utf8.decode(body))) {
        {'error': final String message} => message,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}
