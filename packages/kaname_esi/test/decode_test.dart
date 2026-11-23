import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/fixture_transport.dart';

const String _alliance = '''
{
  "creator_corporation_id": 98000001,
  "creator_id": 90000001,
  "date_founded": "2010-11-04T13:11:00Z",
  "executor_corporation_id": 98000001,
  "name": "Kaname Test Alliance",
  "ticker": "KTA"
}''';

Future<EsiResult<AlliancesDetail>> _alliance200(String body) =>
    EsiClient(FixtureTransport.respond(200, body: body))
        .getAlliancesAllianceId(allianceId: 99000001);

Future<EsiResult<List<CharactersCharacterIdNotificationsGetItem>>>
_notifications200(String type, {String timestamp = '2026-11-19T10:00:00Z'}) =>
    EsiClient(
      FixtureTransport.respond(
        200,
        body:
            '[{"notification_id": 1, "sender_id": 2, '
            '"sender_type": "character", "timestamp": "$timestamp", '
            '"type": $type}]',
      ),
    ).getCharactersCharacterIdNotifications(characterId: 90000001);

/// A listing price, read with the generated `oneOf` reader through the
/// same call path every generated method uses.
Future<EsiResult<EsiOneOf<CharactersParagonHubSkinrItemPrice>>> _price200(
  String body,
) => EsiCall.invoke(
  FixtureTransport.respond(200, body: body),
  () => EsiRequest(
    method: EsiMethod.get,
    operationId: 'GetCharactersParagonHubSkinr',
    target: Uri.parse('/characters/90000001/paragon-hub/skinr'),
    headers: const {},
  ),
  read: CharactersParagonHubSkinrItemPrice.fromJson,
);

Matcher _malformed(String path) => isA<EsiMalformed<Object?>>()
    .having((r) => r.status, 'status', 200)
    .having((r) => r.path, 'path', path);

T _body<T>(EsiResult<T> result) => switch (result) {
  EsiSuccess(:final body) => body,
  _ => fail('expected a success, got $result'),
};

void main() {
  group('Malformed responses are reported', () {
    test('conforming alliance body decodes', () async {
      final alliance = _body(await _alliance200(_alliance));
      expect(alliance.creatorCorporationId, 98000001);
      expect(alliance.creatorId, 90000001);
      expect(alliance.dateFounded, DateTime.utc(2010, 11, 4, 13, 11));
      expect(alliance.executorCorporationId, 98000001);
      expect(alliance.factionId, isNull);
      expect(alliance.name, 'Kaname Test Alliance');
      expect(alliance.ticker, 'KTA');
    });

    test('non-JSON 200 is malformed at the root path', () async {
      expect(await _alliance200('<html>not json</html>'), _malformed(r'$'));
    });

    test('missing required field is malformed with its path', () async {
      expect(
        await _alliance200(_alliance.replaceFirst('"name"', '"nickname"')),
        _malformed(r'$.name'),
      );
    });

    test('string for an integer is malformed with its path', () async {
      expect(
        await _alliance200(
          _alliance.replaceFirst('"creator_id": 90000001', '"creator_id": "x"'),
        ),
        _malformed(r'$.creator_id'),
      );
    });

    for (final founded in ['2010-11-04', '2010-02-30T13:11:00Z']) {
      test('date_founded "$founded" is malformed with its path', () async {
        expect(
          await _alliance200(
            _alliance.replaceFirst('2010-11-04T13:11:00Z', founded),
          ),
          _malformed(r'$.date_founded'),
        );
      });
    }

    test('explicit null for an optional, non-nullable field is malformed '
        'with its path', () async {
      expect(
        await _alliance200(
          _alliance.replaceFirst(
            '"executor_corporation_id": 98000001',
            '"executor_corporation_id": null',
          ),
        ),
        _malformed(r'$.executor_corporation_id'),
      );
    });
  });

  test('a date-time with a lowercase t and z decodes through a generated '
      'call', () async {
    final items = _body(
      await _notifications200(
        '"NewKindOfNotice"',
        timestamp: '2026-11-19t10:00:00z',
      ),
    );
    expect(items.single.timestamp, DateTime.utc(2026, 11, 19, 10));
  });

  group('Values the pinned spec does not list', () {
    test('unlisted enum string decodes to unknown', () async {
      final items = _body(await _notifications200('"NewKindOfNotice"'));
      expect(
        items.single.type,
        isA<EsiUnknown<CharactersCharacterIdNotificationsGetItemType>>().having(
          (u) => u.wire,
          'wire',
          'NewKindOfNotice',
        ),
      );
      expect(
        items.single.senderType,
        const EsiKnown(
          CharactersCharacterIdNotificationsGetItemSenderType.character,
        ),
      );
    });

    test('single-key object with unlisted key decodes to unknown', () async {
      final price = _body(await _price200('{"loyalty_points": 40}'));
      expect(
        price,
        isA<EsiUnknownVariant<CharactersParagonHubSkinrItemPrice>>().having(
          (u) => u.object,
          'object',
          {'loyalty_points': 40},
        ),
      );
    });

    test('undeclared field is ignored', () async {
      final alliance = _body(
        await _alliance200(
          _alliance.replaceFirst('{', '{"motto": "new field", '),
        ),
      );
      expect(alliance.name, 'Kaname Test Alliance');
      expect(alliance.ticker, 'KTA');
    });

    test('listed key with wrong payload type is malformed', () async {
      expect(await _price200('{"isk": "1500.5"}'), _malformed(r'$.isk'));
    });

    test('zero- or two-key oneOf object is malformed', () async {
      expect(await _price200('{}'), _malformed(r'$'));
      expect(await _price200('{"isk": 1500.5, "plex": 20}'), _malformed(r'$'));
    });

    test('number in an enum position is malformed', () async {
      expect(await _notifications200('42'), _malformed(r'$[0].type'));
    });

    test('isk variant decodes with amount 1500.5', () async {
      final price = _body(await _price200('{"isk": 1500.5}'));
      expect(
        price,
        isA<EsiVariant<CharactersParagonHubSkinrItemPrice>>()
            .having((v) => v.key, 'key', 'isk')
            .having(
              (v) => v.value,
              'value',
              const CharactersParagonHubSkinrItemPriceIsk(1500.5),
            ),
      );
    });
  });
}
