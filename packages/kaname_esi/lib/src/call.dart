/// Runs one operation: builds its request target and headers, sends it
/// through the transport and turns the outcome into an [EsiResult].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'json.dart';
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

/// A call argument outside the bounds the pinned spec states.
///
/// Argument checks raise it; [EsiCall.invoke] turns it into
/// [EsiInvalidRequest], so it never escapes a call and nothing is sent.
final class EsiInvalidArgument implements Exception {
  /// Creates a broken bound of the parameter at [path], explained by
  /// [reason].
  const EsiInvalidArgument(this.path, this.reason);

  /// The parameter, such as `page` or `body[0]`.
  final String path;

  /// Which bound the value breaks.
  final String reason;

  @override
  String toString() => 'EsiInvalidArgument($path: $reason)';
}

/// Decodes an operation's JSON body, raising [EsiDecodeException] on a
/// mismatch.
typedef EsiDecoder<T> = T Function(Object? json);

/// The request and response plumbing generated operations share.
abstract final class EsiCall {
  /// Builds a relative request target from an already encoded [path] and
  /// the [query] pairs [EsiCall.query] built, which are already encoded.
  static Uri target(String path, [List<(String, String)> query = const []]) {
    if (query.isEmpty) return Uri.parse(path);
    final joined = [for (final (name, value) in query) '$name=$value'];
    return Uri.parse('$path?${joined.join('&')}');
  }

  /// The query pairs of the parameter [name] holding the JSON [value],
  /// each name and item percent-encoded exactly once: none for `null`, one
  /// pair per item of an array when [explode] is true, one pair joining the
  /// encoded items with literal commas when it is false (so a comma inside
  /// an item stays data), and one pair for a scalar.
  static List<(String, String)> query(
    String name,
    Object? value, {
    bool explode = true,
  }) {
    final key = Uri.encodeQueryComponent(name);
    String encode(Object? item) => Uri.encodeQueryComponent('$item');
    return switch (value) {
      null => const [],
      final List<Object?> items when explode => [
        for (final item in items) (key, encode(item)),
      ],
      final List<Object?> items => [(key, items.map(encode).join(','))],
      _ => [(key, encode(value))],
    };
  }

  /// Builds a request with [build] and runs it as [run] does.
  ///
  /// [build] checks the arguments; an [EsiInvalidArgument] it raises becomes
  /// [EsiInvalidRequest] and nothing is sent. The body is read with [read]
  /// from the root path `$`.
  static Future<EsiResult<T>> invoke<T>(
    EsiTransport transport,
    EsiRequest Function() build, {
    required EsiRead<T> read,
    T Function()? noContent,
  }) async {
    final EsiRequest request;
    try {
      request = build();
    } on EsiInvalidArgument catch (error) {
      return EsiInvalidRequest(parameter: error.path, reason: error.reason);
    }
    return run(
      transport,
      request,
      decode: (json) => read(json, r'$'),
      noContent: noContent,
    );
  }

  /// Percent-encodes one path parameter value, the parameter named [path].
  ///
  /// Percent-encoding leaves `.` and `..` as they are, and URI
  /// normalisation would treat them as path syntax, so an empty, `.` or `..`
  /// value raises [EsiInvalidArgument] instead of reaching the transport.
  static String segment(Object? value, String path) => switch ('$value') {
    '' || '.' || '..' => throw EsiInvalidArgument(
      path,
      'must not be empty, "." or ".." in a path segment',
    ),
    final text => Uri.encodeComponent(text),
  };

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
    switch (outcome) {
      case EsiTransportFailure(:final reason):
        return EsiTransportFailed(reason);
      case EsiTransportRefused():
        return EsiNotSent(outcome);
      case EsiResponse(:final decodeReceipt):
        var usable = false;
        try {
          final result = read(outcome, decode: decode, noContent: noContent);
          usable = result is EsiSuccess<T> || result is EsiNotModified<T>;
          return result;
        } finally {
          if (decodeReceipt != null) await decodeReceipt(usable);
        }
    }
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
