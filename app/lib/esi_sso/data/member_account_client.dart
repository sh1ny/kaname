import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import 'call_log_client.dart' show KanameRpcBearer;

/// Generated account client bound to the verified viewer and server origin.
final class MemberAccountClient {
  /// [bearer] must already have been matched to [base]'s verified origin.
  MemberAccountClient(Uri base, String bearer)
    : _client = Client(
        base.toString(),
        connectionTimeout: const Duration(seconds: 15),
        httpClientOverride: _OriginClient(base.origin, http.Client()),
      )..authKeyProvider = KanameRpcBearer(bearer);

  final Client _client;

  /// Reads one bounded page. Ingress busy has the same result as account busy.
  Future<MemberRosterPage> page(String? after) async {
    try {
      return await _client.memberRoster.page(after);
    } on ServerpodClientHttpException catch (error) {
      return MemberRosterPage(
        status: switch (error.statusCode) {
          401 || 403 => MemberRosterStatus.denied,
          429 => MemberRosterStatus.busy,
          _ => MemberRosterStatus.unavailable,
        },
        characters: [],
      );
    } on Object {
      return MemberRosterPage(
        status: MemberRosterStatus.unavailable,
        characters: [],
      );
    }
  }

  /// Selects a different main, keeping the same connected session.
  Future<MemberAccountStatus> makeMain(String character) =>
      _mutate(() => _client.memberAccount.makeMain(character));

  /// Detaches a character. Only a typed reply establishes a definitive result.
  Future<MemberAccountStatus> unlink(String character) => _mutate(
    () => _client.memberAccount.unlink(character),
    requireTypedDenial: true,
  );

  Future<MemberAccountStatus> _mutate(
    Future<MemberAccountMutation> Function() send, {
    bool requireTypedDenial = false,
  }) async {
    try {
      return (await send()).status;
    } on ServerpodClientHttpException catch (error) {
      return switch (error.statusCode) {
        401 || 403 when !requireTypedDenial => MemberAccountStatus.denied,
        _ => MemberAccountStatus.unavailable,
      };
    } on Object {
      return MemberAccountStatus.unavailable;
    }
  }

  /// Discards the viewer-specific client when the session no longer matches.
  void close() => _client.close();
}

final class _OriginClient extends http.BaseClient {
  _OriginClient(this._origin, this._client);

  final String _origin;
  final http.Client _client;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != _origin) {
      throw http.ClientException('Unexpected account server origin.');
    }
    request.followRedirects = false;
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
