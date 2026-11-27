import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_esi/kaname_esi.dart';

/// Submits a batch using the shared anonymous polling client.
///
/// The job validates the whole successful reply before writing any observation.
Future<AffiliationLookupResult> lookupAffiliation(
  EsiClient client,
  List<int> characterIds,
) async => switch (await client.postCharactersAffiliation(body: characterIds)) {
  EsiSuccess(:final body) => AffiliationReply([
    for (final row in body)
      (
        characterId: row.characterId,
        corporationId: row.corporationId,
        allianceId: row.allianceId,
      ),
  ]),
  EsiMalformed() => const AffiliationLookupFailed(malformed: true),
  EsiError() ||
  EsiNotModified() ||
  EsiInvalidRequest() ||
  EsiNotSent() ||
  EsiTransportFailed() => const AffiliationLookupFailed(),
};
