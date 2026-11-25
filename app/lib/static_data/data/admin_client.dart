/// Static-data admin commands over the generated client.
library;

import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import '../../esi_sso/data/call_log_client.dart' show KanameRpcBearer;
import '../../server/data/secure_for_admin.dart';
import 'rpc_call.dart';

/// Sends admin commands and reads public operation progress.
abstract interface class StaticDataAdminClient {
  /// Starts or resends the update identified by [operationId].
  RpcCall<AdminAnswer> updateNow(String bearer, String operationId);

  /// Starts or resends a rollback against [expectedRevision].
  RpcCall<AdminAnswer> rollBack(
    String bearer,
    String operationId,
    int expectedRevision,
  );

  /// Writes or retries a setting using the same [writeId] and revision.
  RpcCall<AdminAnswer> setAutoUpdate(
    String bearer,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  );

  /// Reads public progress for [operationId] without a session bearer.
  RpcCall<AdminOperationAnswer> operation(String operationId);
}

/// A generated-client implementation with bounded answer and transport waits.
final class ClientStaticDataAdmin implements StaticDataAdminClient {
  /// Creates an adapter for [base], optionally using [httpClientOverride].
  ClientStaticDataAdmin(Uri base, {http.Client? httpClientOverride})
    : _secure = isSecureForAdmin(base),
      _client = Client(
        base.toString(),
        connectionTimeout: const Duration(seconds: 45),
        httpClientOverride: httpClientOverride,
      );

  final bool _secure;
  final Client _client;

  RpcCall<AdminAnswer> _admin(
    String bearer,
    Future<AdminAnswer> Function() send, {
    Duration? answerTimeout,
  }) {
    if (!_secure) {
      final unanswered = Future<RpcResult<AdminAnswer>>.value(
        const RpcUnanswered<AdminAnswer>(),
      );
      return (answer: unanswered, settled: unanswered);
    }
    return startRpc(() {
      // Serverpod captures the immutable provider before its first await.
      // Public reads never inherit it, and settled sends cannot reuse it.
      _client.authKeyProvider = KanameRpcBearer(bearer);
      try {
        return send();
      } finally {
        _client.authKeyProvider = null;
      }
    }, answerTimeout: answerTimeout);
  }

  @override
  RpcCall<AdminAnswer> updateNow(String bearer, String operationId) => _admin(
    bearer,
    () => _client.staticDataAdmin.updateNow(operationId),
    answerTimeout: const Duration(seconds: 15),
  );

  @override
  RpcCall<AdminAnswer> rollBack(
    String bearer,
    String operationId,
    int expectedRevision,
  ) => _admin(
    bearer,
    () => _client.staticDataAdmin.rollBack(operationId, expectedRevision),
    answerTimeout: const Duration(seconds: 40),
  );

  @override
  RpcCall<AdminAnswer> setAutoUpdate(
    String bearer,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) => _admin(
    bearer,
    () =>
        _client.staticDataAdmin.setAutoUpdate(value, expectedRevision, writeId),
  );

  @override
  RpcCall<AdminOperationAnswer> operation(String operationId) =>
      startRpc(() => _client.staticData.operation(operationId));

  /// Closes the generated client and its transport.
  void close() => _client.close();
}

/// Generates a cryptographically random UUID v4 for one press or write.
String newStaticDataRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
