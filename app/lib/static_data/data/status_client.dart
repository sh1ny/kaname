import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import 'rpc_call.dart';

/// Reads the server's public static-data snapshot (D8, D9).
abstract interface class StaticDataStatusClient {
  /// Starts a read, retaining the transport lifetime after an early timeout.
  RpcCall<StaticDataStatus> read();
}

/// A [StaticDataStatusClient] over the generated Kaname API.
final class ClientStaticDataStatus implements StaticDataStatusClient {
  /// Uses the resolved [base] URI, including its configured path prefix.
  ClientStaticDataStatus(
    Uri base, {
    http.Client? httpClientOverride,
    this._answerTimeout = const Duration(seconds: 10),
  }) : _client = Client(
         base.toString(),
         httpClientOverride: httpClientOverride,
       );

  final Client _client;
  final Duration _answerTimeout;

  @override
  RpcCall<StaticDataStatus> read() =>
      startRpc(_client.staticData.status, answerTimeout: _answerTimeout);

  /// Releases the generated client's resources.
  void close() => _client.close();
}
