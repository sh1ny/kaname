import 'package:kaname_client/kaname_client.dart';

/// A generated client bound to one verified viewer and origin.
abstract interface class CallLogAccess {
  /// The server verified this session's admin scope.
  bool get admin;

  /// Lists one page for this viewer without a caller-supplied filter.
  Future<EsiCallLogPage> own(EsiCallLogCursor? after);

  /// Reads the released aggregate window without a period filter.
  Future<EsiRouteCountPage> totals();
}

/// Serverpod emits an auth header, never a bearer in an RPC parameter.
final class KanameRpcBearer implements ClientAuthKeyProvider {
  /// Captures one bearer for this request or bound viewer client.
  const KanameRpcBearer(this._token);

  final String _token;

  @override
  Future<String> get authHeaderValue async =>
      wrapAsBearerAuthHeaderValue(_token);
}

/// A viewer-scoped generated client for the Settings call-log panel.
final class ClientCallLog implements CallLogAccess {
  /// Binds the client to [base] and a bearer already checked for that origin.
  ClientCallLog(Uri base, String bearer, {required this.admin})
    : _client = Client(
        base.toString(),
        connectionTimeout: const Duration(seconds: 15),
      )..authKeyProvider = KanameRpcBearer(bearer);

  final Client _client;

  @override
  final bool admin;

  @override
  Future<EsiCallLogPage> own(EsiCallLogCursor? after) =>
      _client.esiCallLog.ownRows(after);

  @override
  Future<EsiRouteCountPage> totals() => _client.esiCallLog.routeCounts();

  /// Drops this viewer's client on sign-out or server change.
  void close() => _client.close();
}
