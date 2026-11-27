import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

const staticDataTestBearer = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _character = 700000;
final _fixtures = Expando<Future<AuthenticationInfo?>>();

Future<AuthenticationInfo?> staticDataTestAuthentication(
  Session session,
  String bearer,
) async {
  if (bearer != staticDataTestBearer) return null;
  final pod = session.serverpod;
  return _fixtures[pod] ??= pod.withSession((owner) async {
    await owner.db.transaction((tx) async {
      final identity = await SsoIdentityRow.db.insertRow(
        owner,
        SsoIdentityRow(
          characterId: _character,
          owner: 'fixture',
          characterName: 'Admin',
          blocked: false,
        ),
        transaction: tx,
      );
      final account = await MemberAccountRow.db.insertRow(
        owner,
        MemberAccountRow(mainIdentityId: identity.id!),
        transaction: tx,
      );
      await SsoIdentityRow.db.updateRow(
        owner,
        identity.copyWith(accountId: account.id),
        transaction: tx,
      );
      await SsoSessionRow.db.insertRow(
        owner,
        SsoSessionRow(
          digest: ssoDigest(staticDataTestBearer),
          accountId: account.id!,
          identityId: identity.id!,
          expiresAt: DateTime.utc(2100),
        ),
        transaction: tx,
      );
    });
    final sessions = SsoSessions(adminCharacters: {_character});
    sessions.bind(pod);
    return sessions.authenticate(owner, bearer);
  }, enableLogging: false);
}

api.Client staticDataTestClient(String url, {bool admin = true}) =>
    api.Client(url)..authKeyProvider = admin ? const _TestBearer() : null;

final class _TestBearer implements api.ClientAuthKeyProvider {
  const _TestBearer();

  @override
  Future<String> get authHeaderValue async =>
      api.wrapAsBearerAuthHeaderValue(staticDataTestBearer);
}
