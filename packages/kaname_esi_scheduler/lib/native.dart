/// Native ESI composition; only scheduled generated clients reach the sender.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_esi/kaname_esi.dart';

import 'src/memory_state.dart';
import 'src/scheduler.dart';
import 'src/state.dart';

/// Owns native HTTP exchanges for one scheduler runtime.
final class NativeEsiRuntime {
  NativeEsiRuntime._(this.scheduler, this._http);

  /// Creates the scheduler for one native solo runtime with in-process state.
  ///
  /// [key] is a private per-install hash/jitter seed. [userAgent] identifies
  /// the installation and includes contact information. Test origin overrides
  /// are restricted to numeric loopback addresses.
  factory NativeEsiRuntime.solo({
    required List<int> key,
    required String userAgent,
    Uri? testOrigin,
    DateTime Function()? now,
    EsiCallLogSink? callLog,
    void Function()? onCallLogFailure,
  }) => NativeEsiRuntime.shared(
    state: MemorySchedulerState(paceStartup: true),
    key: key,
    userAgent: userAgent,
    testOrigin: testOrigin,
    now: now,
    callLog: callLog,
    onCallLogFailure: onCallLogFailure,
  );

  /// Creates an isolate-local scheduler front end for a shared state adapter.
  ///
  /// [onStateFailure] reports a post-send reconciliation failure without
  /// exporting private headers or raw exceptions.
  factory NativeEsiRuntime.shared({
    required SchedulerState state,
    required List<int> key,
    required String userAgent,
    Uri? testOrigin,
    void Function()? onStateFailure,
    DateTime Function()? now,
    EsiCallLogSink? callLog,
    void Function()? onCallLogFailure,
  }) {
    if (key.isEmpty ||
        userAgent.trim().isEmpty ||
        userAgent.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw ArgumentError(
        'An install key and a valid ESI User-Agent are required',
      );
    }
    if (testOrigin != null && !_isLoopback(testOrigin)) {
      throw ArgumentError('ESI test origin must be a numeric loopback origin');
    }
    final http = _NativeHttp(
      testOrigin ?? Uri.https('esi.evetech.net'),
      userAgent,
    );
    return NativeEsiRuntime._(
      EsiScheduler(
        state: state,
        key: key,
        send: http.send,
        now: now,
        onStateFailure: onStateFailure,
        callLog: callLog,
        onCallLogFailure: onCallLogFailure,
      ),
      http,
    );
  }

  /// The scheduler that binds generated clients to this runtime.
  final EsiScheduler scheduler;
  final _NativeHttp _http;

  /// Aborts active sends and prevents new sends during runtime shutdown.
  void close() => _http.close();

  static bool _isLoopback(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host == '127.0.0.1' || uri.host == '::1') &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.path.isEmpty || uri.path == '/');
}

final class _NativeHttp {
  _NativeHttp(this._origin, this._userAgent);

  static const _deadline = Duration(seconds: 20);
  static const _limit = 16 * 1024 * 1024;
  final Uri _origin;
  final String _userAgent;
  final _active = <HttpClient>{};
  bool _closed = false;

  Future<WireOutcome> send(
    EsiRequest request,
    String? bearer,
    String? validator,
  ) async {
    final path = request.target;
    if (_closed ||
        path.hasScheme ||
        path.hasAuthority ||
        path.hasFragment ||
        !path.path.startsWith('/')) {
      return const WireFailure.unsent();
    }
    // A failed client's socket must be abortable without cancelling other
    // reservations. No pooled stale connection can trigger a resend.
    final client = HttpClient()..connectionTimeout = _deadline;
    _active.add(client);
    EsiResponse? head;
    var connected = false;
    try {
      return await (() async {
        final outgoing = await client.openUrl(
          request.method.wire,
          _origin.resolveUri(path),
        );
        connected = true;
        outgoing
          ..followRedirects = false
          ..persistentConnection = false;
        for (final MapEntry(:key, :value) in request.headers.entries) {
          if (key.toLowerCase() != 'if-none-match') {
            outgoing.headers.set(key, value);
          }
        }
        outgoing.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        if (validator != null) outgoing.headers.set('if-none-match', validator);
        if (bearer != null) {
          outgoing.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $bearer',
          );
        }
        if (request.body case final body?) outgoing.add(body);
        final response = await outgoing.close();
        final headers = <String, String>{};
        response.headers.forEach(
          (name, values) => headers[name] = values.join(', '),
        );
        head = EsiResponse(status: response.statusCode, headers: headers);
        if (response.contentLength > _limit) return WireFailure(head: head);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (chunk.length > _limit - bytes.length) {
            return WireFailure(head: head);
          }
          bytes.add(chunk);
        }
        return WireResponse(
          EsiResponse(
            status: response.statusCode,
            headers: headers,
            body: bytes.takeBytes(),
          ),
        );
      })().timeout(
        _deadline,
        onTimeout: () =>
            WireFailure(head: head, connectivityFailure: !connected),
      );
    } on Exception {
      return WireFailure(head: head, connectivityFailure: !connected);
    } finally {
      _active.remove(client);
      client.close(force: true);
    }
  }

  void close() {
    _closed = true;
    for (final client in _active) {
      client.close(force: true);
    }
  }
}
