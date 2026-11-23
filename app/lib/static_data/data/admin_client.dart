/// Static-data admin commands over the generated client.
library;

import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import '../../server/data/secure_for_admin.dart';
import 'rpc_call.dart';

/// Sends admin commands and reads public operation progress.
abstract interface class StaticDataAdminClient {
  /// Checks the in-memory key without changing server state.
  RpcCall<AdminAnswer> checkKey(String key);

  /// Starts or resends the update identified by [operationId].
  RpcCall<AdminAnswer> updateNow(String key, String operationId);

  /// Starts or resends a rollback against [expectedRevision].
  RpcCall<AdminAnswer> rollBack(
    String key,
    String operationId,
    int expectedRevision,
  );

  /// Writes or retries a setting using the same [writeId] and revision.
  RpcCall<AdminAnswer> setAutoUpdate(
    String key,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  );

  /// Reads public progress for [operationId] without an admin key.
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
    Future<AdminAnswer> Function() send, {
    Duration? answerTimeout,
  }) {
    if (!_secure) {
      final unanswered = Future<RpcResult<AdminAnswer>>.value(
        const RpcUnanswered<AdminAnswer>(),
      );
      return (answer: unanswered, settled: unanswered);
    }
    return startRpc(send, answerTimeout: answerTimeout);
  }

  @override
  RpcCall<AdminAnswer> checkKey(String key) =>
      _admin(() => _client.staticDataAdmin.checkKey(key));

  @override
  RpcCall<AdminAnswer> updateNow(String key, String operationId) => _admin(
    () => _client.staticDataAdmin.updateNow(key, operationId),
    answerTimeout: const Duration(seconds: 15),
  );

  @override
  RpcCall<AdminAnswer> rollBack(
    String key,
    String operationId,
    int expectedRevision,
  ) => _admin(
    () => _client.staticDataAdmin.rollBack(key, operationId, expectedRevision),
    answerTimeout: const Duration(seconds: 40),
  );

  @override
  RpcCall<AdminAnswer> setAutoUpdate(
    String key,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) => _admin(
    () => _client.staticDataAdmin.setAutoUpdate(
      key,
      value,
      expectedRevision,
      writeId,
    ),
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
