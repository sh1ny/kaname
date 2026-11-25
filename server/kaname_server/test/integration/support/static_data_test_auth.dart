import 'package:kaname_client/kaname_client.dart' as api;
import 'package:serverpod/serverpod.dart';

const staticDataTestBearer = 'synthetic-static-data-admin-session';

Future<AuthenticationInfo?> staticDataTestAuthentication(
  Session _,
  String bearer,
) async => bearer == staticDataTestBearer
    ? AuthenticationInfo('1', {Scope.admin}, authId: 'test-admin')
    : null;

api.Client staticDataTestClient(String url, {bool admin = true}) =>
    api.Client(url)..authKeyProvider = admin ? const _TestBearer() : null;

final class _TestBearer implements api.ClientAuthKeyProvider {
  const _TestBearer();

  @override
  Future<String> get authHeaderValue async =>
      api.wrapAsBearerAuthHeaderValue(staticDataTestBearer);
}
