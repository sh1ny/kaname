/// A hand-written HTTP client for tests.
library;

import 'package:http/http.dart' as http;

/// Answers every request through [handler] and records the URLs asked for.
final class FakeHttpClient extends http.BaseClient {
  /// Creates a client answering through [handler].
  FakeHttpClient(this.handler);

  /// Produces the response for one request, or throws to simulate a failure.
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  /// The URLs requested, in order.
  final List<Uri> requested = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requested.add(request.url);
    return handler(request);
  }
}

/// A response that delivers [chunks] and then ends, optionally after
/// [delay] before each chunk, announcing [contentLength].
http.StreamedResponse chunkedResponse(
  List<List<int>> chunks, {
  int status = 200,
  int? contentLength,
  Duration delay = Duration.zero,
}) {
  Stream<List<int>> body() async* {
    for (final chunk in chunks) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield chunk;
    }
  }

  return http.StreamedResponse(body(), status, contentLength: contentLength);
}

/// A response with the whole of [bytes] in one chunk.
http.StreamedResponse bytesResponse(List<int> bytes, {int status = 200}) =>
    chunkedResponse([bytes], status: status, contentLength: bytes.length);
